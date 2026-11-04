import SwiftUI
import UIKit
import Combine
import CoreText
import CryptoKit
import PhotosUI

enum PlateTextRole: String, Identifiable {
    case title, comment
    var id: String { rawValue }
    var label: String { self == .title ? "タイトル" : "コメント" }
}

// 既存のAsset Catalogから取得し、改変を検出してからデータ由来の書体を生成する。
enum PlateFontCatalog {
    struct File: Decodable { let filename: String; let sha256: String; let nameTable: [String: String] }
    struct Record: Decodable { let directory: String; let family: String; let license: String; let licenseSHA256: String; let files: [File] }
    static let records: [Record] = {
        guard let data = NSDataAsset(name: "PlateFonts/Registry")?.data else { return [] }
        return (try? JSONDecoder().decode([Record].self, from: data)) ?? []
    }()
    private static var descriptors: [String: CTFontDescriptor] = [:]
    static let names = ["standard": "標準", "hiramin": "ヒラギノ明朝", "modern": "システム角ゴ", "hiramaru": "ヒラギノ丸ゴ", "zenmarugothic": "ZEN丸ゴシック", "kosugimaru": "小杉丸ゴ", "hachimarupop": "はちまるポップ", "yomogi": "よもぎ", "zenkurenaido": "ZEN紅道", "yuseimagic": "油性マジック", "kaiseidecol": "解星デコール", "mochiypopone": "モッチーポップ One"]
    static let weightNames = ["auto": "自動", "light": "細め", "regular": "標準", "medium": "やや太め", "bold": "太め"]
    static func notice(_ id: String) -> String? {
        switch id {
        case "yomogi", "zenkurenaido": return "小さいコメントでは線が細く見えます。実際のプレビューで確認してください。"
        case "hachimarupop", "yuseimagic", "kaiseidecol", "mochiypopone": return "タイトル向きの個性的な書体です。小さい文字や長文の読みやすさを確認してください。"
        default: return nil
        }
    }
    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    static func external(_ id: String, weight: String, size: CGFloat) -> UIFont? {
        guard let record = records.first(where: { $0.directory == id }) else { return nil }
        let suffix = weight == "bold" ? "-Bold.ttf" : (weight == "medium" ? "-Medium.ttf" : "-Regular.ttf")
        guard let file = record.files.first(where: { $0.filename.hasSuffix(suffix) }), let name = file.nameTable["6"] else { return nil }
        if descriptors[name] == nil {
            let assetName = "PlateFonts/" + String(file.filename.dropLast(4))
            guard let data = NSDataAsset(name: assetName)?.data, digest(data) == file.sha256,
                  let fonts = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor],
                  let descriptor = fonts.first(where: { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String == name }) else { return nil }
            descriptors[name] = descriptor
        }
        guard let descriptor = descriptors[name] else { return nil }
        return CTFontCreateWithFontDescriptor(descriptor, size, nil) as UIFont
    }
    static func available(_ style: PlateTextStyle) -> Bool {
        guard style.supported else { return false }
        if records.contains(where: { $0.directory == style.fontID }) { return external(style.fontID, weight: style.weightID, size: 12) != nil }
        if style.fontID == "hiramin" { return UIFont(name: "HiraMinProN-W3", size: 12) != nil }
        if style.fontID == "hiramaru" { return UIFont(name: "HiraMaruProN-W4", size: 12) != nil }
        return ["standard", "modern"].contains(style.fontID)
    }
    static func font(_ original: PlateTextStyle?, role: PlateTextRole, size: CGFloat) -> Font {
        let style = original?.supported == true ? original! : PlateTextStyle()
        let weight: Font.Weight = style.weightID == "light" ? .light : (style.weightID == "bold" ? .bold : (style.weightID == "medium" ? .medium : (style.weightID == "auto" && role == .title ? .medium : .regular)))
        if style.fontID == "standard" { return .system(size: size, weight: weight, design: role == .title ? .serif : .default) }
        if style.fontID == "modern" { return .system(size: size, weight: weight) }
        if style.fontID == "hiramin", let f = UIFont(name: style.weightID == "bold" ? "HiraMinProN-W6" : "HiraMinProN-W3", size: size) { return Font(f) }
        if style.fontID == "hiramaru", let f = UIFont(name: "HiraMaruProN-W4", size: size) { return Font(f) }
        if let f = external(style.fontID, weight: style.weightID, size: size) { return Font(f) }
        return font(nil, role: role, size: size)
    }
    static let colors: [(String, String)] = [("チャコール", "#38333D"), ("ブラック", "#171717"), ("ホワイト", "#FFFFFF"), ("シャンパン", "#907245"), ("ローズ", "#B15D78"), ("ラベンダー", "#795B8C"), ("ネイビー", "#344966"), ("セージ", "#4B6E62"), ("コーラル", "#C04463"), ("ポップピンク", "#B43376"), ("ブルー", "#377EA0"), ("パステルピンク", "#E6A5BC"), ("パステル紫", "#C5B3E5")]
    static func color(_ hex: String) -> Color {
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return Color(.sRGB, red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255, opacity: 1)
    }
    static func color(_ style: PlateTextStyle?, role: PlateTextRole, template: PlateTemplate) -> Color {
        if let style, style.supported, let hex = style.hexRGB { return color(hex) }
        return template.ink.opacity(role == .comment ? 0.85 : 1)
    }
    static func hex(_ color: Color) -> String? {
        let cg = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)).cgColor
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let converted = cg.converted(to: space, intent: .relativeColorimetric, options: nil), let c = converted.components, c.count >= 3 else { return nil }
        return String(format: "#%02X%02X%02X", Int((min(1, max(0, c[0])) * 255).rounded()), Int((min(1, max(0, c[1])) * 255).rounded()), Int((min(1, max(0, c[2])) * 255).rounded()))
    }
    static func contrast(_ color: Color, _ paper: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            let h = hex(color) ?? "#000000", n = UInt32(h.dropFirst(), radix: 16) ?? 0
            func linear(_ v: UInt32) -> Double { let x = Double(v) / 255; return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear((n >> 16) & 255) + 0.7152 * linear((n >> 8) & 255) + 0.0722 * linear(n & 255)
        }
        let a = luminance(color), b = luminance(paper)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
    static func licenseText(_ record: Record) -> String {
        guard let data = NSDataAsset(name: "PlateFonts/License-" + record.directory)?.data, digest(data) == record.licenseSHA256,
              let text = String(data: data, encoding: .utf8) else { return "ライセンス資料を読み込めませんでした。" }
        return text
    }
}

struct PlateFontLicensesView: View {
    var body: some View {
        List {
            Text("プレートで使用する外部書体の著作権表示とライセンスです。").font(.footnote)
            ForEach(PlateFontCatalog.records, id: \.directory) { record in
                NavigationLink(record.family + "（" + record.license + "）") {
                    ScrollView { Text(PlateFontCatalog.licenseText(record)).font(.footnote.monospaced()).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding() }
                        .navigationTitle(record.family).navigationBarTitleDisplayMode(.inline)
                }
            }
        }.navigationTitle("フォントライセンス").navigationBarTitleDisplayMode(.inline)
    }
}

