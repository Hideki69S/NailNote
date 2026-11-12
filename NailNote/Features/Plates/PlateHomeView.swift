import SwiftUI
import CoreData
import UIKit
import Combine
import ImageIO

// 元画像のEXIF方向を適用して縮小し、透過部分は白地へ合成する。
nonisolated enum PlateItemImageCodec {
    static func jpeg(at url: URL, quality: CGFloat = 0.82) -> Data? {
        autoreleasepool {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 256,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary) else { return nil }
            let color = CGColorSpace(name: CGColorSpace.sRGB)!
            guard let context = CGContext(data: nil, width: cg.width, height: cg.height, bitsPerComponent: 8,
                                          bytesPerRow: cg.width * 4, space: color, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
            guard let image = context.makeImage() else { return nil }
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { return nil }
            let bytes = data as Data
            return PlateRepository.validItemImage(bytes) ? bytes : nil
        }
    }
}

// 購入価格・購入場所・URLはDraftにも掲載用スナップショットにも取り込まない。
struct PlateProduct: Identifiable, Equatable {
    let id: UUID
    let name: String
    let category: String
}

enum PlateSourceAdapter {
    static func product(_ product: NailProduct) -> PlateProduct? {
        guard !product.isDeleted, let id = product.id else { return nil }
        let name = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let category = NailProductCategory(rawValue: product.category ?? "")?.displayName ?? "その他"
        return PlateProduct(id: id, name: name.isEmpty ? "名称未設定のアイテム" : name, category: category)
    }

    static func title(_ entry: NailEntry) -> String {
        let title = (entry.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "タイトルなし" : title
    }

    static func date(_ entry: NailEntry) -> String {
        guard let date = entry.date else { return "日付未設定" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    static func draft(from entry: NailEntry) -> PlateDraft? {
        guard !entry.isDeleted, let id = entry.id else { return nil }
        let links = (entry.usedItems?.array as? [NailEntryUsedItem]) ?? []
        // 同じorderIndexでも、元の順序付き関連の順を保つ。
        let ordered = links.enumerated().sorted {
            $0.element.orderIndex == $1.element.orderIndex ? $0.offset < $1.offset : $0.element.orderIndex < $1.element.orderIndex
        }
        var selected: [PlateProduct] = []
        var ids = Set<UUID>()
        var unavailable = 0
        for link in ordered {
            guard !link.element.isDeleted, let source = link.element.product, let item = product(source) else {
                unavailable += 1; continue
            }
            if ids.insert(item.id).inserted { selected.append(item) }
        }
        return PlateDraft(sourceEntryID: id, photoID: entry.photoId, inheritedProductIDs: ids,
                          title: title(entry), date: date(entry), comment: entry.note ?? "",
                          products: selected, unavailableSourceProducts: unavailable)
    }
}

struct PlateHomeView: View {
    @Environment(\.nailTabResetID) private var tabResetID
    @Environment(\.managedObjectContext) private var context
    @AppStorage(GlassTheme.Keys.designCardPreset) private var presetRaw = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @State private var showingCreate = false
    @State private var savedItems: [PlateListItem] = []
    @State private var listing = true
    @State private var listError: String?
    @State private var message: String?
    @State private var editing: PlateLoadedDocument?
    @State private var deleting: PlateListItem?
    @State private var working = false
    @State private var exporting: PlateExportSnapshot?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var palette: GlassTheme.DesignCardPalette {
        let base = GlassTheme.designCardPalette(for: GlassTheme.DesignCardPreset(rawValue: presetRaw) ?? .roseChampagne)
        return NailAppearance.designPalette(base, choice: NailAppearance.Document.decode(appearanceRaw).resolved(.design))
    }

    private var backgroundPreset: GlassTheme.BackgroundPreset {
        GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne
    }
    private var pagePalette: GlassTheme.DesignCardPalette {
        NailAppearance.designPalette(backgroundPreset.refinedSurfacePalette, choice: NailAppearance.Document.decode(appearanceRaw).resolved(.design))
    }
    private var darkBackground: Bool {
        let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.design)
        return choice.flatMap { $0.changesColor ? $0.dark : nil } ?? (backgroundPreset == .noirGold || backgroundPreset == .noirSilver)
    }

    @State private var contentWidth: CGFloat = 390
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize.isAccessibilitySize || contentWidth < 350 ? 1 : 2) }

