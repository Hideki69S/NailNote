import SwiftUI
import CoreData
import UIKit
import Combine

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
        return PlateProduct(id: id, name: name.isEmpty ? "名称未設定の用品" : name, category: category)
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
            .navigationTitle(PlateCopy.tab).navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(darkBackground ? .dark : .light, for: .navigationBar)
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
        .confirmationDialog("プレートを削除しますか？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            if let deleting {
                Button("削除", role: .destructive) { Task { await remove(deleting) } }
            }
            Button("キャンセル", role: .cancel) { deleting = nil }
        } message: { Text("「\(deleting?.title ?? "")」だけを削除します。元の記録・用品・写真は削除しません。") }
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
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \NailEntry.date, ascending: false)])
    private var entries: FetchedResults<NailEntry>
    @State private var initialDraft: PlateDraft?
    @State private var showingProducts = false

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView("デザインがありません", systemImage: "photo.on.rectangle", description: Text("デザインタブで記録を登録してから、プレートを作成してください。"))
                } else {
                    Section {
                        ForEach(entries) { entry in
                            Button {
                                guard let draft = PlateSourceAdapter.draft(from: entry) else { return }
                                initialDraft = draft; showingProducts = true
                            } label: {
                                HStack(spacing: 14) {
                                    PlateEntryThumbnail(photoID: entry.photoId)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(PlateSourceAdapter.title(entry)).font(.headline)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(PlateSourceAdapter.date(entry)).font(.caption).foregroundStyle(.secondary)
                                        if entry.photoId == nil { Text("写真なし・代替表示で作成").font(.caption).foregroundStyle(.secondary) }
                                        if entry.id == nil { Text("識別子がないため選択できません").font(.caption).foregroundStyle(.secondary) }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                }.frame(minHeight: 76).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).disabled(entry.id == nil || entry.isDeleted)
                            .accessibilityIdentifier("plate.entry.\(entry.id?.uuidString ?? "unavailable")")
                        }
                    } footer: {
                        Text("デザインを1件選んでください。写真のない記録や読込できない写真は代替表示になります。元の記録は変更しません。")
                    }
                }
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
            .navigationTitle("掲載する用品").navigationBarTitleDisplayMode(.inline)
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
                PlateEditorView(draft: $session.draft, onCancel: onCancel, onChooseProducts: { showingEditor = false }, session: session, onSaved: onSaved)
                    .modifier(PlateSessionAlerts(session: session, enabled: true))
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
    @StateObject private var thumbnails = PlateProductThumbnailCache()
    @ScaledMetric(relativeTo: .body) private var minimumInfoWidth = 140.0

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
        return products.compactMap { PlateSourceAdapter.product($0) }.filter {
            seen.insert($0.id).inserted && (normalized.isEmpty || $0.name.localizedCaseInsensitiveContains(normalized))
        }
    }

    var body: some View {
        let sources = photoSources
        List {
            Section {
                Text("選択中：\(draft.products.count)件").font(.headline).accessibilityIdentifier("plate.productCount")
                Text("選択中の用品名・掲載順はプレート内に保持します。元用品が変更・削除されても自動更新しません。0件でも編集できます。")
                    .font(.caption).foregroundStyle(.secondary)
                if draft.unavailableSourceProducts > 0 {
                    Text("参照できない使用用品が\(draft.unavailableSourceProducts)件あります。元データは変更していません。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if draft.recipeOverflow > 0 {
                    Text("Recipeは先頭3件を表示します。選択\(draft.products.count)件のうち他\(draft.recipeOverflow)件は作品上に表示されません。掲載順・選択数を調整できます。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("掲載順") {
                if draft.products.isEmpty { Text("用品なしで作成できます").foregroundStyle(.secondary) }
                ForEach(Array(draft.products.enumerated()), id: \.element.id) { index, product in
                    let information = HStack(spacing: 8) {
                        PlateProductThumbnail(source: sources[product.id], category: product.category, cache: thumbnails)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name).fixedSize(horizontal: false, vertical: true)
                            Text(draft.inheritedProductIDs.contains(product.id) ? "記録から引き継ぎ" : "追加した用品")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    let controls = HStack(spacing: 4) {
                        Button { draft.moveProduct(id: product.id, offset: -1) } label: {
                            Image(systemName: "chevron.up").frame(width: 44, height: 44)
                        }.disabled(index == 0).accessibilityLabel(product.name + "を上へ")
                            .accessibilityIdentifier("plate.product.up.\(product.id.uuidString)")
                        Button { draft.moveProduct(id: product.id, offset: 1) } label: {
                            Image(systemName: "chevron.down").frame(width: 44, height: 44)
                        }.disabled(index == draft.products.count - 1).accessibilityLabel(product.name + "を下へ")
                            .accessibilityIdentifier("plate.product.down.\(product.id.uuidString)")
                        Button { draft.toggleProduct(product) } label: {
                            Image(systemName: "minus.circle").frame(width: 44, height: 44)
                        }.accessibilityLabel(product.name + "を解除")
                            .accessibilityIdentifier("plate.product.remove.\(product.id.uuidString)")
                    }.buttonStyle(.borderless)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 4) { information.frame(minWidth: minimumInfoWidth, alignment: .leading); Spacer(minLength: 4); controls }
                        VStack(alignment: .leading, spacing: 4) {
                            information
                            HStack { Spacer(minLength: 0); controls }
                        }
                    }
                }
            }
            Section("登録済みの用品から選択") {
                if availableProducts.isEmpty { Text("該当する用品がありません").foregroundStyle(.secondary) }
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
        }
        .searchable(text: $query, prompt: "用品名を検索")
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
    private var symbol: String {
        let value = NailProductCategory.allCases.first { $0.displayName == category } ?? .other
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