// 表示名は保存用IDや型名から分離し、将来の翻訳はこのキーへ追加する。
enum PlateCopy {
    static let name = String(localized: "plate.feature.name", defaultValue: "作品プレート（仮称）")
    static let editorTitle = String(localized: "plate.editor.title", defaultValue: "作品プレート")
    static let tab = String(localized: "plate.tab.title", defaultValue: "プレート")
    static let elegant = String(localized: "plate.template.elegant", defaultValue: "Elegant")
    static let noir = String(localized: "plate.template.noir", defaultValue: "Noir")
    static let sweet = String(localized: "plate.template.sweet", defaultValue: "Sweet")
    static let recipe = String(localized: "plate.template.recipe", defaultValue: "Recipe")
}

enum PlateTemplate: String, CaseIterable, Identifiable, Codable {
    case elegant, noir, sweet, recipe
    var id: String { rawValue }
    var title: String {
        switch self {
        case .elegant: return PlateCopy.elegant
        case .noir: return PlateCopy.noir
        case .sweet: return PlateCopy.sweet
        case .recipe: return PlateCopy.recipe
        }
    }
    var detail: String {
        switch self {
        case .elegant: return "大きな写真とパールの余白"
        case .noir: return "縦の写真と重厚な銀の輪郭"
        case .sweet: return "丸い写真枠と柔らかなリボン"
        case .recipe: return "写真と選択した用品"
        }
    }
    var ink: Color { self == .noir ? Color(red: 0.96, green: 0.93, blue: 0.90) : Color(red: 0.22, green: 0.20, blue: 0.24) }
    var metal: Color {
        switch self {
        case .elegant, .recipe: return Color(red: 0.62, green: 0.49, blue: 0.29)
        case .noir: return Color(red: 0.69, green: 0.72, blue: 0.77)
        case .sweet: return Color(red: 0.64, green: 0.43, blue: 0.51)
        }
    }
    var paper: Color {
        switch self {
        case .elegant: return Color(red: 0.96, green: 0.93, blue: 0.86)
        case .noir: return Color(red: 0.10, green: 0.085, blue: 0.12)
        case .sweet: return Color(red: 0.96, green: 0.88, blue: 0.91)
        case .recipe: return Color(red: 0.92, green: 0.94, blue: 0.90)
        }
    }
    // 構図は360×450の論理キャンバスで定義し、端末座標を状態へ保存しない。
    var photoRect: CGRect {
        switch self {
        case .elegant: return CGRect(x: 28, y: 91, width: 304, height: 252)
        case .noir: return CGRect(x: 22, y: 25, width: 216, height: 323)
        case .sweet: return CGRect(x: 49, y: 90, width: 262, height: 271)
        case .recipe: return CGRect(x: 22, y: 85, width: 316, height: 191)
        }
    }
    var photoRadius: CGFloat { self == .sweet ? 65 : (self == .noir ? 4 : 17) }
}

enum PlateBackground: String, CaseIterable, Identifiable, Codable {
    case signature, solid, gradient
    var id: String { rawValue }
    var title: String {
        switch self { case .signature: return "素材"; case .solid: return "単色"; case .gradient: return "グラデーション" }
    }
}

enum PlateFrame: String, CaseIterable, Identifiable, Codable {
    case signature, metal, simple, glass
    var id: String { rawValue }
    var title: String {
        switch self { case .signature: return "標準"; case .metal: return "メタル"; case .simple: return "シンプル"; case .glass: return "ガラス" }
    }
}

// UIImageのsizeだけに依存せず、EXIFの向きを含む表示上の縦横を共有する。
nonisolated enum PlatePhotoGeometry {
    static func pixelSize(_ image: UIImage) -> CGSize {
        let raw = image.cgImage.map { CGSize(width: $0.width, height: $0.height) }
            ?? CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        switch image.imageOrientation {
        case .left, .right, .leftMirrored, .rightMirrored:
            return CGSize(width: raw.height, height: raw.width)
        default: return raw
        }
    }
}

struct PlatePhotoAdjustment: Codable, Equatable {
    var zoom: Double = 1
    var x: Double = 0
    var y: Double = 0
    mutating func constrain() {
        zoom = zoom.isFinite ? min(3, max(1, zoom)) : 1
        x = x.isFinite ? min(1, max(-1, x)) : 0
        y = y.isFinite ? min(1, max(-1, y)) : 0
    }
    func overflow(in viewport: CGSize, image: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return .zero }
        let fill = max(viewport.width / image.width, viewport.height / image.height) * zoom
        return CGSize(width: max(0, (image.width * fill - viewport.width) / 2), height: max(0, (image.height * fill - viewport.height) / 2))
    }
}

// 元データからコピーした値だけを編集し、管理オブジェクトや保存処理を持たない。
struct PlateDraft: Equatable {
    let sourceEntryID: UUID
    let photoID: UUID?
    let inheritedProductIDs: Set<UUID>
    var unavailableSourceProducts = 0
    var template: PlateTemplate = .elegant
    var title: String
    var date: String
    var comment: String
    var products: [PlateProduct]
    var background: PlateBackground = .signature
    var frame: PlateFrame = .signature
    var photoRotationQuarterTurns = 0
    var titleTextStyle: PlateTextStyle? = nil
    var commentTextStyle: PlateTextStyle? = nil
    var textStylesSupported: Bool { (titleTextStyle?.supported ?? true) && (commentTextStyle?.supported ?? true) }
    private(set) var photos: [PlateTemplate: PlatePhotoAdjustment] = [:]
    init(sourceEntryID: UUID, photoID: UUID?, inheritedProductIDs: Set<UUID>, title: String, date: String, comment: String, products: [PlateProduct], unavailableSourceProducts: Int = 0) {
        self.sourceEntryID = sourceEntryID; self.photoID = photoID
        self.inheritedProductIDs = inheritedProductIDs; self.title = title
        self.date = date; self.comment = comment; self.unavailableSourceProducts = unavailableSourceProducts
        var seen = Set<UUID>()
        self.products = products.filter { seen.insert($0.id).inserted }
    }
    var photo: PlatePhotoAdjustment {
        get { photos[template] ?? PlatePhotoAdjustment() }
        set { var value = newValue; value.constrain(); photos[template] = value }
    }
    mutating func resetPhotoComposition() { photos = [:]; photoRotationQuarterTurns = 0 }
    static let recipeLimit = 3
    var recipeOverflow: Int { max(0, products.count - Self.recipeLimit) }
    mutating func toggleProduct(_ product: PlateProduct) {
        if let index = products.firstIndex(where: { $0.id == product.id }) { products.remove(at: index) }
        else { products.append(product) }
    }
    mutating func moveProduct(id: UUID, offset: Int) {
        guard let index = products.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard products.indices.contains(target) else { return }
        let product = products.remove(at: index); products.insert(product, at: target)
    }
}