    var body: some View {
        NavigationStack {
            GlassBackgroundView(refined: true, appearanceArea: .design) {
                VStack(spacing: 0) {
                    NailDesignAdPlaceholderRow().padding(.top, 12).padding(.horizontal, 16)
                    ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Button { showingCreate = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.rectangle.portrait").font(.title2)
                                Text("新しく作成").font(.headline)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                            }
                            .padding(18).frame(minHeight: 58)
                            .foregroundStyle(palette.titleText)
                            .background(LinearGradient(colors: [palette.glowFillTop, palette.glowFillBottom], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(LinearGradient(colors: [.white.opacity(0.85), palette.outerStrokeEnd], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                            .shadow(color: .black.opacity(0.10), radius: 8, x: 1, y: 4)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("plate.new")
                        Text("保存したプレート").font(.headline).foregroundStyle(pagePalette.titleText)
                        if listing { ProgressView("読み込み中") }
                        else if let listError {
                            Text(listError).foregroundStyle(pagePalette.titleText)
                            Button("再読み込み") { Task { await refresh() } }
                        } else if savedItems.isEmpty {
                            Text("保存したプレートはまだありません。「新しく作成」から作品を編集し、保存してください。")
                                .foregroundStyle(pagePalette.tagText)
                        }
                        GeometryReader { proxy in Color.clear.onAppear { contentWidth = proxy.size.width + 40 }.onChange(of: proxy.size.width) { _, width in contentWidth = width + 40 } }.frame(height: 0)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(savedItems) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Button { Task { await open(item) } } label: {
                                        VStack(alignment: .leading, spacing: 8) {
                                            PlateSavedThumbnail(item: item)
                                            Text(item.title.isEmpty ? "タイトルなし" : item.title)
                                                .font(.headline).fixedSize(horizontal: false, vertical: true)
                                            if let issue = item.issue { Text(issue).font(.caption) }
                                            else { Text(item.updatedAt, style: .date).font(.caption) }
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain).disabled(item.issue != nil || working)
                                    .accessibilityIdentifier("plate.saved.\(item.id.uuidString)")
                                    Menu {
                                        Button("書き出し", systemImage: "square.and.arrow.up") { Task { await export(item) } }
                                        Button("複製", systemImage: "plus.square.on.square") { Task { await duplicate(item) } }
                                        Button("削除", systemImage: "trash", role: .destructive) { deleting = item }
                                    } label: {
                                        Label("作品メニュー", systemImage: "ellipsis").font(.caption).frame(minHeight: 44)
                                    }.disabled(item.issue != nil || working).accessibilityIdentifier("plate.menu.\(item.id.uuidString)")
                                }
                                .foregroundStyle(palette.titleText).padding(10)
                                .background(palette.glowFillMid.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(palette.tagStroke, lineWidth: 0.7))
                            }
                        }
                        Text("価格・購入場所・商品URLはプレートに掲載しません。")
                            .font(.caption).foregroundStyle(pagePalette.tagText)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .modifier(NailTabStackReset())
        .onChange(of: tabResetID) { _, _ in showingCreate = false; editing = nil; deleting = nil }
        .modifier(NailAppearanceEnvironment(area: .design))
        .task { await refresh() }
        .sheet(isPresented: $showingCreate, onDismiss: { Task { await refresh() } }) {
            PlateCreationView(onSaved: { showingCreate = false }).environment(\.managedObjectContext, context)
        }
        .sheet(item: $editing, onDismiss: { Task { await refresh() } }) { loaded in
            NavigationStack {
                PlateDraftSessionView(loaded: loaded, onCancel: { editing = nil }, onSaved: { editing = nil })
            }.environment(\.managedObjectContext, context)
        }
        .sheet(item: $exporting) { snapshot in PlateExportSheet(snapshot: snapshot) }
        .confirmationDialog("プレートを削除しますか？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            if let deleting {
                Button("削除", role: .destructive) { Task { await remove(deleting) } }
            }
            Button("キャンセル", role: .cancel) { deleting = nil }
        } message: { Text("「\(deleting?.title ?? "")」だけを削除します。元の記録・アイテム・写真は削除しません。") }
        .alert("プレート", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }
    private func refresh() async {
        listing = true; listError = nil
        do { savedItems = try await PlateRepository.shared.list() }
        catch { listError = "一覧を読み込めませんでした。\n" + error.localizedDescription }
        listing = false
    }
    private func open(_ item: PlateListItem) async {
        guard !working else { return }; working = true; defer { working = false }
        do { editing = try await PlateRepository.shared.load(item.id) }
        catch { message = error.localizedDescription }
    }
    private func export(_ item: PlateListItem) async {
        guard !working else { return }
        working = true; defer { working = false }
        do {
            let loaded = try await PlateRepository.shared.load(item.id)
            guard loaded.document.revisionID == item.revisionID else { throw PlateStorageError.conflict }
            exporting = try PlateExportSnapshot(loaded: loaded)
        } catch { message = "書き出しを準備できませんでした。\n" + error.localizedDescription }
    }
    private func duplicate(_ item: PlateListItem) async {
        guard !working, let revision = item.revisionID else { return }
        working = true; defer { working = false }
        do { _ = try await PlateRepository.shared.duplicate(item.id, expectedRevision: revision); await refresh(); message = "複製しました。作品の内容・タイトルは元のままです。" }
        catch { message = "複製できませんでした。\n" + error.localizedDescription }
    }
    private func remove(_ item: PlateListItem) async {
        deleting = nil
        guard !working, let revision = item.revisionID else { return }
        working = true; defer { working = false }
        do { let warning = try await PlateRepository.shared.delete(item.id, expectedRevision: revision); await refresh(); if let warning { message = warning } }
        catch { message = "削除できませんでした。\n" + error.localizedDescription }
    }

}

private struct PlateCreationView: View {
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var initialDraft: PlateDraft?
    @State private var showingProducts = false

    var body: some View {
        NavigationStack {
            PlateDesignSelectionView(replacingPhoto: false) { entry in
                guard let draft = PlateSourceAdapter.draft(from: entry) else { return }
                initialDraft = draft; showingProducts = true
            }
            .navigationTitle("デザインを選択").navigationBarTitleDisplayMode(.inline)
            .modifier(NailTabExitProtection(dirty: false))
            .modifier(NailEditorExit(dirty: false, enabled: !showingProducts, onReturn: { dismiss() }))
            .navigationDestination(isPresented: $showingProducts) {
                if let initialDraft {
                    PlateDraftSessionView(initialDraft: initialDraft, onCancel: { dismiss() }, onSaved: onSaved)
                        .id(initialDraft.sourceEntryID)
                }
            }
        }
    }
}

// 新規作成と写真差し替えで共有する、読取専用のデザイン選択一覧。
struct PlateDesignSelectionView: View {
    let replacingPhoto: Bool
    var blocked = false
    let onSelect: (NailEntry) -> Void
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \NailEntry.date, ascending: false)])
    private var entries: FetchedResults<NailEntry>
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    var body: some View {
        let preset = GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne
        let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.design)
        let dark = choice.flatMap { $0.changesColor ? $0.dark : nil } ?? (preset == .noirGold || preset == .noirSilver)
            List {
                if entries.isEmpty {
                    ContentUnavailableView("デザインがありません", systemImage: "photo.on.rectangle", description: Text("デザインタブで記録を登録してから、プレートを作成してください。"))
                } else {
                    Section {
                        ForEach(entries) { entry in
                            Button {
                                onSelect(entry)
                            } label: {
                                HStack(spacing: 14) {
                                    PlateEntryThumbnail(photoID: entry.photoId)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(PlateSourceAdapter.title(entry)).font(.headline)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(PlateSourceAdapter.date(entry)).font(.caption).foregroundStyle(.secondary)
                                        if entry.photoId == nil { Text(replacingPhoto ? "写真がないため差し替えできません" : "写真なし・代替表示で作成").font(.caption).foregroundStyle(.secondary) }
                                        if entry.id == nil { Text("識別子がないため選択できません").font(.caption).foregroundStyle(.secondary) }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }.frame(minHeight: 76).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).disabled(blocked || entry.id == nil || entry.isDeleted || (replacingPhoto && entry.photoId == nil))
                            .accessibilityIdentifier("plate.entry.\(entry.id?.uuidString ?? "unavailable")")
                        }
                    } footer: {
                        Text(replacingPhoto ? "写真のみ差し替えます。作成元の記録・文章・アイテムは変わりません。写真のない記録は選択できません。" : "デザインを1件選んでください。写真のない記録や読込できない写真は代替表示になります。元の記録は変更しません。")
                    }
                }
            }
        .scrollContentBackground(.hidden)
        .background { GlassBackgroundView(refined: true, appearanceArea: .design) { Color.clear } }
        .overlay(alignment: .top) { if blocked { ProgressView("写真を準備中").padding(12).background(.regularMaterial, in: Capsule()) } }
        .navigationTitle("デザインを選択").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarColorScheme(dark ? .dark : .light, for: .navigationBar)
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}

private struct PlateEntryThumbnail: View {
    let photoID: UUID?
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08))
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
        .frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityHidden(true)
        .task(id: photoID) {
            image = nil
            guard let photoID else { return }
            let url = EntryPhotoStore.thumbnailURL(photoId: photoID)
            let data = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: url) }.value
            guard !Task.isCancelled else { return }
            image = data.flatMap { UIImage(data: $0) }
        }
    }
}

