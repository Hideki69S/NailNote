import SwiftUI
import UIKit
import Combine
import CoreText
import CryptoKit
import CoreData
import Photos
import UniformTypeIdentifiers

enum PlateTextRole: String, Identifiable {
    case title, comment, itemNames
    var id: String { rawValue }
    var label: String { self == .title ? "タイトル" : (self == .comment ? "コメント" : "アイテム名") }
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
        let weight: Font.Weight = style.weightID == "light" ? .light : (style.weightID == "bold" ? .bold : (style.weightID == "medium" ? .medium : (style.weightID == "auto" && role != .comment ? .medium : .regular)))
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
        case .recipe: return "写真と選択したアイテム"
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
    var layoutSixPhotoRect: CGRect {
        switch self {
        case .elegant: return CGRect(x: 28, y: 35, width: 304, height: 278)
        case .sweet: return CGRect(x: 40, y: 43, width: 280, height: 270)
        case .noir: return CGRect(x: 18, y: 25, width: 228, height: 335)
        case .recipe: return CGRect(x: 22, y: 32, width: 316, height: 211)
        }
    }
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

// 任意角度だけの描画解決器。旧90度の描画経路は変更しない。
nonisolated struct PlatePhotoTransform {
    let scale: CGFloat
    let travel: CGSize
    let offset: CGSize

    init(viewport: CGSize, image: CGSize, zoom: Double, x: Double, y: Double, degrees: Double) {
        guard viewport.width > 0, viewport.height > 0, image.width > 0, image.height > 0,
              degrees.isFinite, zoom.isFinite, x.isFinite, y.isFinite else {
            scale = 1; travel = .zero; offset = .zero; return
        }
        let radians = degrees * .pi / 180
        // 直角の微小な三角関数誤差を除き、旧構図との境界を安定させる。
        let cosine = abs(cos(radians)) < 1e-12 ? 0 : cos(radians)
        let sine = abs(sin(radians)) < 1e-12 ? 0 : sin(radians)
        let c = abs(cosine), s = abs(sine)
        let factor = max((viewport.width*c + viewport.height*s)/image.width,
                         (viewport.width*s + viewport.height*c)/image.height) * min(3, max(1, zoom))
        scale = factor
        let extent = CGSize(width: max(0, (factor*(image.width*c + image.height*s)-viewport.width)/2),
                            height: max(0, (factor*(image.width*s + image.height*c)-viewport.height)/2))
        travel = extent
        let dx = min(1, max(-1, x))*extent.width, dy = min(1, max(-1, y))*extent.height
        let marginX = max(0, (factor*image.width-viewport.width*c-viewport.height*s)/2)
        let marginY = max(0, (factor*image.height-viewport.width*s-viewport.height*c)/2)
        let u = max(-marginX, min(marginX, cosine*dx+sine*dy))
        let v = max(-marginY, min(marginY, -sine*dx+cosine*dy))
        offset = CGSize(width: cosine*u-sine*v, height: sine*u+cosine*v)
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
    var itemImagesEnabled = true
    // 既存6を再保存しても7へ上げず、明示更新時だけ描画版を変更する。
    var layoutVersion = 7
    var usesNewLayout: Bool { layoutVersion >= 6 }
    var itemImageReferences: [String: PlateFileReference] = [:]
    var photoRotationQuarterTurns = 0
    var photoRotationDegrees: Double? = nil
    var photoAngle: Double { photoRotationDegrees ?? (photoRotationQuarterTurns == 3 ? -90 : Double(photoRotationQuarterTurns)*90) }
    var rotationSupported: Bool {
        if let value = photoRotationDegrees { return value.isFinite && (-180...180).contains(value) && photoRotationQuarterTurns == 0 }
        return (0...3).contains(photoRotationQuarterTurns)
    }
    mutating func setPhotoAngle(_ value: Double) {
        guard value.isFinite, (-180...180).contains(value), value != photoAngle else { return }
        photoRotationDegrees = value; photoRotationQuarterTurns = 0
    }
    var titleTextStyle: PlateTextStyle? = nil
    var commentTextStyle: PlateTextStyle? = nil
    var itemNameTextStyle: PlateTextStyle? = nil
    var itemNameFontSize: PlateStyleValue? = nil
    var commentFontSize: PlateStyleValue? = nil
    var textStylesSupported: Bool {
        (titleTextStyle?.supported ?? true) && (commentTextStyle?.supported ?? true) && (itemNameTextStyle?.supported ?? true)
        && PlateTextStyle.validSize(itemNameFontSize, range: 7...14) && PlateTextStyle.validSize(commentFontSize, range: 8...16)
    }
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
    mutating func resetPhotoComposition() {
        photos = [:]; photoRotationQuarterTurns = 0
        if photoRotationDegrees != nil { photoRotationDegrees = 0 }
    }
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
    case template, photo, background, frame, text, decoration
    var id: String { rawValue }
    var title: String {
        switch self {
        case .template: return "プレート"; case .photo: return "写真"; case .background: return "背景"
        case .frame: return "フレーム"; case .text: return "文字"; case .decoration: return "装飾"
        }
    }
    var symbol: String {
        switch self {
        case .template: return "rectangle.stack"; case .photo: return "photo"; case .background: return "circle.lefthalf.filled"
        case .frame: return "square.on.square"; case .text: return "textformat"; case .decoration: return "sparkles"
        }
    }
}

struct PlateEditorView: View {
    @Environment(\.managedObjectContext) private var itemContext
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
    @State private var textRole: PlateTextRole = .itemNames
    @State private var editingText: PlateTextRole?
    @State private var choosingDesignPhoto = false
    @State private var exporting: PlateExportSnapshot?
    @ScaledMetric(relativeTo: .caption) private var menuWidth: CGFloat = 72
    @ScaledMetric(relativeTo: .caption) private var menuHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .caption) private var menuIconSize: CGFloat = 18
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
                let contentWidth = max(0, page.size.width - 32)
                let proposedWidth = max(0, contentWidth - 12) * 0.60
                let horizontal = !typeSize.isAccessibilitySize && proposedWidth >= 160 && proposedWidth * 1.25 <= page.size.height * 0.42 && focusedField == nil
                VStack(spacing: 10) {
                    if horizontal {
                        HStack(alignment: .top, spacing: 12) {
                            preview(width: proposedWidth)
                            PlateProductEditingSidebar(draft: $draft, compact: contentWidth - proposedWidth - 12 < 128, palette: editorPalette) {
                                focusedField = nil; onChooseProducts()
                            }.frame(width: max(0, contentWidth - proposedWidth - 12), height: proposedWidth * 1.25)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                preview(width: min(contentWidth, max(160, min(240, page.size.height * 0.25) * 0.8)))
                                PlateProductEditingSidebar(draft: $draft, compact: false, palette: editorPalette) {
                                    focusedField = nil; onChooseProducts()
                                }.frame(height: typeSize.isAccessibilitySize ? max(300, menuHeight * 4) : 200)
                            }
                        }.frame(height: page.size.height * (focusedField == nil ? 0.48 : 0.30))
                            .accessibilityIdentifier("plate.previewProducts.vertical")
                    }
                    toolBar
                    if tool == .text && !typeSize.isAccessibilitySize {
                        Text("選べる文字の太さは、書体によって異なります。")
                            .font(.caption).foregroundStyle(editorPalette.tagText).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("plate.weight.explanation")
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("プレートの変更は元の記録・アイテムには反映されません")
                                .font(.caption).foregroundStyle(editorPalette.tagText).fixedSize(horizontal: false, vertical: true)
                            if let photoNotice = session.photoNotice {
                                Text(photoNotice).font(.caption).foregroundStyle(editorPalette.tagText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("plate.photoNotice")
                            }
                            if let notice = session.itemImageNotice {
                                Text(notice).font(.caption).foregroundStyle(editorPalette.tagText)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        focusedField = nil
                        exporting = session.exportSnapshot()
                    } label: {
                        Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("編集中のプレートを書き出す")
                    .accessibilityIdentifier("plate.export")
                    .disabled(session.saving || session.importingPhoto || session.loadingItemImages || session.photoState == .loading || !draft.textStylesSupported)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(session.saving ? "保存中…" : "保存") {
                        focusedField = nil
                        if session.photoState == .missingSource { confirmingMissingPhoto = true }
                        else { Task { if await session.save() { onSaved() } } }
                    }
                    .disabled(session.saving || session.importingPhoto || session.loadingItemImages || session.photoState == .loading || session.photoState == .damagedSaved || !draft.textStylesSupported)
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
        .task(id: session.itemImageRequestKey) { await session.prepareItemImages(in: itemContext) }
        .modifier(NailTabExitProtection(dirty: session.dirty, blocked: session.saving || session.importingPhoto || session.loadingItemImages))
        .modifier(NailEditorExit(dirty: session.dirty, blocked: session.saving || session.importingPhoto || session.loadingItemImages, onReturn: onCancel))
        .disabled(session.saving)
        .navigationBarBackButtonHidden(true)
        .onChange(of: textRole) { _, _ in focusedField = nil; weightNotice = nil }
        .sheet(item: $choosingFont) { role in fontSheet(role) }
        .sheet(item: $exporting) { snapshot in PlateExportSheet(snapshot: snapshot) }
        .sheet(item: $editingText) { role in
            PlateTextInputSheet(role: role, initialText: role == .title ? draft.title : draft.comment) { value in
                // 入力対象はシートを開いた時点のroleに固定する。作品の保存は行わない。
                if role == .title { draft.title = value } else { draft.comment = value }
            }
        }
        .sheet(isPresented: $choosingDesignPhoto, onDismiss: { photoImportTask?.cancel(); session.cancelPhotoImport() }) {
            NavigationStack {
                PlateDesignSelectionView(replacingPhoto: true, blocked: session.importingPhoto) { entry in
                    photoImportTask?.cancel()
                    photoImportTask = Task {
                        if await session.replacePhoto(from: entry) { choosingDesignPhoto = false }
                    }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { photoImportTask?.cancel(); session.cancelPhotoImport(); choosingDesignPhoto = false }
                        .accessibilityIdentifier("plate.photo.cancelSelection")
                } }
                .alert("写真を読み込めませんでした", isPresented: Binding(get: { session.photoImportError != nil }, set: { if !$0 { session.photoImportError = nil } })) {
                    Button("OK") { session.photoImportError = nil }
                } message: { Text(session.photoImportError ?? "") }
            }
        }
        .onDisappear { photoImportTask?.cancel(); session.cancelPhotoImport() }
        .alert("写真を読み込めませんでした", isPresented: Binding(get: { !choosingDesignPhoto && session.photoImportError != nil }, set: { if !$0 { session.photoImportError = nil } })) {
            Button("OK") { session.photoImportError = nil }
        } message: { Text(session.photoImportError ?? "") }
        .confirmationDialog("未対応の文字設定を標準に戻しますか？ この文字の保存情報を置き換えます。", isPresented: Binding(get: { resetUnknown != nil }, set: { if !$0 { resetUnknown = nil } })) {
            Button("標準に戻す", role: .destructive) { if let role = resetUnknown { resetStyle(role) }; resetUnknown = nil }
            Button("編集を続ける", role: .cancel) { resetUnknown = nil }
        }
        .alert("写真を読み込めません", isPresented: $confirmingMissingPhoto) {
            Button("写真なしで保存") { Task { if await session.save() { onSaved() } } }
            Button("編集を続ける", role: .cancel) {}
        } message: { Text("元写真を保存できません。写真なしのプレートとして保存しますか？ 元の記録は変更しません。") }
    }

    private func preview(width: CGFloat) -> some View {
        PlateCanvasView(draft: $draft, image: session.image, loadingPhoto: session.photoState == .loading, photoEditing: tool == .photo, itemImages: session.itemImages)
            .frame(width: 360, height: 450).scaleEffect(width / 360, anchor: .topLeading)
            .frame(width: width, height: width * 1.25, alignment: .topLeading)
            .accessibilityIdentifier("plate.preview")
    }

    private var toolBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PlateTool.allCases) { item in
                    Button { focusedField = nil; tool = item } label: {
                        Group {
                            if item == .template {
                                VStack(spacing: 4) {
                                    Image(systemName: item.symbol).font(.system(size: 18))
                                    Text("テンプレート").hidden().overlay { Text(item.title) }.font(.caption)
                                }.padding(.horizontal, 9).padding(.vertical, 8).frame(minWidth: 60, minHeight: 52)
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: item.symbol).font(.system(size: menuIconSize)).frame(height: menuIconSize)
                                    Text(item.title).font(.caption).lineLimit(1)
                                }.frame(width: max(44, menuWidth), height: max(44, menuHeight))
                            }
                        }
                        .background(tool == item ? editorPalette.glowFillTop : editorPalette.glowFillBottom.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(editorPalette.outerStrokeEnd.opacity(tool == item ? 0.85 : 0.25), lineWidth: tool == item ? 1.2 : 0.7))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("plate.tool.\(item.rawValue)")
                    .accessibilityHint(item == .decoration ? "装飾は表示のみです" : "編集する項目を選択します")
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
        case .photo:
            VStack(alignment: .leading, spacing: 10) {
                Button { focusedField = nil; choosingDesignPhoto = true } label: {
                    Label("デザインから写真を選ぶ", systemImage: "photo.on.rectangle").frame(minHeight: 44)
                }.disabled(session.saving || session.importingPhoto || session.loadingItemImages).accessibilityIdentifier("plate.photo.choose")
                if session.importingPhoto { ProgressView("写真を準備中") }
                Text("写真のみ差し替えます。成功すると全テンプレートの位置・倍率・角度を初期化します。作品の保存まで旧写真は変わりません。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
                VStack(alignment: .leading, spacing: 4) {
                    Text("回転角度：" + draft.photoAngle.formatted(.number.precision(.fractionLength(0...1))) + "°")
                        .font(.subheadline).accessibilityIdentifier("plate.photo.angleValue")
                    Slider(value: Binding(get: { draft.photoAngle }, set: { draft.setPhotoAngle($0) }), in: -180...180, step: 1)
                        .accessibilityLabel("写真の回転角度")
                        .accessibilityValue(draft.photoAngle.formatted() + "度")
                        .accessibilityIdentifier("plate.photo.angle")
                    Button("0°に戻す") { draft.setPhotoAngle(0) }
                        .frame(minHeight: 44).disabled(draft.photoAngle == 0)
                        .accessibilityIdentifier("plate.photo.angleZero")
                }.disabled(session.image == nil || session.importingPhoto)
                Text("写真をドラッグ、またはスライダーで調整できます。端を越えて移動しません。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
                adjustmentSlider("倍率", keyPath: \.zoom, range: 1...3)
                adjustmentSlider("左右", keyPath: \.x, range: -1...1)
                adjustmentSlider("上下", keyPath: \.y, range: -1...1)
                Text("角度に応じて枠を覆う倍率と移動範囲を自動調整します。倍率・位置の保存値は保持します。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
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
                    Text("アイテム名").tag(PlateTextRole.itemNames)
                    Text("コメント").tag(PlateTextRole.comment)
                }.pickerStyle(.segmented).frame(minHeight: 44).accessibilityIdentifier("plate.text.target")
                if typeSize.isAccessibilitySize {
                    Text("選べる文字の太さは、書体によって異なります。")
                        .font(.caption).foregroundStyle(editorPalette.tagText)
                        .accessibilityIdentifier("plate.weight.explanation")
                }
                if !draft.usesNewLayout {
                    Text("旧レイアウトを保持しています。アイテム欄の「新レイアウトに更新」から確認後、アイテム名と文字サイズを調整できます。")
                        .font(.caption).foregroundStyle(editorPalette.tagText)
                }
                if textRole == .comment {
                Button { focusedField = nil; editingText = .comment } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("コメントを編集").font(.caption)
                            let value = draft.comment
                            Text(value.isEmpty ? "タップして入力" : value).lineLimit(3).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "square.and.pencil")
                    }.padding(12).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(editorPalette.glowFillTop, in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityIdentifier("plate.text.edit.comment")
                } else {
                    Text("掲載する全アイテム名に共通で適用します。名前そのものは変更しません。")
                        .font(.caption).foregroundStyle(editorPalette.tagText)
                }
                textStyleControls(textRole).disabled(textRole == .itemNames && !draft.usesNewLayout)
                TextField("制作日", text: $draft.date).focused($focusedField, equals: .date).accessibilityIdentifier("plate.date")
                Text("文字は各テンプレートの表示枠に収まる範囲で表示します。入力した全文は切替後も保持します。")
                    .font(.caption).foregroundStyle(editorPalette.tagText)
            }.textFieldStyle(.roundedBorder)
        case .decoration:
            Text("テンプレート固有の装飾を表示しています。装飾の追加・自由配置は今後対応予定です。")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)

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
        Binding(get: {
            (role == .itemNames ? draft.itemNameTextStyle : (role == .title ? draft.titleTextStyle : draft.commentTextStyle)) ?? PlateTextStyle()
        }, set: { value in
            let normalized: PlateTextStyle? = value.isLegacy ? nil : value
            if role == .itemNames { draft.itemNameTextStyle = normalized }
            else if role == .title { draft.titleTextStyle = normalized }
            else { draft.commentTextStyle = normalized }
        })
    }
    private func sizeValue(_ role: PlateTextRole) -> PlateStyleValue? {
        role == .itemNames ? draft.itemNameFontSize : draft.commentFontSize
    }
    private func sizeRange(_ role: PlateTextRole) -> ClosedRange<Double> { role == .itemNames ? 7...14 : 8...16 }
    private func setSize(_ value: PlateStyleValue?, role: PlateTextRole) {
        if role == .itemNames { draft.itemNameFontSize = value } else { draft.commentFontSize = value }
    }
    private func resetStyle(_ role: PlateTextRole) {
        styleBinding(role).wrappedValue = PlateTextStyle()
        setSize(nil, role: role)
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
            if draft.usesNewLayout {
                let validSize = PlateTextStyle.validSize(sizeValue(role), range: sizeRange(role))
                VStack(alignment: .leading, spacing: 5) {
                    let stored: Double? = { if case .number(let number) = sizeValue(role) { return number }; return nil }()
                    Text(role.label + "の文字サイズ：" + (stored.map { $0.formatted() + " pt" } ?? "自動"))
                        .font(.subheadline).accessibilityIdentifier("plate.size.value." + role.rawValue)
                    if !validSize { Text("未対応の文字サイズを保護しています。標準に戻す操作で解除できます。").font(.caption).foregroundStyle(.red) }
                    Slider(value: Binding(get: { stored ?? (role == .itemNames ? 9 : 12) }, set: { setSize(.number($0), role: role) }), in: sizeRange(role), step: 0.5)
                        .accessibilityLabel(role.label + "の文字サイズ").accessibilityIdentifier("plate.size." + role.rawValue)
                        .disabled(!validSize)
                    Button("文字サイズを自動に戻す") { setSize(nil, role: role) }.frame(minHeight: 44).disabled(!validSize)
                }
            }
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
                if style.supported && PlateTextStyle.validSize(sizeValue(role), range: sizeRange(role)) { resetStyle(role) } else { resetUnknown = role }
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
    var itemImages: [UUID: UIImage] = [:]

    var body: some View {
        let template = draft.template
        ZStack(alignment: .topLeading) {
            PlateSurface(template: template, style: draft.background)
            RoundedRectangle(cornerRadius: 12).inset(by: 8)
                .strokeBorder(template.metal.opacity(0.55), lineWidth: 0.7)
            PlatePhotoViewport(adjustment: Binding(get: { draft.photo }, set: { draft.photo = $0 }), image: image, loading: loadingPhoto, template: template, frame: draft.frame, editing: photoEditing, quarterTurns: draft.photoRotationQuarterTurns, degrees: draft.photoRotationDegrees)
                .frame(width: photoRect.width, height: photoRect.height)
                .offset(x: photoRect.minX, y: photoRect.minY)
            if draft.usesNewLayout { layoutSixComposition } else { composition }
        }
        .frame(width: 360, height: 450).clipShape(RoundedRectangle(cornerRadius: 12))
        .modifier(PlateLayoutSixComposite(enabled: draft.usesNewLayout))
        .shadow(color: .black.opacity(0.16), radius: 9, x: 1, y: 5)
        // 作品の構図は操作UIの文字拡大やアプリのテーマから独立させる。
        .dynamicTypeSize(.large).environment(\.colorScheme, .light)
    }

    private var photoRect: CGRect { draft.usesNewLayout ? draft.template.layoutSixPhotoRect : draft.template.photoRect }

    @ViewBuilder private var composition: some View {
        switch draft.template {
        case .elegant:
            heading(x: 28, y: 25, width: 304, alignment: .center)
            caption(draft.date, size: 10).frame(width: 304).offset(x: 28, y: 69)
            if draft.itemImagesEnabled {
                itemStrip.frame(width: 286, height: 35).offset(x: 37, y: 349)
                comment(size: 12, maxHeight: 45).frame(width: 286, height: 45, alignment: .top).clipped().offset(x: 37, y: 390)
            } else {
                comment(size: 12).frame(width: 286, height: 55).offset(x: 37, y: 365)
                Rectangle().fill(draft.template.metal.opacity(0.5)).frame(width: 66, height: 0.7).offset(x: 147, y: 356)
            }
        case .noir:
            VStack(alignment: .leading, spacing: 16) {
                Text("NOIR").font(.system(size: 14, weight: .light, design: .serif)).tracking(2)
                Rectangle().fill(draft.template.metal).frame(width: 42, height: 1)
                caption(draft.date, size: 10)
                Text("NAIL\nCOLLECTION").font(.system(size: 9, weight: .medium)).tracking(1.5)
            }
            .foregroundStyle(draft.template.ink).frame(width: 84, alignment: .leading).offset(x: 253, y: 66)
            if draft.itemImagesEnabled {
                VStack(spacing: 5) {
                    ForEach(Array(draft.products.prefix(3))) { product in
                        HStack(spacing: 4) {
                            itemPhoto(product, size: 27)
                            Text(product.name).font(.system(size: 8)).lineLimit(2)
                        }.frame(width: 84, height: 39, alignment: .leading)
                    }
                    if draft.products.count > 3 { Text("他\(draft.products.count - 3)点").font(.system(size: 7)) }
                }.foregroundStyle(draft.template.ink).offset(x: 253, y: 195)
            }
            heading(x: 22, y: 362, width: 316, alignment: .leading)
            comment(size: 11, maxHeight: draft.itemImagesEnabled ? 42 : nil).frame(width: 316, height: 42, alignment: .topLeading).offset(x: 22, y: 402)
        case .sweet:
            heading(x: 34, y: 26, width: 292, alignment: .center)
            caption(draft.date, size: 10).frame(width: 292).offset(x: 34, y: 68)
            Image(systemName: "heart.fill").font(.system(size: 15)).foregroundStyle(draft.template.metal.opacity(0.65)).offset(x: 26, y: 170)
            Image(systemName: "heart").font(.system(size: 19)).foregroundStyle(draft.template.metal).offset(x: 310, y: 289)
            PlateRibbon().fill(draft.template.metal.opacity(0.8)).frame(width: 65, height: 38).offset(x: 148, y: 76)
            if draft.itemImagesEnabled {
                itemStrip.frame(width: 286, height: 34).offset(x: 37, y: 365)
                comment(size: 12, lines: 2, maxHeight: 34).frame(width: 286, height: 34, alignment: .top).clipped().offset(x: 37, y: 403)
            } else { comment(size: 12).frame(width: 286, height: 56).offset(x: 37, y: 377) }
        case .recipe:
            heading(x: 22, y: 18, width: 316, alignment: .leading)
            caption(draft.date + "  /  NAIL RECIPE", size: 9).frame(width: 316, alignment: .leading).offset(x: 22, y: 60)
            VStack(spacing: draft.itemImagesEnabled ? 4 : 7) {
                if draft.products.isEmpty {
                    caption("アイテムは選択されていません", size: 12).frame(height: 70)
                } else {
                    ForEach(Array(draft.products.prefix(PlateDraft.recipeLimit).enumerated()), id: \.element.id) { index, product in
                        if draft.itemImagesEnabled {
                            HStack(spacing: 8) {
                                Text(String(format: "%02d", index + 1)).font(.system(size: 9)).foregroundStyle(draft.template.metal)
                                itemPhoto(product, size: 24)
                                Text(product.name).font(.system(size: 10, weight: .medium)).lineLimit(1)
                                Spacer(minLength: 0)
                            }.padding(.horizontal, 7).frame(height: 28)
                                .foregroundStyle(draft.template.ink)
                                .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 7))
                        } else { recipeRow(String(format: "%02d", index + 1), product.name) }
                    }
                }
            }.frame(width: 316).offset(x: 22, y: 293)
            if draft.recipeOverflow > 0 {
                caption("掲載3 / 選択\(draft.products.count)件 · 他\(draft.recipeOverflow)件は非表示", size: 8)
                    .frame(width: 316, alignment: .leading).offset(x: 22, y: 389)
            }
            comment(size: 11, maxHeight: draft.itemImagesEnabled ? 40 : nil).frame(width: 316, height: 40, alignment: .topLeading).offset(x: 22, y: 403)
        }
    }

    private var layoutSixComposition: some View {
        let layout = PlateLayoutSixGeometry(template: draft.template)
        let footer = PlateLayoutSevenFooter(template: draft.template)
        return ZStack(alignment: .topLeading) {
            if draft.template == .noir {
                Text("NOIR").font(.system(size: 12, weight: .light, design: .serif)).tracking(1.6)
                    .foregroundStyle(draft.template.metal).frame(width: 88).offset(x: 254, y: 27)
            }
            if draft.layoutVersion == 7 {
                Text(draft.date).font(.system(size: 9)).foregroundStyle(draft.template.ink.opacity(0.85))
                    .lineLimit(1).truncationMode(.tail)
                    .frame(width: footer.date.width, height: footer.date.height, alignment: .trailing)
                    .clipped().offset(x: footer.date.minX, y: footer.date.minY)
            } else {
                caption(draft.date, size: draft.template == .noir ? 8 : 9)
                    .frame(width: layout.date.width, height: layout.date.height, alignment: .top)
                    .clipped().offset(x: layout.date.minX, y: layout.date.minY)
            }
            if draft.template == .sweet {
                PlateRibbon().fill(draft.template.metal.opacity(0.8)).frame(width: 60, height: 30).offset(x: 150, y: 23)
                Image(systemName: "heart.fill").font(.system(size: 14)).foregroundStyle(draft.template.metal).offset(x: 19, y: 145)
                Image(systemName: "heart").font(.system(size: 17)).foregroundStyle(draft.template.metal).offset(x: 321, y: 285)
            }
            if draft.products.isEmpty {
                caption("アイテムなし", size: 10).frame(width: layout.empty.width, height: layout.empty.height)
                    .offset(x: layout.empty.minX, y: layout.empty.minY)
            }
            ForEach(Array(draft.products.prefix(3).enumerated()), id: \.element.id) { index, product in
                let slot = layout.slots[index]
                if draft.template == .recipe {
                    RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.20))
                        .frame(width: 316, height: 42).offset(x: 22, y: 254 + CGFloat(index) * 45)
                    Text(String(format: "%02d", index + 1)).font(.system(size: 9)).foregroundStyle(draft.template.metal)
                        .frame(width: 12, height: 42).offset(x: 29, y: 254 + CGFloat(index) * 45)
                }
                itemPhoto(product, size: slot.photo.width).offset(x: slot.photo.minX, y: slot.photo.minY)
                layoutSixText(product.name, style: draft.itemNameTextStyle, value: draft.itemNameFontSize,
                              defaultSize: draft.template == .recipe ? 10 : 9, role: .itemNames, rect: slot.name, lines: 2)
            }
            if draft.products.count > 3 {
                Text("+\(draft.products.count - 3)").font(.system(size: 8)).foregroundStyle(draft.template.ink.opacity(0.85)).lineLimit(1)
                    .frame(width: layout.overflow.width, height: layout.overflow.height, alignment: .trailing)
                    .clipped()
                    .offset(x: layout.overflow.minX, y: layout.overflow.minY)
            }
            layoutSixText(draft.comment, style: draft.commentTextStyle, value: draft.commentFontSize,
                          defaultSize: draft.template == .elegant || draft.template == .sweet ? 12 : 11,
                          role: .comment, rect: draft.layoutVersion == 7 ? footer.comment : layout.comment, lines: 3)
        }.frame(width: 360, height: 450, alignment: .topLeading).allowsHitTesting(false)
    }

    private func layoutSixText(_ text: String, style: PlateTextStyle?, value: PlateStyleValue?, defaultSize: CGFloat,
                               role: PlateTextRole, rect: CGRect, lines: Int) -> some View {
        let range: ClosedRange<Double> = role == .itemNames ? 7...14 : 8...16
        let size: CGFloat = {
            if PlateTextStyle.validSize(value, range: range), case .number(let number) = value { return CGFloat(number) }
            return defaultSize
        }()
        let safeStyle = style?.supported == true ? style! : PlateTextStyle()
        let font = PlateFontCatalog.external(safeStyle.fontID, weight: safeStyle.weightID, size: size)
            ?? (safeStyle.fontID == "hiramin" ? UIFont(name: safeStyle.weightID == "bold" ? "HiraMinProN-W6" : "HiraMinProN-W3", size: size) : nil)
            ?? (safeStyle.fontID == "hiramaru" ? UIFont(name: "HiraMaruProN-W4", size: size) : nil)
            ?? UIFont.systemFont(ofSize: size, weight: safeStyle.weightID == "bold" ? .bold : .regular)
        let bounds = NSAttributedString(string: "あAg💅", attributes: [.font: font]).boundingRect(with: CGSize(width: 1000, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let count = max(1, min(lines, Int(rect.height / max(font.lineHeight, ceil(bounds.height)))))
        return Text(text).font(PlateFontCatalog.font(style, role: role, size: size))
            .foregroundStyle(PlateFontCatalog.color(style, role: role, template: draft.template))
            .lineLimit(count).truncationMode(.tail).multilineTextAlignment(.leading)
            .frame(width: rect.width, height: rect.height, alignment: .topLeading).clipped()
            .offset(x: rect.minX, y: rect.minY)
    }

    private func itemPhoto(_ product: PlateProduct, size: CGFloat) -> some View {
        ZStack {
            draft.template.paper
            if let image = itemImages[product.id] {
                if draft.layoutVersion == 7 {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: size, height: size, alignment: .center)
                } else { Image(uiImage: image).resizable().scaledToFit() }
            }
            else { Image(systemName: PlateItemPresentation.symbol(for: product.category)).font(.system(size: size * 0.48)).foregroundStyle(draft.template.metal) }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(draft.template.metal.opacity(0.4), lineWidth: 0.5))
    }
    private var itemStrip: some View {
        HStack(spacing: 5) {
            ForEach(Array(draft.products.prefix(3))) { product in
                HStack(spacing: 4) {
                    itemPhoto(product, size: 25)
                    Text(product.name).font(.system(size: 8, weight: .medium)).lineLimit(2)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if draft.products.isEmpty { Text("アイテムなし").font(.system(size: 9)) }
            if draft.products.count > 3 { Text("+\(draft.products.count - 3)").font(.system(size: 7)) }
        }.foregroundStyle(draft.template.ink)
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
    private func comment(size: CGFloat, lines: Int = 3, maxHeight: CGFloat? = nil) -> some View {
        let style = draft.commentTextStyle ?? PlateTextStyle()
        let uiFont = PlateFontCatalog.external(style.fontID, weight: style.weightID, size: size)
            ?? (style.fontID == "hiramin" ? UIFont(name: style.weightID == "bold" ? "HiraMinProN-W6" : "HiraMinProN-W3", size: size) : nil)
            ?? (style.fontID == "hiramaru" ? UIFont(name: "HiraMaruProN-W4", size: size) : nil)
            ?? UIFont.systemFont(ofSize: size)
        // 新構図だけ、和文・英字・絵文字の行高に収まる完全な行数を表示する。
        let bounds = NSAttributedString(string: "あAg💅", attributes: [.font: uiFont]).boundingRect(with: CGSize(width: 1000, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let lineHeight = max(uiFont.lineHeight, ceil(bounds.height))
        let visibleLines = maxHeight.map { max(1, min(lines, Int($0 / lineHeight))) } ?? lines
        return Text(draft.comment).font(PlateFontCatalog.font(draft.commentTextStyle, role: .comment, size: size))
            .foregroundStyle(PlateFontCatalog.color(draft.commentTextStyle, role: .comment, template: draft.template))
            .lineLimit(visibleLines).fixedSize(horizontal: false, vertical: true).allowsHitTesting(false)
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
    var degrees: Double? = nil
    @State private var dragStart: PlatePhotoAdjustment?

    var body: some View {
        GeometryReader { proxy in
            let imageSize = image.map(PlatePhotoGeometry.pixelSize) ?? CGSize(width: 4, height: 5)
            let rotatedSize = quarterTurns % 2 == 0 ? imageSize : CGSize(width: imageSize.height, height: imageSize.width)
            let overflow = adjustment.overflow(in: proxy.size, image: rotatedSize)
            let transform = degrees.map { PlatePhotoTransform(viewport: proxy.size, image: imageSize, zoom: adjustment.zoom, x: adjustment.x, y: adjustment.y, degrees: $0) }
            let travel = transform?.travel ?? overflow
            let shape = RoundedRectangle(cornerRadius: template.photoRadius)
            ZStack {
                if let image {
                    let fill = transform?.scale ?? (max(proxy.size.width / rotatedSize.width, proxy.size.height / rotatedSize.height) * adjustment.zoom)
                    Image(uiImage: image).resizable()
                        .frame(width: imageSize.width * fill, height: imageSize.height * fill)
                        .rotationEffect(.degrees(degrees ?? Double(quarterTurns) * 90))
                        .offset(x: transform?.offset.width ?? adjustment.x * overflow.width, y: transform?.offset.height ?? adjustment.y * overflow.height)
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
                start.x += travel.width > 0.1 ? value.translation.width / travel.width : 0
                start.y += travel.height > 0.1 ? value.translation.height / travel.height : 0
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
        .onChange(of: degrees) { _, _ in dragStart = nil }
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
    @Published private(set) var loadingItemImages = false
    @Published private(set) var itemImages: [UUID: UIImage] = [:]
    private var itemImageBytes: [String: Data] = [:]
    private var preparedItemRefs: [String: PlateFileReference] = [:]
    private var resolvedItemIDs = Set<UUID>()
    private var itemImageToken = UUID()
    private var damagedItemHashes = Set<String>()
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
        itemImageBytes = loaded.itemImageData
        preparedItemRefs = document.itemImageReferences ?? [:]
        damagedItemHashes = loaded.damagedItemHashes
        if value.itemImagesEnabled { resolvedItemIDs = Set(value.products.map(\.id)) }
        refreshItemImages()
        startedPhoto = true
    }

    var itemImageRequestKey: String {
        String(draft.itemImagesEnabled) + draft.products.map { $0.id.uuidString }.joined(separator: ":")
    }
    var itemImageNotice: String? {
        damagedItemHashes.isEmpty ? nil : "一部の保存済みアイテム写真を読み込めません。カテゴリ表示で作品を表示し、旧画像参照を保持しています。"
    }
    private func refreshItemImages() {
        var images: [UUID: UIImage] = [:]
        for product in draft.products.prefix(PlateDraft.recipeLimit) {
            if let ref = preparedItemRefs[product.id.uuidString], let bytes = itemImageBytes[ref.sha256], let image = UIImage(data: bytes) {
                images[product.id] = image
            }
        }
        itemImages = images
    }
    func prepareItemImages(in context: NSManagedObjectContext) async {
        guard draft.itemImagesEnabled, !saving else { return }
        let pending = Set(draft.products.map(\.id)).subtracting(resolvedItemIDs)
        guard !pending.isEmpty else { refreshItemImages(); return }
        let token = UUID(); itemImageToken = token; loadingItemImages = true
        let request = NSFetchRequest<NailProduct>(entityName: "NailProduct")
        request.predicate = NSPredicate(format: "id IN %@", pending.map { $0 as NSUUID })
        var sources: [UUID: [URL]] = [:]
        let products: [NailProduct]
        do { products = try context.fetch(request) }
        catch { loadingItemImages = false; self.error = "アイテム写真を準備できませんでした。編集内容は保持しています。"; return }
        for product in products where !product.isDeleted {
            guard let id = product.id else { continue }
            sources[id] = [product.photoId, product.samplePhotoId].compactMap { $0 }.compactMap { ProductPhotoStore.sourceURL(photoId: $0) }
        }
        let capturedSources = sources
        let bytes = await Task.detached(priority: .userInitiated) { () -> [UUID: Data] in
            var result: [UUID: Data] = [:]
            for id in pending {
                for url in capturedSources[id] ?? [] {
                    if let data = PlateItemImageCodec.jpeg(at: url) { result[id] = data; break }
                }
            }
            return result
        }.value
        guard token == itemImageToken else { return }
        defer { loadingItemImages = false }
        guard !Task.isCancelled, draft.itemImagesEnabled else { return }
        for id in pending {
            if let data = bytes[id] {
                let hash = PlateRepository.digest(data)
                itemImageBytes[hash] = data
                preparedItemRefs[id.uuidString] = .init(path: "item-images/\(hash).jpg", sha256: hash)
            }
            resolvedItemIDs.insert(id)
        }
        refreshItemImages()
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
    func replacePhoto(from entry: NailEntry) async -> Bool {
        guard !saving else { return false }
        let token = beginPhotoImport()
        guard !entry.isDeleted, let entryID = entry.id, let photoID = entry.photoId else { failPhotoImport(token: token); return false }
        let url = EntryPhotoStore.fullURL(photoId: photoID)
        let bytes = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 100 * 1024 * 1024 else { return nil }
            return try? Data(contentsOf: url)
        }.value
        guard token == photoImportToken, !Task.isCancelled else { return false }
        guard !entry.isDeleted, entry.id == entryID, entry.photoId == photoID else { failPhotoImport(token: token); return false }
        return await finishPhotoImport(bytes, token: token)
    }

    @discardableResult func finishPhotoImport(_ bytes: Data?, token: UUID) async -> Bool {
        guard token == photoImportToken else { return false }
        // デザインの既存フルJPEGを再圧縮せず固定し、元ファイルには書き込まない。
        let validated = await Task.detached(priority: .userInitiated) { () -> Data? in
            guard let bytes, bytes.count <= 100 * 1024 * 1024, PlateRepository.validImage(bytes) else { return nil }
            return bytes
        }.value
        guard token == photoImportToken, !Task.isCancelled else { return false }
        guard let bytes = validated, let image = UIImage(data: bytes) else { failPhotoImport(token: token); return false }
        photoGeneration = UUID(); startedPhoto = true
        photoData = bytes; currentPhotoHash = PlateRepository.digest(bytes); self.image = image; photoState = .loaded
        explicitlyReplacedPhoto = true; draft.resetPhotoComposition(); importingPhoto = false
        return true
    }

    func save() async -> Bool {
        guard !saving, !importingPhoto, !loadingItemImages, photoState != .loading else { return false }
        guard draft.rotationSupported else { error = "未対応の写真角度を保護するため保存を停止しました。"; return false }
        guard draft.textStylesSupported else { error = "未対応の文字設定を保護するため保存を停止しました。編集内容は保持しています。"; return false }
        guard photoState != .damagedSaved else { error = PlateStorageError.damagedPhoto.localizedDescription; return false }
        saving = true
        defer { saving = false }
        var value = draft
        if value.itemImagesEnabled {
            guard Set(value.products.map(\.id)).isSubset(of: resolvedItemIDs) else {
                error = "アイテム写真の準備が完了していません。もう一度お試しください。"; return false
            }
            value.itemImageReferences = preparedItemRefs.filter { key, _ in value.products.contains { $0.id.uuidString == key } }
        }
        let renderer = ImageRenderer(content: PlateCanvasView(draft: .constant(value), image: image, itemImages: itemImages)
            .frame(width: 360, height: 450).environment(\.colorScheme, .light).dynamicTypeSize(.large))
        renderer.scale = 2
        guard let thumbnail = renderer.uiImage?.jpegData(compressionQuality: 0.8) else {
            error = "サムネイルを作成できませんでした。編集内容は保持しています。"; return false
        }
        let document = value.document(plateID: plateID, revisionID: UUID(), createdAt: createdAt)
        do {
            let saved = try await repository.save(document, expectedRevision: revisionID, photo: photoData, thumbnail: thumbnail, replacingPhoto: explicitlyReplacedPhoto, itemPhotos: itemImageBytes.filter { hash, _ in value.itemImageReferences.values.contains { $0.sha256 == hash } })
            revisionID = saved.revisionID; createdAt = saved.createdAt; draft = value; baseline = value
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
        itemImagesEnabled = document.rendererVersion >= 5
        layoutVersion = document.rendererVersion >= 6 ? document.rendererVersion : 0
        itemImageReferences = document.itemImageReferences ?? [:]
        template = PlateTemplate(rawValue: document.templateID) ?? .elegant
        background = PlateBackground(rawValue: document.backgroundStyle) ?? .signature
        frame = PlateFrame(rawValue: document.frameStyle) ?? .signature
        photoRotationQuarterTurns = document.photoRotationQuarterTurns ?? 0
        photoRotationDegrees = document.photoRotationDegrees
        titleTextStyle = document.titleTextStyle
        commentTextStyle = document.commentTextStyle
        itemNameTextStyle = document.itemNameTextStyle
        itemNameFontSize = document.itemNameFontSize
        commentFontSize = document.commentFontSize
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
        if let degrees = photoRotationDegrees {
            document.photoRotationDegrees = degrees; document.photoRotationQuarterTurns = nil; document.rendererVersion = 4
        }
        if itemImagesEnabled { document.rendererVersion = 5; document.itemImageReferences = itemImageReferences }
        if usesNewLayout {
            document.rendererVersion = layoutVersion
            document.itemImageReferences = itemImageReferences
            document.itemNameTextStyle = itemNameTextStyle
            document.itemNameFontSize = itemNameFontSize
            document.commentFontSize = commentFontSize
        }
        return document
    }
}

// 書き出し用の不変コピー。編集Session・Repositoryへの書き込み経路を持たない。
@MainActor struct PlateExportSnapshot: Identifiable {
    let id = UUID()
    let draft: PlateDraft
    let image: UIImage?
    let itemImages: [UUID: UIImage]
    let sourceDescription: String
    let warnings: [String]

    init(draft: PlateDraft, image: UIImage?, itemImages: [UUID: UIImage], sourceDescription: String, warnings: [String] = []) {
        self.draft = draft; self.image = image; self.itemImages = itemImages
        self.sourceDescription = sourceDescription; self.warnings = warnings
    }
    init(loaded: PlateLoadedDocument) throws {
        try loaded.document.validate()
        guard loaded.document.textStylesSupported else { throw PlateStorageError.unsupported }
        let session = PlateEditingSession(loaded: loaded)
        let value = session.exportSnapshot(source: "最後に保存した完成状態（確定revision）")
        self.init(draft: value.draft, image: value.image, itemImages: value.itemImages, sourceDescription: value.sourceDescription, warnings: value.warnings)
    }
}

extension PlateEditingSession {
    func exportSnapshot(source: String = "現在の編集中の表示（未保存の変更を含む）") -> PlateExportSnapshot {
        var warnings: [String] = []
        if photoState == .damagedSaved || photoState == .missingSource {
            warnings.append("主写真を読み込めません。写真なしの代替表示になります。")
        }
        if !damagedItemHashes.isEmpty {
            warnings.append("一部のアイテム写真が欠損・破損しています。カテゴリのアイコンで表示します。")
        }
        return .init(draft: draft, image: image, itemImages: itemImages, sourceDescription: source, warnings: warnings)
    }
}

nonisolated enum PlateExportFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg, png
    var id: Self { self }
    var title: String { self == .jpeg ? "JPEG" : "PNG" }
    var type: String { self == .jpeg ? UTType.jpeg.identifier : UTType.png.identifier }
    var suffix: String { self == .jpeg ? "jpg" : "png" }
}
nonisolated enum PlateExportResolution: Int, CaseIterable, Identifiable, Sendable {
    case standard = 3, high = 4
    var id: Self { self }
    var title: String { self == .standard ? "標準：1080 × 1350" : "高解像度：1440 × 1800" }
}
nonisolated enum PlateExportError: LocalizedError {
    case render, encode, permission, restricted, configuration, unsafeTemporary
    var errorDescription: String? {
        switch self {
        case .render: return "完成画像を描画できませんでした。編集内容は変更していません。"
        case .encode: return "画像ファイルを作成できませんでした。"
        case .permission: return "写真への追加が許可されていません。必要な場合はiPhoneの設定でNailNoteの写真への追加を許可してください。"
        case .restricted: return "この端末では写真への追加が制限されています。"
        case .configuration: return "写真保存の権限説明が設定されていないため、安全のため処理を停止しました。"
        case .unsafeTemporary: return "共有用の安全な一時領域を確認できませんでした。"
        }
    }
}

@MainActor enum PlateExportRenderer {
    static func render(_ snapshot: PlateExportSnapshot, resolution: PlateExportResolution) throws -> CGImage {
        guard snapshot.draft.rotationSupported, snapshot.draft.textStylesSupported else { throw PlateStorageError.unsupported }
        let renderer = ImageRenderer(content: PlateCanvasView(draft: .constant(snapshot.draft), image: snapshot.image, itemImages: snapshot.itemImages)
            .frame(width: 360, height: 450).background(Color.white)
            .environment(\.colorScheme, .light).dynamicTypeSize(.large))
        renderer.scale = CGFloat(resolution.rawValue)
        renderer.isOpaque = true
        guard let image = renderer.cgImage, image.width == 360 * resolution.rawValue, image.height == 450 * resolution.rawValue else { throw PlateExportError.render }
        return image
    }
    nonisolated static func encode(_ image: CGImage, format: PlateExportFormat) throws -> Data {
        try autoreleasepool {
            let bytes = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(bytes, format.type as CFString, 1, nil) else { throw PlateExportError.encode }
            let options: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.95] : [:]
            CGImageDestinationAddImage(destination, image, options as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw PlateExportError.encode }
            return bytes as Data
        }
    }
}

// 追加専用PhotoKit。読み取り・既存assetの変更／削除は要求しない。
@MainActor enum PlatePhotoLibraryWriter {
    static func validate(_ status: PHAuthorizationStatus) throws {
        if status == .restricted { throw PlateExportError.restricted }
        guard status == .authorized else { throw PlateExportError.permission }
    }
    static func save(_ data: Data, format: PlateExportFormat) async throws {
        guard let description = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") as? String, !description.isEmpty else { throw PlateExportError.configuration }
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined { status = await PHPhotoLibrary.requestAuthorization(for: .addOnly) }
        try validate(status)
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = format.type
            options.originalFilename = "NailNote-Plate." + format.suffix
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: options)
        }
    }
}

// 共有ごとに専用URLを発行。完了が不明なファイルを他の共有から清掃しない。
@MainActor final class PlateShareFile: Identifiable {
    let id: UUID
    let url: URL
    private let folder: URL
    init(data: Data, format: PlateExportFormat, temporaryRoot: URL = FileManager.default.temporaryDirectory,
         write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .withoutOverwriting) }) throws {
        id = UUID()
        let root = temporaryRoot.resolvingSymlinksInPath().standardizedFileURL
        guard try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { throw PlateExportError.unsafeTemporary }
        folder = root.appendingPathComponent("NailNote-PlateExport-" + id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        url = folder.appendingPathComponent("NailNote-Plate." + format.suffix)
        let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
              folder.resolvingSymlinksInPath().pathComponents == root.pathComponents + [folder.lastPathComponent] else { throw PlateExportError.unsafeTemporary }
        // 未公開の固有フォルダへ完全に書き終えてから共有する。atomicとの併用は不可。
        do { try write(data, url) }
        catch {
            // 未公開の自分の部分ファイルだけ整理する。共有済み・他セッションには触れない。
            if folder.resolvingSymlinksInPath() == folder,
               let value = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
               value.isRegularFile == true, value.isSymbolicLink != true { try? FileManager.default.removeItem(at: url) }
            if (try? FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty) == true { try? FileManager.default.removeItem(at: folder) }
            throw error
        }
    }
    func completed() {
        // 標準共有のcompletion後だけ、自分が作った通常ファイルを削除する。
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              folder.resolvingSymlinksInPath() == folder else { return }
        try? FileManager.default.removeItem(at: url)
        if (try? FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty) == true { try? FileManager.default.removeItem(at: folder) }
    }
}

struct PlateShareController: UIViewControllerRepresentable {
    let file: PlateShareFile
    let completion: (Bool, Error?) -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        controller.excludedActivityTypes = [.saveToCameraRoll]
        controller.completionWithItemsHandler = { _, completed, _, error in
            Task { @MainActor in
                file.completed()
                completion(completed, error)
            }
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

@MainActor final class PlateExportOperation: ObservableObject {
    @Published private(set) var busy = false
    @Published var share: PlateShareFile?
    @Published var message: String?
    private var task: Task<Void, Never>?
    func start(snapshot: PlateExportSnapshot, format: PlateExportFormat, resolution: PlateExportResolution, photos: Bool) {
        guard !busy, share == nil else { return }
        busy = true
        task = Task { @MainActor in
            defer { busy = false; task = nil }
            do {
                // 進行表示を更新した後にCanvasを一度だけ描画、エンコードは背景で行う。
                await Task.yield()
                try Task.checkCancellation()
                let image = try PlateExportRenderer.render(snapshot, resolution: resolution)
                let data = try await Task.detached(priority: .userInitiated) { try PlateExportRenderer.encode(image, format: format) }.value
                try Task.checkCancellation()
                if photos {
                    try await PlatePhotoLibraryWriter.save(data, format: format)
                    message = "写真に保存しました。"
                } else { share = try PlateShareFile(data: data, format: format) }
            } catch is CancellationError { }
            catch { message = "書き出しできませんでした。\n" + error.localizedDescription }
        }
    }
    func cancel() { task?.cancel() }
}

struct PlateExportSheet: View {
    let snapshot: PlateExportSnapshot
    @Environment(\.dismiss) private var dismiss
    @StateObject private var operation = PlateExportOperation()
    @State private var format: PlateExportFormat = .jpeg
    @State private var resolution: PlateExportResolution = .standard
    @State private var allowMissingImages = false
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
        let preset = GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne
        return NailAppearance.designPalette(preset.refinedSurfacePalette, choice: NailAppearance.Document.decode(appearanceRaw).resolved(.design))
    }
    private var dark: Bool {
        let preset = GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne
        let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.design)
        return choice.flatMap { $0.changesColor ? $0.dark : nil } ?? (preset == .noirGold || preset == .noirSilver)
    }
    var body: some View {
        NavigationStack {
            GlassBackgroundView(refined: true, appearanceArea: .design) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(snapshot.sourceDescription).font(.headline).accessibilityIdentifier("plate.export.source")
                        Text("作品データは変更せず、完成画像だけを書き出します。")
                            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        Picker("形式", selection: $format) {
                            ForEach(PlateExportFormat.allCases) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented).accessibilityIdentifier("plate.export.format")
                        VStack(alignment: .leading, spacing: 6) {
                            Text("解像度").font(.headline)
                            ForEach(PlateExportResolution.allCases) { option in
                                Button { resolution = option } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: resolution == option ? "checkmark.circle.fill" : "circle").frame(width: 22)
                                        Text(option.title).fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                    .accessibilityAddTraits(resolution == option ? .isSelected : [])
                                    .accessibilityIdentifier("plate.export.resolution.\(option.rawValue)")
                            }
                            Text("画像の精細さは元の写真に依存します。").font(.caption).foregroundStyle(palette.tagText)
                        }
                        if !snapshot.warnings.isEmpty {
                            Text(snapshot.warnings.joined(separator: "\n")).foregroundStyle(.secondary)
                            Toggle("画像のない代替表示で書き出す", isOn: $allowMissingImages)
                                .accessibilityIdentifier("plate.export.allowMissing")
                        }
                        Button { run(photos: true) } label: {
                            Label("写真に保存", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.plain)
                            .background(LinearGradient(colors: [palette.glowFillTop, palette.glowFillBottom], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(palette.tagStroke, lineWidth: 1))
                            .accessibilityIdentifier("plate.export.photos")
                        Button { run(photos: false) } label: {
                            Label("共有", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.bordered).accessibilityIdentifier("plate.export.share")
                        if operation.busy { ProgressView("画像を準備しています…").accessibilityIdentifier("plate.export.progress") }
                    }.padding(20)
                }
            }
            .navigationTitle("書き出し").navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(dark ? .dark : .light, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }.frame(minHeight: 44).disabled(operation.busy || operation.share != nil)
                    .accessibilityIdentifier("plate.export.close")
            } }
            .disabled(operation.busy || operation.share != nil)
        }
        .modifier(NailAppearanceEnvironment(area: .design))
        .foregroundStyle(palette.titleText)
        .tint(palette.titleIcon)
        .environment(\.colorScheme, dark ? .dark : .light)
        .interactiveDismissDisabled(operation.busy || operation.share != nil)
        .onDisappear { operation.cancel() }
        .sheet(item: $operation.share) { file in
            PlateShareController(file: file) { _, error in
                operation.share = nil
                if let error { operation.message = "共有できませんでした。\n" + error.localizedDescription }
            }
        }
        .alert("画像の書き出し", isPresented: Binding(get: { operation.message != nil }, set: { if !$0 { operation.message = nil } })) {
            Button("OK") { operation.message = nil }
        } message: { Text(operation.message ?? "") }
    }
    private func run(photos: Bool) {
        guard snapshot.warnings.isEmpty || allowMissingImages else {
            operation.message = "画像の欠損を確認し、代替表示で書き出す場合は確認スイッチをオンにしてください。"; return
        }
        operation.start(snapshot: snapshot, format: format, resolution: resolution, photos: photos)
    }
}

// renderer6の配置。画像・名前・コメントの境界を共有し、旧構図には適用しない。
nonisolated struct PlateLayoutSixGeometry {
    struct Slot { let photo: CGRect; let name: CGRect }
    let slots: [Slot]
    let date: CGRect
    let comment: CGRect
    let overflow: CGRect
    let empty: CGRect
    init(template: PlateTemplate) {
        switch template {
        case .elegant, .sweet:
            slots = (0..<3).map { index in
                let x = CGFloat(28 + index * 104)
                return Slot(photo: CGRect(x: x + 32, y: 326, width: 32, height: 32), name: CGRect(x: x, y: 362, width: 96, height: 36))
            }
            date = CGRect(x: 28, y: 15, width: 304, height: 15)
            comment = CGRect(x: 28, y: 405, width: 304, height: 32)
            overflow = CGRect(x: 304, y: 338, width: 28, height: 12)
            empty = CGRect(x: 28, y: 342, width: 304, height: 32)
        case .noir:
            slots = (0..<3).map { index in
                let y = CGFloat(94 + index * 86)
                return Slot(photo: CGRect(x: 281, y: y, width: 34, height: 34), name: CGRect(x: 254, y: y + 38, width: 88, height: 36))
            }
            date = CGRect(x: 254, y: 52, width: 88, height: 28)
            comment = CGRect(x: 20, y: 376, width: 320, height: 61)
            overflow = CGRect(x: 254, y: 346, width: 88, height: 12)
            empty = CGRect(x: 254, y: 150, width: 88, height: 40)
        case .recipe:
            slots = (0..<3).map { index in
                let y = CGFloat(254 + index * 45)
                return Slot(photo: CGRect(x: 47, y: y + 6, width: 30, height: 30), name: CGRect(x: 85, y: y + 5, width: 246, height: 32))
            }
            date = CGRect(x: 22, y: 12, width: 316, height: 15)
            comment = CGRect(x: 22, y: 405, width: 316, height: 32)
            overflow = CGRect(x: 22, y: 389, width: 316, height: 12)
            empty = CGRect(x: 22, y: 287, width: 316, height: 42)
        }
    }
}

// 7だけの日付とコメント。画像・名前の矩形は6から変更しない。
nonisolated struct PlateLayoutSevenFooter {
    let date: CGRect
    let comment: CGRect
    init(template: PlateTemplate) {
        switch template {
        case .elegant, .sweet:
            comment = CGRect(x: 28, y: 405, width: 208, height: 32)
            date = CGRect(x: 244, y: 421, width: 88, height: 16)
        case .noir:
            comment = CGRect(x: 20, y: 376, width: 226, height: 61)
            date = CGRect(x: 254, y: 421, width: 88, height: 16)
        case .recipe:
            comment = CGRect(x: 22, y: 405, width: 218, height: 32)
            date = CGRect(x: 248, y: 421, width: 88, height: 16)
        }
    }
}

// 新構図は完成作品を一枚に合成する。旧版の影の描画経路は保持する。
private struct PlateLayoutSixComposite: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.compositingGroup() } else { content }
    }
}

struct PlateLayoutUpdateButton: View {
    @Binding var draft: PlateDraft
    @State private var confirming = false
    var body: some View {
        Button("新レイアウトに更新") { confirming = true }
            .frame(minHeight: 44).accessibilityIdentifier("plate.layout.upgrade")
            .alert("新レイアウトへ更新しますか？", isPresented: $confirming) {
                Button("renderer7でプレビュー") { draft.layoutVersion = 7; draft.itemImagesEnabled = true }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("renderer7へ更新します。アイテム画像を中央でトリミングし、日付を右下に移します。画像の上下や左右が一部切れる場合があります。コメント幅も狭くなります。旧構図ではタイトルを非表示にし、写真・アイテム欄を広げます。写真未対応の旧作品では現在のアイテム写真も追加します。元の文字と写真は保持し、保存するまで旧版は変わりません。")
            }
    }
}