private enum PlateTool: String, CaseIterable, Identifiable {
    case template, photo, background, frame, text, decoration, items, adjustment
    var id: String { rawValue }
    var title: String {
        switch self {
        case .template: return "テンプレート"; case .photo: return "写真"; case .background: return "背景"
        case .frame: return "フレーム"; case .text: return "文字"; case .decoration: return "装飾"
        case .items: return "用品"; case .adjustment: return "調整"
        }
    }
    var symbol: String {
        switch self {
        case .template: return "rectangle.stack"; case .photo: return "photo"; case .background: return "circle.lefthalf.filled"
        case .frame: return "square.on.square"; case .text: return "textformat"; case .decoration: return "sparkles"
        case .items: return "square.grid.2x2"; case .adjustment: return "slider.horizontal.3"
        }
    }
}

struct PlateEditorView: View {
    private enum TextFieldID: Hashable { case title, date, comment }
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var draft: PlateDraft
    let onCancel: () -> Void
    let onChooseProducts: () -> Void
    @ObservedObject var session: PlateEditingSession
    let onSaved: () -> Void
    @State private var confirmingMissingPhoto = false
    @State private var tool: PlateTool = .template
    @State private var choosingFont: PlateTextRole?
    @State private var resetUnknown: PlateTextRole?
    @State private var textRole: PlateTextRole = .title
    @State private var editingText: PlateTextRole?
    @State private var photoSelection: PhotosPickerItem?
    @State private var photoImportTask: Task<Void, Never>?
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @State private var weightNotice: String?
    @FocusState private var focusedField: TextFieldID?