private struct PlateDraftSessionView: View {
    @StateObject private var session: PlateEditingSession
    @State private var showingEditor = false
    @State private var showingProductsSheet = false
    @State private var entered = false
    let startsInEditor: Bool
    let onCancel: () -> Void
    let onSaved: () -> Void

    init(initialDraft: PlateDraft, onCancel: @escaping () -> Void, onSaved: @escaping () -> Void) {
        _session = StateObject(wrappedValue: PlateEditingSession(draft: initialDraft))
        startsInEditor = false; self.onCancel = onCancel; self.onSaved = onSaved
    }
    init(loaded: PlateLoadedDocument, onCancel: @escaping () -> Void, onSaved: @escaping () -> Void) {
        _session = StateObject(wrappedValue: PlateEditingSession(loaded: loaded))
        startsInEditor = true; self.onCancel = onCancel; self.onSaved = onSaved
    }
    var body: some View {
        PlateProductSelectionView(draft: $session.draft)
            .modifier(NailTabExitProtection(dirty: session.dirty, blocked: session.saving))
            .navigationTitle("掲載するアイテム").navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .modifier(NailEditorExit(dirty: session.dirty, blocked: session.saving, enabled: !showingEditor, onReturn: onCancel))
            .toolbar {
                if !showingEditor {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("編集へ") { showingEditor = true }.accessibilityIdentifier("plate.edit")
                    }
                }
            }
            .navigationDestination(isPresented: $showingEditor) {
                PlateEditorView(draft: $session.draft, onCancel: onCancel, onChooseProducts: { showingProductsSheet = true }, session: session, onSaved: onSaved)
                    .modifier(PlateSessionAlerts(session: session, enabled: true))
            }
            .sheet(isPresented: $showingProductsSheet) {
                NavigationStack {
                    PlateProductSelectionView(draft: $session.draft)
                        .navigationTitle("掲載するアイテム").navigationBarTitleDisplayMode(.inline)
                        .toolbar(.visible, for: .navigationBar)
                        .toolbar { ToolbarItem(placement: .confirmationAction) {
                            Button("完了") { showingProductsSheet = false }.accessibilityIdentifier("plate.products.done")
                        } }
                }.interactiveDismissDisabled(session.saving || session.importingPhoto)
            }
            .onAppear { if !entered { entered = true; showingEditor = startsInEditor } }
            .disabled(session.saving)
            .modifier(PlateSessionAlerts(session: session, enabled: !showingEditor))
    }
}