    private var backgroundPreset: GlassTheme.BackgroundPreset {
        GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne
    }
    private var editorPalette: GlassTheme.DesignCardPalette {
        NailAppearance.designPalette(backgroundPreset.refinedSurfacePalette, choice: NailAppearance.Document.decode(appearanceRaw).resolved(.design))
    }
    private var editorDark: Bool {
        let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.design)
        return choice.flatMap { $0.changesColor ? $0.dark : nil } ?? (backgroundPreset == .noirGold || backgroundPreset == .noirSilver)
    }

    var body: some View {
            GeometryReader { page in
                // 設定領域を先に確保し、残りの高さで作品比率を保ったプレビューを表示する。
                let panelBudget = page.size.height * (typeSize.isAccessibilitySize ? 0.52 : 0.38)
                let previewHeight = focusedField != nil ? page.size.height * 0.18 : max(0, page.size.height - panelBudget - (typeSize.isAccessibilitySize ? 190 : 160))
                let width = min(max(0, page.size.width - 32), previewHeight * 0.8)
                VStack(spacing: 10) {
                    Button { focusedField = nil; onChooseProducts() } label: {
                        HStack(spacing: 8) {
                            Text("使用用品").font(.subheadline.weight(.semibold))
                            Spacer(minLength: 4)
                            Text("\(draft.products.count)点").font(.subheadline)
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .padding(.horizontal, 12).frame(minHeight: 44)
                        .background(editorPalette.glowFillMid.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(editorPalette.outerStrokeEnd.opacity(0.30), lineWidth: 0.7))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("plate.products")
                    .accessibilityHint("掲載する用品を編集します。元の記録や用品は変更しません。")
                    PlateCanvasView(draft: $draft, image: session.image, loadingPhoto: session.photoState == .loading, photoEditing: tool == .photo || tool == .adjustment)
                        .frame(width: 360, height: 450)
                        .scaleEffect(width / 360, anchor: .topLeading)
                        .frame(width: width, height: width * 1.25, alignment: .topLeading)
                        .accessibilityIdentifier("plate.preview")
                    toolBar
                    if tool == .text && !typeSize.isAccessibilitySize {
                        Text("選べる文字の太さは、書体によって異なります。")
                            .font(.caption).foregroundStyle(editorPalette.tagText).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("plate.weight.explanation")
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("プレートの変更は元の記録・用品には反映されません")
                                .font(.caption).foregroundStyle(editorPalette.tagText).fixedSize(horizontal: false, vertical: true)
                            if let photoNotice = session.photoNotice {
                                Text(photoNotice).font(.caption).foregroundStyle(editorPalette.tagText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("plate.photoNotice")
                            }
                            toolPanel
                        }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .background(LinearGradient(colors: [editorPalette.glowFillTop, editorPalette.glowFillBottom], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(editorPalette.tagStroke, lineWidth: 0.7))
                    .accessibilityIdentifier("plate.panel")
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background { GlassBackgroundView(refined: true, appearanceArea: .design) { Color.clear } }
            .foregroundStyle(editorPalette.titleText)
            .navigationTitle(PlateCopy.editorTitle).navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(editorDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(session.saving ? "保存中…" : "保存") {
                        focusedField = nil
                        if session.photoState == .missingSource { confirmingMissingPhoto = true }
                        else { Task { if await session.save() { onSaved() } } }
                    }
                    .disabled(session.saving || session.importingPhoto || session.photoState == .loading || session.photoState == .damagedSaved || !draft.textStylesSupported)
                    .accessibilityIdentifier("plate.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if editingText == nil {
                        Spacer()
                        Button("キーボードを閉じる") { focusedField = nil }
                    }
                }
            }
        .tint(editorPalette.titleIcon)
        .environment(\.colorScheme, editorDark ? .dark : .light)
        .task { await session.loadPhoto() }
        .modifier(NailTabExitProtection(dirty: session.dirty, blocked: session.saving || session.importingPhoto))
        .modifier(NailEditorExit(dirty: session.dirty, blocked: session.saving || session.importingPhoto, onReturn: onCancel))
        .disabled(session.saving)
        .navigationBarBackButtonHidden(true)
        .onChange(of: textRole) { _, _ in focusedField = nil; weightNotice = nil }
        .sheet(item: $choosingFont) { role in fontSheet(role) }
        .sheet(item: $editingText) { role in
            PlateTextInputSheet(role: role, initialText: role == .title ? draft.title : draft.comment) { value in
                // 入力対象はシートを開いた時点のroleに固定する。作品の保存は行わない。
                if role == .title { draft.title = value } else { draft.comment = value }
            }
        }
        .onChange(of: photoSelection) { _, item in
            photoImportTask?.cancel()
            guard let item else { return }
            let token = session.beginPhotoImport()
            photoImportTask = Task {
                do {
                    let data = try await item.loadTransferable(type: Data.self)
                    await session.finishPhotoImport(data, token: token)
                } catch { session.failPhotoImport(token: token) }
                if session.isCurrentPhotoImport(token) { photoSelection = nil }
            }
        }
        .onDisappear { photoImportTask?.cancel(); session.cancelPhotoImport() }
        .alert("写真を読み込めませんでした", isPresented: Binding(get: { session.photoImportError != nil }, set: { if !$0 { session.photoImportError = nil } })) {
            Button("OK") { session.photoImportError = nil }
        } message: { Text(session.photoImportError ?? "") }
        .confirmationDialog("未対応の文字設定を標準に戻しますか？ この文字の保存情報を置き換えます。", isPresented: Binding(get: { resetUnknown != nil }, set: { if !$0 { resetUnknown = nil } })) {
            Button("標準に戻す", role: .destructive) { if let role = resetUnknown { styleBinding(role).wrappedValue = PlateTextStyle() }; resetUnknown = nil }
            Button("編集を続ける", role: .cancel) { resetUnknown = nil }
        }
        .alert("写真を読み込めません", isPresented: $confirmingMissingPhoto) {
            Button("写真なしで保存") { Task { if await session.save() { onSaved() } } }
            Button("編集を続ける", role: .cancel) {}
        } message: { Text("元写真を保存できません。写真なしのプレートとして保存しますか？ 元の記録は変更しません。") }
    }

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PlateTool.allCases) { item in
                    Button { focusedField = nil; tool = item } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.symbol).font(.system(size: 18))
                            Text(item.title).font(.caption)
                            if item == .decoration { Text("表示のみ").font(.caption2) }
                        }
                        .padding(.horizontal, 9).padding(.vertical, 8)
                        .frame(minWidth: 60, minHeight: 52)
                        .background(tool == item ? editorPalette.glowFillTop : editorPalette.glowFillBottom.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(editorPalette.outerStrokeEnd.opacity(tool == item ? 0.85 : 0.25), lineWidth: tool == item ? 1.2 : 0.7))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("plate.tool.\(item.rawValue)")
                    .accessibilityAddTraits(tool == item ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder private var toolPanel: some View {
        switch tool {
        case .template:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
                ForEach(PlateTemplate.allCases) { item in
                    Button { draft.template = item } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.semibold))
                            Text(item.detail).font(.caption).foregroundStyle(editorPalette.tagText)
                        }
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(10)
                        .background(draft.template == item ? editorPalette.glowFillTop : editorPalette.glowFillBottom.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(editorPalette.outerStrokeEnd.opacity(draft.template == item ? 0.8 : 0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("plate.template.\(item.rawValue)")
                    .accessibilityAddTraits(draft.template == item ? .isSelected : [])
                }
            }
        case .photo, .adjustment:
            VStack(alignment: .leading, spacing: 10) {
                PhotosPicker(selection: $photoSelection, matching: .images) {
                    Label("写真を選択・差し替え", systemImage: "photo.badge.plus").frame(minHeight: 44)
                }.disabled(session.saving || session.importingPhoto).accessibilityIdentifier("plate.photo.choose")
                if session.importingPhoto { ProgressView("写真を準備中") }
                Text("差し替えると全テンプレートの位置・倍率・回転を初期化します。作品を保存するまで元の保存写真は変更しません。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
                HStack {
                    Button { draft.photoRotationQuarterTurns = (draft.photoRotationQuarterTurns + 3) % 4 } label: {
                        Label("左90°", systemImage: "rotate.left").frame(maxWidth: .infinity, minHeight: 44)
                    }.accessibilityIdentifier("plate.photo.rotate.left")
                    Button { draft.photoRotationQuarterTurns = (draft.photoRotationQuarterTurns + 1) % 4 } label: {
                        Label("右90°", systemImage: "rotate.right").frame(maxWidth: .infinity, minHeight: 44)
                    }.accessibilityIdentifier("plate.photo.rotate.right")
                }.disabled(session.image == nil || session.importingPhoto)
                Text("写真をドラッグ、またはスライダーで調整できます。端を越えて移動しません。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
                adjustmentSlider("倍率", keyPath: \.zoom, range: 1...3)
                adjustmentSlider("左右", keyPath: \.x, range: -1...1)
                adjustmentSlider("上下", keyPath: \.y, range: -1...1)
                Button("このテンプレートの写真を元に戻す") { draft.photo = PlatePhotoAdjustment() }
                    .frame(minHeight: 44).accessibilityIdentifier("plate.photo.reset")
            }
        case .background:
            VStack(alignment: .leading, spacing: 12) {
                Text("背景の表現").font(.subheadline.weight(.semibold))
                Picker("背景", selection: $draft.background) {
                    ForEach(PlateBackground.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.inline).labelsHidden().accessibilityIdentifier("plate.background")
            }
        case .frame:
            VStack(alignment: .leading, spacing: 12) {
                Text("写真を引き立てる輪郭").font(.subheadline.weight(.semibold))
                Picker("フレーム", selection: $draft.frame) {
                    ForEach(PlateFrame.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.inline).labelsHidden().accessibilityIdentifier("plate.frame")
            }
        case .text:
            VStack(alignment: .leading, spacing: 10) {
                Picker("編集する文字", selection: $textRole) {
                    Text("タイトル").tag(PlateTextRole.title)
                    Text("コメント").tag(PlateTextRole.comment)
                }.pickerStyle(.segmented).frame(minHeight: 44).accessibilityIdentifier("plate.text.target")
                if typeSize.isAccessibilitySize {
                    Text("選べる文字の太さは、書体によって異なります。")
                        .font(.caption).foregroundStyle(editorPalette.tagText)
                        .accessibilityIdentifier("plate.weight.explanation")
                }
                Button { focusedField = nil; editingText = textRole } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(textRole.label + "を編集").font(.caption)
                            let value = textRole == .title ? draft.title : draft.comment
                            Text(value.isEmpty ? "タップして入力" : value).lineLimit(3).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "square.and.pencil")
                    }.padding(12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(editorPalette.glowFillTop, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityIdentifier("plate.text.edit." + textRole.rawValue)
                textStyleControls(textRole)
                TextField("制作日", text: $draft.date).focused($focusedField, equals: .date).accessibilityIdentifier("plate.date")
                Text("文字は各テンプレートの表示枠に収まる範囲で表示します。入力した全文は切替後も保持します。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
            }.textFieldStyle(.roundedBorder)
        case .decoration:
            Text("テンプレート固有の装飾を表示しています。装飾の追加・自由配置は今後対応予定です。")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
        case .items:
            VStack(alignment: .leading, spacing: 10) {
                Text("選択中の用品：\(draft.products.count)件").font(.subheadline.weight(.semibold))
                Text(draft.recipeOverflow > 0
                     ? "Recipeの表示は先頭3件です。残り\(draft.recipeOverflow)件は非表示ですが、選択は保持しています。掲載順・件数は選び直せます。"
                     : "Recipeに掲載順で表示します。他のテンプレートでも選択は保持します。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
                Button("用品を選び直す", action: onChooseProducts)
                    .frame(minHeight: 44).accessibilityIdentifier("plate.reselectProducts")
                ForEach(draft.products) { product in
                    Text(product.name).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                Text("購入価格・購入場所・商品URLは掲載しません。長い品名は作品上の枠内で省略される場合があります。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
            }
        }
    }

    private func adjustmentSlider(_ title: String, keyPath: WritableKeyPath<PlatePhotoAdjustment, Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.caption)
            Slider(value: Binding(get: { draft.photo[keyPath: keyPath] }, set: { value in
                var photo = draft.photo; photo[keyPath: keyPath] = value; draft.photo = photo
            }), in: range)
            .accessibilityLabel(title).accessibilityIdentifier("plate.photo.\(title)")
        }
    }

    private func styleBinding(_ role: PlateTextRole) -> Binding<PlateTextStyle> {
        Binding(get: { (role == .title ? draft.titleTextStyle : draft.commentTextStyle) ?? PlateTextStyle() }, set: { value in
            let normalized: PlateTextStyle? = value.isLegacy ? nil : value
            if role == .title { draft.titleTextStyle = normalized } else { draft.commentTextStyle = normalized }
        })
    }
    private func textStyleControls(_ role: PlateTextRole) -> some View {
        let binding = styleBinding(role), style = binding.wrappedValue
        return VStack(alignment: .leading, spacing: 10) {
            if !style.supported {
                Text("未対応の文字設定があります。元の情報を保持して標準で表示しています。上書き保存は停止しています。").font(.caption).foregroundStyle(.red)
            }
            Button { focusedField = nil; choosingFont = role } label: {
                HStack { Text("書体"); Spacer(); Text(PlateFontCatalog.names[style.fontID] ?? "未対応"); Image(systemName: "chevron.right") }.frame(minHeight: 44)
            }.disabled(!style.supported).accessibilityLabel(role.label + "の書体").accessibilityIdentifier("plate.font." + role.rawValue)
            Menu {
                ForEach(PlateTextStyle.weights(style.fontID), id: \.self) { weight in
                    Button { var v = binding.wrappedValue; v.weightID = weight; binding.wrappedValue = v } label: {
                        if weight == style.weightID { Label(PlateFontCatalog.weightNames[weight] ?? weight, systemImage: "checkmark") }
                        else { Text(PlateFontCatalog.weightNames[weight] ?? weight) }
                    }
                }
            } label: {
                HStack { Text(role.label + "の太さ"); Spacer(); Text(PlateFontCatalog.weightNames[style.weightID] ?? "未対応"); Image(systemName: "chevron.up.chevron.down") }.frame(minHeight: 44)
            }.disabled(!style.supported).accessibilityIdentifier("plate.weight." + role.rawValue)
            if PlateTextStyle.weights(style.fontID).filter({ $0 != "auto" }).count == 1 {
                Text("この書体の実ウェイトは1種類です。自動と標準は同じ太さになる場合があります。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
            }
            if let notice = PlateFontCatalog.notice(style.fontID) { Text(notice).font(.caption).foregroundStyle(editorPalette.tagText) }
            if style.supported && !PlateFontCatalog.available(style) { Text("この書体を利用できないため標準書体で表示しています。選択情報は保持します。").font(.caption).foregroundStyle(editorPalette.tagText) }
            if let notice = weightNotice { Text(notice).font(.caption).foregroundStyle(editorPalette.tagText) }
            Button { var v = binding.wrappedValue; v.setColor(nil); binding.wrappedValue = v } label: {
                Label("自動（テンプレート従来色）", systemImage: style.hexRGB == nil ? "checkmark.circle.fill" : "circle").frame(minHeight: 44)
            }.disabled(!style.supported).accessibilityIdentifier("plate.color.auto." + role.rawValue)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108))], spacing: 6) {
                ForEach(PlateFontCatalog.colors, id: \.1) { name, hex in
                    Button { var v = binding.wrappedValue; v.setColor(hex); binding.wrappedValue = v } label: {
                        HStack(spacing: 6) {
                            Circle().fill(PlateFontCatalog.color(hex)).overlay(Circle().stroke(.gray, lineWidth: 0.5)).frame(width: 14, height: 14)
                            Text(name).font(.caption).fixedSize(horizontal: false, vertical: true)
                            if style.hexRGB == hex { Image(systemName: "checkmark").font(.caption) }
                        }.frame(maxWidth: .infinity, minHeight: 44)
                    }.disabled(!style.supported).accessibilityLabel(role.label + "の文字色：" + name)
                        .accessibilityAddTraits(style.hexRGB == hex ? [.isSelected] : [])
                }
            }
            ColorPicker(selection: Binding(get: { PlateFontCatalog.color(binding.wrappedValue, role: role, template: draft.template) }, set: { color in
                if let hex = PlateFontCatalog.hex(color) { var v = binding.wrappedValue; v.setColor(hex); binding.wrappedValue = v }
            }), supportsOpacity: false) { Text(role.label + "の自由色").frame(minHeight: 44) }.disabled(!style.supported).accessibilityIdentifier("plate.color.custom." + role.rawValue)
            if let hex = style.hexRGB {
                Text(hex).font(.caption.monospaced())
                if PlateFontCatalog.contrast(PlateFontCatalog.color(hex), draft.template.paper) < 4.5 {
                    Text("背景と近い色です。実際のプレビューで読みやすさを確認してください。色は自動変更しません。").font(.caption).foregroundStyle(editorPalette.tagText)
                }
            }
            Button {
                if style.supported { binding.wrappedValue = PlateTextStyle() } else { resetUnknown = role }
            } label: { Text(role.label + "を標準に戻す").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading) }.accessibilityIdentifier("plate.text.reset." + role.rawValue)
        }
    }
    private func fontSheet(_ role: PlateTextRole) -> some View {
        NavigationStack {
            List {
                ForEach(PlateTextStyle.fontIDs, id: \.self) { id in
                    let selected = styleBinding(role).wrappedValue.fontID == id
                    Button {
                        var value = styleBinding(role).wrappedValue; value.fontID = id
                        if !PlateTextStyle.weights(id).contains(value.weightID) { value.weightID = "regular"; weightNotice = "この書体に対応する標準の太さへ変更しました。" }
                        styleBinding(role).wrappedValue = value; choosingFont = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text(PlateFontCatalog.names[id] ?? id).font(.headline); Spacer(); if selected { Image(systemName: "checkmark") } }
                            let sample: PlateTextStyle = { var s = PlateTextStyle(); s.fontID = id; return s }()
                            Text("指先の彩り Nail 2026").font(PlateFontCatalog.font(sample, role: role, size: role == .title ? 22 : 16))
                            if let notice = PlateFontCatalog.notice(id) { Text(notice).font(.caption).foregroundStyle(editorPalette.tagText) }
                        }.foregroundStyle(.primary).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.accessibilityAddTraits(selected ? [.isSelected] : []).accessibilityIdentifier("plate.font.option." + id)
                }
            }.navigationTitle(role.label + "の書体").navigationBarTitleDisplayMode(.inline)
                .toolbarColorScheme(editorDark ? .dark : .light, for: .navigationBar)
                .scrollContentBackground(.hidden)
                .background { GlassBackgroundView(refined: true, appearanceArea: .design) { Color.clear } }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { choosingFont = nil } } }
        }.environment(\.colorScheme, editorDark ? .dark : .light).tint(editorPalette.titleIcon)
    }


}

private struct PlateTextInputSheet: View {
    let role: PlateTextRole
    let onApply: (String) -> Void
    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue

    init(role: PlateTextRole, initialText: String, onApply: @escaping (String) -> Void) {
        self.role = role; self.onApply = onApply; _text = State(initialValue: initialText)
    }
    var body: some View {
        let preset = GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne
        let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.design)
        let palette = NailAppearance.designPalette(preset.refinedSurfacePalette, choice: choice)
        let dark = choice.flatMap { $0.changesColor ? $0.dark : nil } ?? (preset == .noirGold || preset == .noirSilver)
        NavigationStack {
            GlassBackgroundView(refined: true, appearanceArea: .design) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(role == .title ? "作品名を入力してください。既存の改行も保持します。" : "コメントを複数行で入力できます。")
                        .font(.subheadline).foregroundStyle(palette.tagText)
                    TextEditor(text: $text)
                        .font(role == .title ? .title3 : .body)
                        .focused($focused).scrollContentBackground(.hidden)
                        .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(palette.glowFillMid, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.tagStroke, lineWidth: 1))
                        .accessibilityLabel(role.label).accessibilityIdentifier("plate.text.input." + role.rawValue)
                    Text("「入力を反映」では作品は保存されません。")
                        .font(.caption).foregroundStyle(palette.tagText)
                }.padding(16).foregroundStyle(palette.titleText)
            }
            .navigationTitle(role.label).navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(dark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.accessibilityIdentifier("plate.text.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("入力を反映") { onApply(text); dismiss() }.accessibilityIdentifier("plate.text.apply")
                }
            }
        }
        .environment(\.colorScheme, dark ? .dark : .light).tint(palette.titleIcon)
        .presentationDetents([.large]).presentationDragIndicator(.visible)
        .onAppear { focused = true }
    }
}

struct PlateCanvasView: View {
    @Binding var draft: PlateDraft
    var image: UIImage? = nil
    var loadingPhoto = false
    var photoEditing = false

    var body: some View {
        let template = draft.template
        ZStack(alignment: .topLeading) {
            PlateSurface(template: template, style: draft.background)
            RoundedRectangle(cornerRadius: 12).inset(by: 8)
                .strokeBorder(template.metal.opacity(0.55), lineWidth: 0.7)
            PlatePhotoViewport(adjustment: Binding(get: { draft.photo }, set: { draft.photo = $0 }), image: image, loading: loadingPhoto, template: template, frame: draft.frame, editing: photoEditing, quarterTurns: draft.photoRotationQuarterTurns)
                .frame(width: template.photoRect.width, height: template.photoRect.height)
                .offset(x: template.photoRect.minX, y: template.photoRect.minY)
            composition
        }
        .frame(width: 360, height: 450).clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.16), radius: 9, x: 1, y: 5)
        // 作品の構図は操作UIの文字拡大やアプリのテーマから独立させる。
        .dynamicTypeSize(.large).environment(\.colorScheme, .light)
    }

    @ViewBuilder private var composition: some View {
        switch draft.template {
        case .elegant:
            heading(x: 28, y: 25, width: 304, alignment: .center)
            caption(draft.date, size: 10).frame(width: 304).offset(x: 28, y: 69)
            comment(size: 12).frame(width: 286, height: 55).offset(x: 37, y: 365)
            Rectangle().fill(draft.template.metal.opacity(0.5)).frame(width: 66, height: 0.7).offset(x: 147, y: 356)
        case .noir:
            VStack(alignment: .leading, spacing: 16) {
                Text("NOIR").font(.system(size: 14, weight: .light, design: .serif)).tracking(2)
                Rectangle().fill(draft.template.metal).frame(width: 42, height: 1)
                caption(draft.date, size: 10)
                Text("NAIL\nCOLLECTION").font(.system(size: 9, weight: .medium)).tracking(1.5)
            }
            .foregroundStyle(draft.template.ink).frame(width: 84, alignment: .leading).offset(x: 253, y: 66)
            heading(x: 22, y: 362, width: 316, alignment: .leading)
            comment(size: 11).frame(width: 316, height: 42, alignment: .topLeading).offset(x: 22, y: 402)
        case .sweet:
            heading(x: 34, y: 26, width: 292, alignment: .center)
            caption(draft.date, size: 10).frame(width: 292).offset(x: 34, y: 68)
            Image(systemName: "heart.fill").font(.system(size: 15)).foregroundStyle(draft.template.metal.opacity(0.65)).offset(x: 26, y: 170)
            Image(systemName: "heart").font(.system(size: 19)).foregroundStyle(draft.template.metal).offset(x: 310, y: 289)
            PlateRibbon().fill(draft.template.metal.opacity(0.8)).frame(width: 65, height: 38).offset(x: 148, y: 76)
            comment(size: 12).frame(width: 286, height: 56).offset(x: 37, y: 377)
        case .recipe:
            heading(x: 22, y: 18, width: 316, alignment: .leading)
            caption(draft.date + "  /  NAIL RECIPE", size: 9).frame(width: 316, alignment: .leading).offset(x: 22, y: 60)
            VStack(spacing: 7) {
                if draft.products.isEmpty {
                    caption("用品は選択されていません", size: 12).frame(height: 70)
                } else {
                    ForEach(Array(draft.products.prefix(PlateDraft.recipeLimit).enumerated()), id: \.element.id) { index, product in
                        recipeRow(String(format: "%02d", index + 1), product.name)
                    }
                }
            }.frame(width: 316).offset(x: 22, y: 293)
            if draft.recipeOverflow > 0 {
                caption("掲載3 / 選択\(draft.products.count)件 · 他\(draft.recipeOverflow)件は非表示", size: 8)
                    .frame(width: 316, alignment: .leading).offset(x: 22, y: 389)
            }
            comment(size: 11).frame(width: 316, height: 40, alignment: .topLeading).offset(x: 22, y: 403)
        }
    }

    private func heading(x: CGFloat, y: CGFloat, width: CGFloat, alignment: Alignment) -> some View {
        Text(draft.title).font(PlateFontCatalog.font(draft.titleTextStyle, role: .title, size: 22))
            .foregroundStyle(PlateFontCatalog.color(draft.titleTextStyle, role: .title, template: draft.template)).lineLimit(2).minimumScaleFactor(0.65)
            .frame(width: width, height: 42, alignment: alignment).offset(x: x, y: y).allowsHitTesting(false)
    }
    private func caption(_ text: String, size: CGFloat) -> some View {
        Text(text).font(.system(size: size)).foregroundStyle(draft.template.ink.opacity(0.85))
            .lineLimit(3).fixedSize(horizontal: false, vertical: true).allowsHitTesting(false)
    }
    private func comment(size: CGFloat) -> some View {
        Text(draft.comment).font(PlateFontCatalog.font(draft.commentTextStyle, role: .comment, size: size))
            .foregroundStyle(PlateFontCatalog.color(draft.commentTextStyle, role: .comment, template: draft.template))
            .lineLimit(3).fixedSize(horizontal: false, vertical: true).allowsHitTesting(false)
    }
    private func recipeRow(_ number: String, _ name: String) -> some View {
        HStack(spacing: 10) {
            Text(number).font(.system(size: 10, weight: .semibold)).foregroundStyle(draft.template.metal)
            Text(name).font(.system(size: 11, weight: .medium)).lineLimit(1)
            Spacer(minLength: 4)
        }
        .foregroundStyle(draft.template.ink).padding(.horizontal, 10).frame(height: 28)
        .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct PlateSurface: View {
    let template: PlateTemplate
    let style: PlateBackground
    var body: some View {
        let reflection = template == .noir ? Color(red: 0.30, green: 0.07, blue: 0.15) : template.metal
        ZStack {
            template.paper
            if style != .solid {
                LinearGradient(colors: [template.paper, reflection.opacity(template == .noir ? 0.55 : 0.22), template.paper], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            if style == .signature {
                Canvas { context, size in
                    for index in 0..<4 {
                        let y = CGFloat(index) * 125 - 80
                        var path = Path(); path.move(to: CGPoint(x: -30, y: y))
                        path.addCurve(to: CGPoint(x: size.width + 40, y: y + 240), control1: CGPoint(x: size.width * 0.12, y: y + 240), control2: CGPoint(x: size.width * 0.64, y: y - 15))
                        context.stroke(path, with: .linearGradient(Gradient(colors: [.white.opacity(template == .noir ? 0.07 : 0.32), template.metal.opacity(0.12), .clear]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)), style: StrokeStyle(lineWidth: 35, lineCap: .round))
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct PlateRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.midY), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.midY), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.width * 0.66, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.width * 0.34, y: rect.maxY));path.closeSubpath()
        return path
    }
}

private struct PlatePhotoViewport: View {
    @Binding var adjustment: PlatePhotoAdjustment
    let image: UIImage?
    let loading: Bool
    let template: PlateTemplate
    let frame: PlateFrame
    let editing: Bool
    let quarterTurns: Int
    @State private var dragStart: PlatePhotoAdjustment?

    var body: some View {
        GeometryReader { proxy in
            let imageSize = image.map(PlatePhotoGeometry.pixelSize) ?? CGSize(width: 4, height: 5)
            let rotatedSize = quarterTurns % 2 == 0 ? imageSize : CGSize(width: imageSize.height, height: imageSize.width)
            let overflow = adjustment.overflow(in: proxy.size, image: rotatedSize)
            let shape = RoundedRectangle(cornerRadius: template.photoRadius)
            ZStack {
                if let image {
                    let fill = max(proxy.size.width / rotatedSize.width, proxy.size.height / rotatedSize.height) * adjustment.zoom
                    Image(uiImage: image).resizable()
                        .frame(width: imageSize.width * fill, height: imageSize.height * fill)
                        .rotationEffect(.degrees(Double(quarterTurns) * 90))
                        .offset(x: adjustment.x * overflow.width, y: adjustment.y * overflow.height)
                } else {
                    Color.gray.opacity(0.15)
                    if loading { ProgressView("写真を読み込み中").font(.caption).tint(template.ink) }
                    else { Label("写真なし", systemImage: "photo").font(.caption).foregroundStyle(template.ink) }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(shape)
            .overlay { photoFrame(shape) }
            .shadow(color: .black.opacity(template == .noir ? 0.35 : 0.16), radius: 5, x: 1, y: 3)
            .contentShape(shape)
            .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                guard editing, image != nil else { return }
                if dragStart == nil { dragStart = adjustment }
                guard var start = dragStart else { return }
                start.x += overflow.width > 0.1 ? value.translation.width / overflow.width : 0
                start.y += overflow.height > 0.1 ? value.translation.height / overflow.height : 0
                start.constrain(); adjustment = start
            }.onEnded { _ in dragStart = nil })
            .overlay {
                if editing { shape.stroke(Color.blue.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 4])).padding(-3).allowsHitTesting(false).accessibilityHidden(true) }
            }
            .accessibilityLabel(image == nil ? "写真の代替表示" : "選択したデザインの写真")
            .accessibilityHint(editing ? "位置調整は下のスライダーでも操作できます" : "写真ツールで位置と倍率を調整できます")
            .accessibilityIdentifier("plate.photo.viewport")
        }
        .onChange(of: template) { _, _ in dragStart = nil }
        .onChange(of: quarterTurns) { _, _ in dragStart = nil }
    }

    @ViewBuilder private func photoFrame(_ shape: RoundedRectangle) -> some View {
        let metal = template.metal
        let width: CGFloat = frame == .simple ? 0.8 : (frame == .metal ? 3 : 1.8)
        shape.strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.95), location: 0), .init(color: metal, location: 0.23), .init(color: metal.opacity(0.45), location: 0.48), .init(color: .white.opacity(0.9), location: 0.65), .init(color: metal, location: 1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width)
        if frame != .simple {
            shape.inset(by: frame == .glass ? 5 : 3.5)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.7), metal.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: frame == .glass ? 1.4 : 0.6)
        }
    }
}