// 表示中の画面だけが確認を提示する。背面のListへalertを付けたままにしない。
private struct PlateSessionAlerts: ViewModifier {
    @ObservedObject var session: PlateEditingSession
    let enabled: Bool
    func body(content: Content) -> some View {
        content.alert("保存できませんでした", isPresented: Binding(
            get: { enabled && session.error != nil },
            set: { if !$0 { session.error = nil } }
        )) {
            Button("OK") { session.error = nil }
        } message: {
            Text(session.error ?? "")
        }
    }
}

// 公開のシートdelegateを中継し、スワイプでの破棄も同じ確認へ渡す。
struct PlateDismissGuard: UIViewControllerRepresentable {
    let blocked: () -> Bool
    let onAttempt: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> GuardController {
        let controller = GuardController(); controller.view.isUserInteractionEnabled = false
        let coordinator = context.coordinator
        controller.onAttach = { [weak controller] in if let controller { coordinator.install(from: controller) } }
        return controller
    }
    func updateUIViewController(_ controller: GuardController, context: Context) {
        let coordinator = context.coordinator
        coordinator.blocked = blocked; coordinator.onAttempt = onAttempt
        DispatchQueue.main.async { coordinator.install(from: controller) }
    }
    static func dismantleUIViewController(_ controller: GuardController, coordinator: Coordinator) {
        if let presentation = coordinator.presentation, presentation.delegate === coordinator { presentation.delegate = coordinator.previous }
    }
    final class GuardController: UIViewController {
        var onAttach: (() -> Void)?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); onAttach?() }
        override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); onAttach?() }
    }
    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var blocked: () -> Bool = { false }
        var onAttempt: () -> Void = {}
        weak var previous: UIAdaptivePresentationControllerDelegate?
        weak var presentation: UIPresentationController?
        func install(from controller: UIViewController) {
            var chain: [UIViewController] = []
            var node: UIViewController? = controller
            while let current = node { chain.append(current); node = current.parent }
            for current in chain.reversed() {
                if current.presentingViewController != nil, let presentation = current.presentationController {
                    if presentation.delegate !== self {
                        if let prior = presentation.delegate as? Coordinator { previous = prior.previous }
                        else { previous = presentation.delegate }
                        presentation.delegate = self
                    }
                    self.presentation = presentation; return
                }
            }
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !blocked() && (previous?.presentationControllerShouldDismiss?(presentationController) ?? true)
        }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { onAttempt() }
        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) { previous?.presentationControllerWillDismiss?(presentationController) }
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { previous?.presentationControllerDidDismiss?(presentationController) }
    }
}