// 写真とDraftは編集セッションに固定し、用品画面への往復で再取得しない。
@MainActor final class PlateEditingSession: ObservableObject {
    enum PhotoState { case loading, none, loaded, missingSource, damagedSaved }
    @Published var draft: PlateDraft
    @Published var image: UIImage?
    @Published var photoState: PhotoState
    @Published var saving = false
    @Published private(set) var importingPhoto = false
    @Published var photoImportError: String?
    private var photoImportToken = UUID()
    private var photoGeneration = UUID()
    private var baselinePhotoHash: String?
    private var currentPhotoHash: String?
    private var explicitlyReplacedPhoto = false
    @Published var error: String?
    private(set) var photoData: Data?
    private(set) var revisionID: UUID?
    private var createdAt: Date
    let plateID: UUID
    let repository: PlateRepository
    private var baseline: PlateDraft
    private var startedPhoto = false

    init(draft: PlateDraft, repository: PlateRepository = .shared) {
        self.draft = draft; baseline = draft; self.repository = repository
        plateID = UUID(); createdAt = Date()
        photoState = draft.photoID == nil ? .none : .loading
    }

    init(loaded: PlateLoadedDocument, repository: PlateRepository = .shared) {
        let document = loaded.document
        let value = PlateDraft(document: document)
        draft = value; baseline = value; self.repository = repository
        plateID = document.plateID; revisionID = document.revisionID; createdAt = document.createdAt
        let decodedImage = loaded.photoData.flatMap { UIImage(data: $0) }
        photoData = loaded.photoData; image = decodedImage
        baselinePhotoHash = loaded.photoData.map(PlateRepository.digest); currentPhotoHash = baselinePhotoHash
        photoState = loaded.photoDamaged || (document.photoReference != nil && decodedImage == nil) ? .damagedSaved : (decodedImage == nil ? .none : .loaded)
        startedPhoto = true
    }

    var dirty: Bool {
        // 未調整の省略値と、操作後に既定値へ戻した値を同じ状態として扱う。
        func normalized(_ source: PlateDraft) -> PlateDraft {
            var value = source
            for template in PlateTemplate.allCases { value.template = template; value.photo = value.photo }
            value.template = source.template
            return value
        }
        return normalized(draft) != normalized(baseline) || currentPhotoHash != baselinePhotoHash || explicitlyReplacedPhoto
    }
    var photoNotice: String? {
        switch photoState {
        case .none: return "写真のないプレートです。代替表示で保存できます。"
        case .missingSource: return "元写真を読み込めませんでした。保存時に、写真なしで保存するか確認します。"
        case .damagedSaved: return "保存済み写真が欠損・破損しています。元の保存版を保護するため上書き保存を停止しています。"
        default: return nil
        }
    }

    func loadPhoto() async {
        guard !startedPhoto, !explicitlyReplacedPhoto else { return }; startedPhoto = true
        guard let id = draft.photoID else { return }
        let generation = photoGeneration
        let url = EntryPhotoStore.fullURL(photoId: id)
        let bytes = await Task.detached(priority: .userInitiated) { try? Data(contentsOf: url) }.value
        guard !Task.isCancelled else {
            if generation == photoGeneration { startedPhoto = false }
            return
        }
        guard generation == photoGeneration else { return }
        if let bytes, PlateRepository.validImage(bytes), let image = UIImage(data: bytes) {
            photoData = bytes; baselinePhotoHash = PlateRepository.digest(bytes); currentPhotoHash = baselinePhotoHash; self.image = image; photoState = .loaded
        } else { photoState = .missingSource }
    }