private struct PlateSavedThumbnail: View {
    let item: PlateListItem
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.10))
            if let image { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: failed || item.issue != nil ? "exclamationmark.triangle" : "photo").foregroundStyle(.secondary) }
        }
        .aspectRatio(0.8, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityHidden(true)
        .task(id: item.revisionID) {
            image = nil; failed = false
            do { let bytes = try await PlateRepository.shared.thumbnail(item); guard !Task.isCancelled else { return }; image = UIImage(data: bytes); failed = image == nil }
            catch { failed = true }
        }
    }
}

extension PlateLoadedDocument: Identifiable {
    var id: UUID { document.plateID }
}

struct PlateProductSelectionView: View {
    @Binding var draft: PlateDraft
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \NailProduct.name, ascending: true)])
    private var products: FetchedResults<NailProduct>
    @State private var query = ""
    @State private var selectedCategory: NailProductCategory = .color
    @StateObject private var thumbnails = PlateProductThumbnailCache()
    @State private var dragSession = UUID()

    // 現在のItemは画像参照だけに使用し、保存済み用品の文字や順序へ書き戻さない。
    private var photoSources: [UUID: PlateProductPhotoSource] {
        var sources: [UUID: PlateProductPhotoSource] = [:]
        for product in products where !product.isDeleted {
            guard let id = product.id, sources[id] == nil else { continue }
            sources[id] = PlateProductPhotoSource(photoID: product.photoId, sampleID: product.samplePhotoId)
        }
        return sources
    }

    private var availableProducts: [PlateProduct] {
        var seen = Set<UUID>()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return products.filter {
            let raw = ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return (NailProductCategory(rawValue: raw) ?? .other) == selectedCategory
        }.compactMap { PlateSourceAdapter.product($0) }.filter {
            seen.insert($0.id).inserted && (normalized.isEmpty || $0.name.localizedCaseInsensitiveContains(normalized))
        }
    }

    var body: some View {
        let sources = photoSources
        List {
            Section("登録済みのアイテムから選択") {
                categoryTabs
                if availableProducts.isEmpty { Text("このカテゴリに該当するアイテムがありません").foregroundStyle(.secondary) }
                ForEach(availableProducts) { product in
                    let selected = draft.products.contains { $0.id == product.id }
                    let displayed = draft.products.first { $0.id == product.id } ?? product
                    Button { draft.toggleProduct(product) } label: {
                        HStack(spacing: 12) {
                            PlateProductThumbnail(source: sources[product.id], category: displayed.category, cache: thumbnails)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayed.name).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                Text(displayed.category).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("plate.product.toggle.\(product.id.uuidString)")
                    .accessibilityValue(selected ? "選択中" : "未選択")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Section("掲載アイテムの配置") {
                Text("選択中：\(draft.products.count)件").font(.headline).accessibilityIdentifier("plate.productCount")
                Text("長押しして別のブロックへドロップすると掲載順が変わります。解除は上の登録済みアイテムから行えます。")
                    .font(.caption).foregroundStyle(.secondary)
                Text("アイテム名・カテゴリ・掲載順は作品内に保持します。元アイテムの変更・削除では更新しません。")
                    .font(.caption).foregroundStyle(.secondary)
                if draft.products.isEmpty {
                    Text("上のカテゴリからアイテムを選択してください。アイテムなしでも作成できます。")
                        .foregroundStyle(.secondary)
                } else {
                    arrangement(sources: sources)
                }
                if draft.unavailableSourceProducts > 0 {
                    Text("参照できない使用アイテムが\(draft.unavailableSourceProducts)件あります。元データは変更していません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

        }
        .searchable(text: $query, prompt: "アイテム名を検索")
    }

    // ドラッグ中はDraftを変更せず、同じ選択画面からのドロップ成立時だけ既存の移動処理へ渡す。
    private var visibleLimit: Int { draft.layoutVersion == 8 ? PlateLayoutEightItems.limit : 3 }

    private var arrangementColumns: Int {
        let count = min(visibleLimit, draft.products.count)
        switch draft.template {
        case .elegant, .sweet: return count <= 3 ? max(1, count) : 3
        case .noir, .recipe: return count <= 3 ? 1 : 2
        }
    }

    private func arrangementIndex(row: Int, column: Int, rows: Int) -> Int {
        // Recipeだけ列優先。ほかはrenderer8と同じ行優先で読む。
        draft.template == .recipe ? column * rows + row : row * arrangementColumns + column
    }

    private func arrangement(sources: [UUID: PlateProductPhotoSource]) -> some View {
        let count = min(visibleLimit, draft.products.count)
        let rows = (count + arrangementColumns - 1) / arrangementColumns
        return VStack(alignment: .leading, spacing: 10) {
            Text("掲載対象（先頭\(visibleLimit)件まで）").font(.subheadline.weight(.semibold))
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<rows, id: \.self) { row in
                    GridRow {
                        ForEach(0..<arrangementColumns, id: \.self) { column in
                            let index = arrangementIndex(row: row, column: column, rows: rows)
                            if index < count {
                                arrangementBlock(index: index, sources: sources)
                            } else {
                                PlateArrangementDropTarget(sessionID: dragSession.uuidString, onDrop: { acceptDrop($0, at: count - 1) }) {
                                    Text("末尾へ移動").font(.caption2).foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, minHeight: 100)
                                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                                }
                                .accessibilityLabel("空き枠。ドロップすると掲載対象の末尾へ移動")
                            }
                        }
                    }
                }
            }
            if draft.products.count > visibleLimit {
                Text("掲載対象外（あと\(draft.products.count - visibleLimit)件）")
                    .font(.subheadline.weight(.semibold))
                Text("現在の作品には表示されません。掲載対象へドラッグすると入れ替えられます。")
                    .font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 6) {
                    ForEach(visibleLimit..<draft.products.count, id: \.self) { index in
                        arrangementBlock(index: index, sources: sources)
                    }
                }
            }
        }
    }

    private func arrangementBlock(index: Int, sources: [UUID: PlateProductPhotoSource]) -> some View {
        let product = draft.products[index]
        return PlateArrangementDropTarget(sessionID: dragSession.uuidString, dragValue: dragSession.uuidString + ":" + product.id.uuidString, onDrop: { acceptDrop($0, at: index) }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(String(format: "%02d", index + 1)).font(.caption2.monospacedDigit())
                    Spacer(minLength: 0)
                    Image(systemName: "hand.draw").font(.caption2)
                }.foregroundStyle(.secondary)
                if index >= visibleLimit {
                    HStack(alignment: .top, spacing: 6) {
                        PlateProductThumbnail(source: sources[product.id], category: product.category, cache: thumbnails)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(PlateItemCategoryLabel.title(product.category)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Text(product.name).font(.caption).lineLimit(2).multilineTextAlignment(.leading)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    PlateProductThumbnail(source: sources[product.id], category: product.category, cache: thumbnails)
                    Text(PlateItemCategoryLabel.title(product.category)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Text(product.name).font(.caption).lineLimit(2).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(8).frame(maxWidth: .infinity, minHeight: index >= visibleLimit ? 88 : 136, alignment: .topLeading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(GlassTheme.cardStroke, lineWidth: 0.7))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("掲載順\(index + 1)、" + product.name + "、" + PlateItemCategoryLabel.title(product.category))
            .accessibilityValue(index < visibleLimit ? "掲載対象" : "掲載対象外")
            .accessibilityHint("長押しで移動。VoiceOverのアクションでも掲載順を変更できます")
            .accessibilityAction(named: "掲載順を1つ前へ") { move(product.id, to: index - 1) }
            .accessibilityAction(named: "掲載順を1つ後へ") { move(product.id, to: index + 1) }
            .accessibilityIdentifier("plate.arrangement.item." + product.id.uuidString)
    }

    private func acceptDrop(_ values: [String], at index: Int) -> Bool {
        guard values.count == 1 else { return false }
        let parts = values[0].split(separator: ":")
        guard parts.count == 2, String(parts[0]) == dragSession.uuidString,
              let id = UUID(uuidString: String(parts[1])), draft.products.contains(where: { $0.id == id }),
              draft.products.indices.contains(index) else { return false }
        move(id, to: index)
        return true
    }

    private func move(_ id: UUID, to index: Int) {
        guard let from = draft.products.firstIndex(where: { $0.id == id }), draft.products.indices.contains(index) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { draft.moveProduct(id: id, offset: index - from) }
    }

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NailProductCategory.allCases) { category in
                    let selected = selectedCategory == category
                    Button { selectedCategory = category } label: {
                        Text(category.displayName).font(.caption.weight(selected ? .semibold : .regular))
                            .padding(.horizontal, 12).frame(minHeight: 44)
                            .background(selected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(selected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1))
                            .foregroundStyle(selected ? Color.accentColor : Color.primary)
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("plate.category.\(category.rawValue)")
                        .accessibilityValue(selected ? "選択中" : "未選択")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }.accessibilityIdentifier("plate.categoryTabs")
    }
}

// List内の個別ブロックへ標準UIKitのドラッグ／ドロップを接続する。表示と配列更新はSwiftUI側で管理する。
private struct PlateArrangementDropTarget<Content: View>: View {
    let sessionID: String
    var dragValue: String? = nil
    let onDrop: ([String]) -> Bool
    @ViewBuilder let content: () -> Content
    @State private var targeted = false

    var body: some View {
        content()
            .overlay(PlateArrangementInteraction(sessionID: sessionID, value: dragValue, onDrop: onDrop, onTargeted: { targeted = $0 }))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(targeted ? Color.accentColor : .clear, lineWidth: 3).allowsHitTesting(false))
    }
}

private struct PlateArrangementInteraction: UIViewRepresentable {
    let sessionID: String
    let value: String?
    let onDrop: ([String]) -> Bool
    let onTargeted: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        let drag = UIDragInteraction(delegate: context.coordinator)
        drag.isEnabled = true
        view.addInteraction(drag)
        view.addInteraction(UIDropInteraction(delegate: context.coordinator))
        return view
    }
    func updateUIView(_ view: UIView, context: Context) { context.coordinator.owner = self }

    final class Coordinator: NSObject, UIDragInteractionDelegate, UIDropInteractionDelegate {
        var owner: PlateArrangementInteraction
        init(_ owner: PlateArrangementInteraction) { self.owner = owner }

        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            guard let value = owner.value else { return [] }
            let item = UIDragItem(itemProvider: NSItemProvider(object: value as NSString))
            item.localObject = value
            return [item]
        }
        func dragInteraction(_ interaction: UIDragInteraction, sessionAllowsMoveOperation session: UIDragSession) -> Bool { true }
        func dragInteraction(_ interaction: UIDragInteraction, sessionIsRestrictedToDraggingApplication session: UIDragSession) -> Bool { true }
        func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: UIDragSession) -> UITargetedDragPreview? {
            guard let view = interaction.view, let window = view.window else { return nil }
            let rect = view.convert(view.bounds, to: window)
            guard let snapshot = window.resizableSnapshotView(from: rect, afterScreenUpdates: false, withCapInsets: .zero) else { return nil }
            snapshot.layer.cornerRadius = 10; snapshot.clipsToBounds = true
            let parameters = UIDragPreviewParameters(); parameters.backgroundColor = .clear
            return UITargetedDragPreview(view: snapshot, parameters: parameters,
                target: UIDragPreviewTarget(container: window, center: CGPoint(x: rect.midX, y: rect.midY)))
        }
        // 外部アプリ・別の選択画面・複数ブロックからのドロップを受け付けない。
        private func localValue(_ session: UIDropSession) -> String? {
            guard session.localDragSession != nil, session.items.count == 1,
                  let value = session.items.first?.localObject as? String,
                  value.hasPrefix(owner.sessionID + ":") else { return nil }
            return value
        }
        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool { localValue(session) != nil }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) { owner.onTargeted(localValue(session) != nil) }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
            UIDropProposal(operation: localValue(session) == nil ? .forbidden : .move)
        }
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            defer { owner.onTargeted(false) }
            guard let value = localValue(session) else { return }
            _ = owner.onDrop([value])
        }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) { owner.onTargeted(false) }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) { owner.onTargeted(false) }
        func dragInteraction(_ interaction: UIDragInteraction, session: UIDragSession, didEndWith operation: UIDropOperation) { owner.onTargeted(false) }
    }
}