    func beginPhotoImport() -> UUID {
        photoImportToken = UUID(); importingPhoto = true; photoImportError = nil
        return photoImportToken
    }
    func isCurrentPhotoImport(_ token: UUID) -> Bool { token == photoImportToken }
    func cancelPhotoImport() { photoImportToken = UUID(); importingPhoto = false }
    func failPhotoImport(token: UUID) {
        guard token == photoImportToken else { return }
        importingPhoto = false
        photoImportError = "写真を読み込めませんでした。変更前の写真は保持しています。"
    }
    func finishPhotoImport(_ bytes: Data?, token: UUID) async {
        guard token == photoImportToken else { return }
        // 新しい候補だけを正規化し、元のDiary写真・保存済みassetには書き込まない。
        let normalized = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let bytes, bytes.count <= 100 * 1024 * 1024, PlateRepository.validImage(bytes), let image = UIImage(data: bytes) else { return nil }
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let size = PlatePhotoGeometry.pixelSize(image)
            return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.95) { context in
                UIColor.white.setFill(); context.fill(CGRect(origin: .zero, size: size))
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }.value
        guard token == photoImportToken, !Task.isCancelled else { return }
        guard let normalized, PlateRepository.validImage(normalized), let image = UIImage(data: normalized) else { failPhotoImport(token: token); return }
        photoGeneration = UUID(); startedPhoto = true
        photoData = normalized; currentPhotoHash = PlateRepository.digest(normalized); self.image = image; photoState = .loaded
        explicitlyReplacedPhoto = true; draft.resetPhotoComposition(); importingPhoto = false
    }

    func save() async -> Bool {
        guard !saving, !importingPhoto, photoState != .loading else { return false }
        guard draft.textStylesSupported else { error = "未対応の文字設定を保護するため保存を停止しました。編集内容は保持しています。"; return false }
        guard photoState != .damagedSaved else { error = PlateStorageError.damagedPhoto.localizedDescription; return false }
        saving = true
        defer { saving = false }
        let value = draft
        let renderer = ImageRenderer(content: PlateCanvasView(draft: .constant(value), image: image)
            .frame(width: 360, height: 450).environment(\.colorScheme, .light).dynamicTypeSize(.large))
        renderer.scale = 2
        guard let thumbnail = renderer.uiImage?.jpegData(compressionQuality: 0.8) else {
            error = "サムネイルを作成できませんでした。編集内容は保持しています。"; return false
        }
        let document = value.document(plateID: plateID, revisionID: UUID(), createdAt: createdAt)
        do {
            let saved = try await repository.save(document, expectedRevision: revisionID, photo: photoData, thumbnail: thumbnail, replacingPhoto: explicitlyReplacedPhoto)
            revisionID = saved.revisionID; createdAt = saved.createdAt; baseline = value
            baselinePhotoHash = currentPhotoHash; explicitlyReplacedPhoto = false
            return true
        } catch { self.error = "保存できませんでした。編集内容は保持しています。\n" + error.localizedDescription; return false }
    }
}

extension PlateDraft {
    init(document: PlateDocument) {
        self.init(sourceEntryID: document.sourceEntryID, photoID: nil,
                  inheritedProductIDs: Set(document.selectedProducts.filter(\.inherited).map(\.id)),
                  title: document.title, date: document.dateText, comment: document.comment,
                  products: document.selectedProducts.map { PlateProduct(id: $0.id, name: $0.name, category: $0.category) },
                  unavailableSourceProducts: document.unavailableSourceProducts)
        template = PlateTemplate(rawValue: document.templateID) ?? .elegant
        background = PlateBackground(rawValue: document.backgroundStyle) ?? .signature
        frame = PlateFrame(rawValue: document.frameStyle) ?? .signature
        photoRotationQuarterTurns = document.photoRotationQuarterTurns ?? 0
        titleTextStyle = document.titleTextStyle
        commentTextStyle = document.commentTextStyle
        photos = Dictionary(uniqueKeysWithValues: document.photoAdjustments.compactMap { key, value in
            PlateTemplate(rawValue: key).map { ($0, PlatePhotoAdjustment(zoom: value.zoom, x: value.x, y: value.y)) }
        })
    }

    func document(plateID: UUID, revisionID: UUID, createdAt: Date) -> PlateDocument {
        var document = PlateDocument(plateID: plateID, revisionID: revisionID, createdAt: createdAt, updatedAt: Date(),
            sourceEntryID: sourceEntryID, templateID: template.rawValue, title: title, dateText: date, comment: comment,
            backgroundStyle: background.rawValue, frameStyle: frame.rawValue,
            photoAdjustments: Dictionary(uniqueKeysWithValues: PlateTemplate.allCases.map { key in
                let value = photos[key] ?? PlatePhotoAdjustment()
                return (key.rawValue, PlateSavedAdjustment(zoom: value.zoom, x: value.x, y: value.y))
            }),
            selectedProducts: products.map { PlateSavedProduct(id: $0.id, name: $0.name, category: $0.category, inherited: inheritedProductIDs.contains($0.id)) },
            productOrder: products.map(\.id), unavailableSourceProducts: unavailableSourceProducts,
            photoReference: nil, thumbnailReference: PlateFileReference(path: "thumbnail.jpg", sha256: ""))
        document.titleTextStyle = titleTextStyle
        document.commentTextStyle = commentTextStyle
        document.photoRotationQuarterTurns = photoRotationQuarterTurns == 0 ? nil : photoRotationQuarterTurns
        document.rendererVersion = (titleTextStyle?.isLegacy ?? true) && (commentTextStyle?.isLegacy ?? true) ? 1 : 2
        if photoRotationQuarterTurns != 0 { document.rendererVersion = 3 }
        return document
    }
}