// 完成作品の外に置く編集用リスト。作品のCanvas・サムネイルには含めない。
struct PlateProductEditingSidebar: View {
    @Binding var draft: PlateDraft
    let compact: Bool
    let palette: GlassTheme.DesignCardPalette
    let onChoose: () -> Void
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \NailProduct.name, ascending: true)])
    private var products: FetchedResults<NailProduct>
    @StateObject private var thumbnails = PlateProductThumbnailCache()
    @State private var inspecting: PlateProduct?

    private var sources: [UUID: PlateProductPhotoSource] {
        var values: [UUID: PlateProductPhotoSource] = [:]
        for item in products where !item.isDeleted {
            guard let id = item.id, values[id] == nil else { continue }
            values[id] = .init(photoID: item.photoId, sampleID: item.samplePhotoId)
        }
        return values
    }
    var body: some View {
        let photos = sources
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                Text("アイテム").font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                Button(action: onChoose) {
                    Image(systemName: "plus").font(.body.weight(.semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("plate.products")
                    .accessibilityLabel("アイテムを追加")
            }
            Text("掲載順 · \(draft.products.count)点").font(.caption2)
            if draft.layoutVersion < 8 { PlateLayoutUpdateButton(draft: $draft).font(.caption) }
            ScrollView {
                LazyVStack(spacing: 6) {
                    if draft.products.isEmpty { Text("アイテムなし").font(.caption).padding(.vertical, 8) }
                    ForEach(Array(draft.products.enumerated()), id: \.element.id) { index, item in
                        Menu {
                            Button("アイテム名を確認") { inspecting = item }
                            Button("1つ上へ") { draft.moveProduct(id: item.id, offset: -1) }
                                .disabled(index == 0).accessibilityIdentifier("plate.sidebar.up." + item.id.uuidString)
                            Button("1つ下へ") { draft.moveProduct(id: item.id, offset: 1) }
                                .disabled(index == draft.products.count - 1).accessibilityIdentifier("plate.sidebar.down." + item.id.uuidString)
                            Button("掲載から外す", role: .destructive) { draft.toggleProduct(item) }
                                .accessibilityIdentifier("plate.sidebar.remove." + item.id.uuidString)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack { Text(String(format: "%02d", index + 1)); Spacer(minLength: 0); Image(systemName: "ellipsis") }.font(.caption)
                                HStack(spacing: 5) {
                                    if !compact {
                                        PlateProductThumbnail(source: photos[item.id], category: item.category, cache: thumbnails)
                                            .scaleEffect(0.6).frame(width: 29, height: 29)
                                    }
                                    Text(item.name).font(.caption).lineLimit(2).multilineTextAlignment(.leading)
                                }
                                if draft.template == .recipe && index >= (draft.layoutVersion == 8 ? PlateLayoutEightItems.limit : PlateDraft.recipeLimit) {
                                    Text("作品では非表示").font(.caption2)
                                }
                            }.padding(7).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                .background(palette.glowFillTop, in: RoundedRectangle(cornerRadius: 9))
                        }
                        .accessibilityLabel("掲載順\(index + 1)、" + item.name)
                        .accessibilityHint("メニューから掲載順の変更・解除・全文確認ができます")
                        .accessibilityIdentifier("plate.sidebar.menu." + item.id.uuidString)
                    }
                }
            }.accessibilityIdentifier("plate.sidebar.list")
        }
        .foregroundStyle(palette.titleText).padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.glowFillMid.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.tagStroke, lineWidth: 0.7))
        .alert("掲載アイテム", isPresented: Binding(get: { inspecting != nil }, set: { if !$0 { inspecting = nil } })) {
            Button("閉じる") { inspecting = nil }
        } message: { Text((inspecting?.name ?? "") + "\n" + (inspecting?.category ?? "")) }
    }
}

private struct PlateProductPhotoSource: Hashable {
    let photoID: UUID?
    let sampleID: UUID?
}

// 選択画面の生存期間だけ保持する。写真の永続コピーや保存処理は行わない。
private final class PlateProductThumbnailCache: ObservableObject {
    private let images = NSCache<NSUUID, UIImage>()

    init() {
        images.countLimit = 64
        images.totalCostLimit = 8 * 1024 * 1024
    }

    func image(for source: PlateProductPhotoSource?) -> UIImage? {
        guard let source else { return nil }
        for id in [source.photoID, source.sampleID].compactMap({ $0 }) {
            if let image = images.object(forKey: id as NSUUID) { return image }
            if let image = ProductPhotoStore.loadThumbnail(photoId: id, maxPixel: 48) {
                images.setObject(image, forKey: id as NSUUID, cost: Int(image.size.width * image.scale * image.size.height * image.scale * 4))
                return image
            }
        }
        return nil
    }
}

private struct PlateProductThumbnail: View {
    let source: PlateProductPhotoSource?
    let category: String
    let cache: PlateProductThumbnailCache
    @State private var image: UIImage?

    // 既存12カテゴリに対応する表示専用の代替アイコン。保存値には追加しない。
    private var symbol: String { PlateItemPresentation.symbol(for: category) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(.thinMaterial)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: symbol).font(.system(size: 20, weight: .regular)).foregroundStyle(.secondary) }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(GlassTheme.cardStroke, lineWidth: 0.7))
        .accessibilityHidden(true)
        .task(id: source) {
            image = nil
            guard !Task.isCancelled else { return }
            image = cache.image(for: source)
        }
    }
}

// 編集用サムネイルと作品のカテゴリ代替表示を共通化する。
enum PlateItemPresentation {
    static func symbol(for category: String) -> String {
        let value = NailProductCategory.allCases.first { $0.displayName == category || $0.rawValue == category } ?? .other
        switch value {
        case .color: return "paintpalette"
        case .base, .top: return "drop"
        case .deco, .parts: return "sparkles"
        case .art: return "paintbrush.pointed"
        case .sticker: return "square.on.square"
        case .care: return "hand.raised"
        case .remove: return "drop.degreesign"
        case .tool: return "wrench.and.screwdriver"
        case .stock: return "archivebox"
        case .other: return "shippingbox"
        }
    }

}
