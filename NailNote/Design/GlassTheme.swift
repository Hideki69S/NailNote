import SwiftUI
import UIKit

/// 従来のテーマキーには書き込まない、追加の外観設定。
enum NailAppearance {
    static let key = "NailNoteAppearanceV1"
    enum Area: String, Codable, CaseIterable, Identifiable {
        case design, items, tabBar, addButton, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .design: return "デザイン画面"
            case .items: return "アイテム画面"
            case .tabBar: return "下部タブバー"
            case .addButton: return "追加（＋）ボタン"
            case .settings: return "設定画面"
            }
        }
        var hasBackground: Bool { self == .design || self == .items || self == .settings }
    }
    enum Preset: String, Codable, CaseIterable, Identifiable {
        case standard, silkLavender, rosePearl, sageMist, champagne, midnightGold, custom
        var id: String { rawValue }
        var title: String {
            switch self {
            case .standard: return "標準（Refined Luxury）"
            case .silkLavender: return "Silk Lavender"
            case .rosePearl: return "Rose Pearl"
            case .sageMist: return "Sage Mist"
            case .champagne: return "Champagne"
            case .midnightGold: return "Midnight Gold"
            case .custom: return "自由なカラー"
            }
        }
        var rgb: RGB {
            switch self {
            case .silkLavender: return RGB(r: 0.72, g: 0.65, b: 0.84)
            case .rosePearl: return RGB(r: 0.85, g: 0.63, b: 0.69)
            case .sageMist: return RGB(r: 0.57, g: 0.69, b: 0.61)
            case .champagne, .standard: return RGB(r: 0.81, g: 0.74, b: 0.61)
            case .midnightGold: return RGB(r: 0.10, g: 0.13, b: 0.19)
            case .custom: return RGB(r: 0.57, g: 0.66, b: 0.77)
            }
        }
    }
    enum Background: String, Codable, CaseIterable, Identifiable {
        case silk, satin, gradient, solid
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }
    struct RGB: Codable, Equatable {
        var r: Double
        var g: Double
        var b: Double
        var valid: Bool { [r, g, b].allSatisfy { $0.isFinite && (0...1).contains($0) } }
        var color: Color { Color(red: r, green: g, blue: b) }
        var dark: Bool { 0.2126 * r + 0.7152 * g + 0.0722 * b < 0.38 }
        func mixed(with other: RGB, amount: Double) -> RGB {
            RGB(r: r + (other.r-r)*amount, g: g + (other.g-g)*amount, b: b + (other.b-b)*amount)
        }
        init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
        init(color: Color) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            self.init(r: Double(r), g: Double(g), b: Double(b))
        }
    }
    struct Choice: Codable, Equatable {
        var preset: Preset = .standard
        var customColor: RGB? = nil
        var background: Background? = nil
        var rgb: RGB { preset == .custom ? (customColor ?? preset.rgb) : preset.rgb }
        var valid: Bool { preset != .custom || customColor?.valid == true }
        var changesColor: Bool { preset != .standard }
        var dark: Bool { rgb.dark }
        var signature: String { String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? "" }
    }
    struct Document: Codable, Equatable {
        private final class Cached: NSObject {
            let document: Document
            init(_ document: Document) { self.document = document }
        }
        private static let cache: NSCache<NSString, Cached> = {
            let cache = NSCache<NSString, Cached>()
            cache.countLimit = 32
            return cache
        }()
        var version = 1
        var global: Choice? = nil
        var overrides: [String: Choice] = [:]
        func resolved(_ area: Area) -> Choice? { overrides[area.rawValue] ?? global }
        mutating func set(_ choice: Choice?, for area: Area?) {
            if let area { overrides[area.rawValue] = choice } else { global = choice }
        }
        static func decode(_ raw: String) -> Document {
            guard !raw.isEmpty else { return Document() }
            if let cached = cache.object(forKey: raw as NSString) { return cached.document }
            guard let data = raw.data(using: .utf8),
                  let document = try? JSONDecoder().decode(Document.self, from: data),
                  document.version == 1,
                  document.global?.valid != false,
                  document.overrides.allSatisfy({ Area(rawValue: $0.key) != nil && $0.value.valid }) else { return Document() }
            cache.setObject(Cached(document), forKey: raw as NSString)
            return document
        }
        var encoded: String { String(data: (try? JSONEncoder().encode(self)) ?? Data(), encoding: .utf8) ?? "" }
    }

    static func designPalette(_ original: GlassTheme.DesignCardPalette, choice: Choice?) -> GlassTheme.DesignCardPalette {
        guard let choice, choice.changesColor else { return original }
        let rgb = choice.rgb
        let white = RGB(r: 1, g: 1, b: 1)
        let ink = RGB(r: 0.055, g: 0.07, b: 0.095)
        let top = rgb.mixed(with: white, amount: rgb.dark ? 0.13 : 0.78).color
        let bottom = rgb.mixed(with: rgb.dark ? ink : white, amount: rgb.dark ? 0.10 : 0.57).color
        let text = rgb.dark ? Color(red: 0.96, green: 0.96, blue: 0.94) : ink.color
        let metal = choice.preset == .midnightGold ? RGB(r: 0.72, g: 0.62, b: 0.40) : rgb
        let edge = metal.mixed(with: rgb.dark ? white : ink, amount: rgb.dark ? 0.55 : 0.48).color
        return GlassTheme.DesignCardPalette(titleIcon: edge, titleText: text,
            outerFillTop: top, outerFillBottom: bottom, outerStrokeStart: metal.mixed(with: white, amount: 0.65).color,
            outerStrokeEnd: edge, outerStroke: edge, thumbnailStrokeStart: top, thumbnailStrokeEnd: edge,
            glowFillTop: top, glowFillMid: rgb.mixed(with: white, amount: rgb.dark ? 0.08 : 0.68).color,
            glowFillBottom: bottom, glowStrokeStart: top, glowStrokeEnd: edge,
            tagText: text.opacity(0.85), tagStroke: edge.opacity(0.5), badgeStart: top, badgeEnd: bottom)
    }
    static func itemPalette(_ original: GlassTheme.ItemCardPalette, choice: Choice?) -> GlassTheme.ItemCardPalette {
        guard let choice, choice.changesColor else { return original }
        let p = designPalette(GlassTheme.designCardPalette(for: .roseChampagne), choice: choice)
        return GlassTheme.ItemCardPalette(fillTop: p.glowFillTop, fillBottom: p.glowFillBottom,
            outerFillTop: p.outerFillTop, outerFillBottom: p.outerFillBottom, outerStrokeStart: p.outerStrokeStart,
            outerStrokeEnd: p.outerStrokeEnd, outerStroke: p.outerStroke, strokeStart: p.glowStrokeStart, strokeEnd: p.glowStrokeEnd)
    }
}

/// カスタマイズ対象画面だけへ適用し、未設定時は環境も変更しない。
struct NailAppearanceEnvironment: ViewModifier {
    let area: NailAppearance.Area
    @AppStorage(NailAppearance.key) private var raw = ""
    @ViewBuilder func body(content: Content) -> some View {
        if let choice = NailAppearance.Document.decode(raw).resolved(area), choice.changesColor {
            let palette = NailAppearance.designPalette(GlassTheme.designCardPalette(for: .roseChampagne), choice: choice)
            content.environment(\.colorScheme, choice.dark ? .dark : .light).tint(palette.titleIcon)
        } else { content }
    }
}

/// Glassmorphism用の共通カラーテーマ
struct GlassTheme {
    enum Keys {
        static let backgroundPreset = "ThemeBackgroundPreset"
        static let designCardPreset = "ThemeDesignCardPreset"
        static let itemCardPreset = "ThemeItemCardPreset"
        static let aiChartPreset = "ThemeAIChartPreset"
    }

    enum BackgroundPreset: String, CaseIterable, Identifiable {
        case smokySageChampagne
        case stoneRose
        case mistBlueTaupe
        case graphiteMint
        case ivoryCoral
        case noirSilver
        case noirGold
        case ivoryGold
        case rainbow

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .smokySageChampagne: return "スモーキーセージ"
            case .stoneRose: return "ストーンローズ"
            case .mistBlueTaupe: return "ミストブルー"
            case .graphiteMint: return "グラファイトミント"
            case .ivoryCoral: return "アイボリーコーラル"
            case .noirSilver: return "ノワールシルバー"
            case .noirGold: return "ノワールゴールド"
            case .ivoryGold: return "アイボリーゴールド"
            case .rainbow: return "レインボー"
            }
        }
    }

    enum DesignCardPreset: String, CaseIterable, Identifiable {
        case roseChampagne
        case mauveBronze
        case sageGold
        case slateBlueSilver
        case terracottaCream
        case noirSilver
        case noirGold
        case ivoryGold
        case rainbow

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .roseChampagne: return "ローズシャンパン"
            case .mauveBronze: return "モーブブロンズ"
            case .sageGold: return "セージゴールド"
            case .slateBlueSilver: return "スレートブルー"
            case .terracottaCream: return "テラコッタクリーム"
            case .noirSilver: return "ノワールシルバー"
            case .noirGold: return "ノワールゴールド"
            case .ivoryGold: return "アイボリーゴールド"
            case .rainbow: return "レインボー"
            }
        }
    }

    enum ItemCardPreset: String, CaseIterable, Identifiable {
        case roseChampagne
        case mauveBronze
        case sageGold
        case slateBlueSilver
        case terracottaCream
        case noirSilver
        case noirGold
        case ivoryGold
        case rainbow

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .roseChampagne: return "ローズシャンパン"
            case .mauveBronze: return "モーブブロンズ"
            case .sageGold: return "セージゴールド"
            case .slateBlueSilver: return "スレートブルー"
            case .terracottaCream: return "テラコッタクリーム"
            case .noirSilver: return "ノワールシルバー"
            case .noirGold: return "ノワールゴールド"
            case .ivoryGold: return "アイボリーゴールド"
            case .rainbow: return "レインボー"
            }
        }
    }

    enum AIScoreChartPreset: String, CaseIterable, Identifiable {
        case freshGreen
        case oceanBlue
        case sunsetCoral
        case violetSmoke
        case amberOlive

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .freshGreen: return "フレッシュグリーン"
            case .oceanBlue: return "オーシャンブルー"
            case .sunsetCoral: return "サンセットコーラル"
            case .violetSmoke: return "バイオレットスモーク"
            case .amberOlive: return "アンバーオリーブ"
            }
        }
    }

    struct DesignCardPalette {
        let titleIcon: Color
        let titleText: Color
        let outerFillTop: Color
        let outerFillBottom: Color
        let outerStrokeStart: Color
        let outerStrokeEnd: Color
        let outerStroke: Color
        let thumbnailStrokeStart: Color
        let thumbnailStrokeEnd: Color
        let glowFillTop: Color
        let glowFillMid: Color
        let glowFillBottom: Color
        let glowStrokeStart: Color
        let glowStrokeEnd: Color
        let tagText: Color
        let tagStroke: Color
        let badgeStart: Color
        let badgeEnd: Color
    }

    struct ItemCardPalette {
        let fillTop: Color
        let fillBottom: Color
        let outerFillTop: Color
        let outerFillBottom: Color
        let outerStrokeStart: Color
        let outerStrokeEnd: Color
        let outerStroke: Color
        let strokeStart: Color
        let strokeEnd: Color
    }

    struct AIScoreChartPalette {
        let haloInner: Color
        let haloMid: Color
        let gridOuter: Color
        let gridInner: Color
        let outerDash: Color
        let axis: Color
        let areaTop: Color
        let areaMid: Color
        let areaBottom: Color
        let lineStart: Color
        let lineEnd: Color
        let lineShadow: Color
        let pointGlow: Color
        let pointFill: Color
        let pointStroke: Color
        let centerFillStart: Color
        let centerFillEnd: Color
        let centerStrokeStart: Color
        let centerStrokeEnd: Color
        let centerScore: Color
        let centerTotal: Color
        let labelFill: Color
        let labelStroke: Color
    }

    private static var backgroundPreset: BackgroundPreset {
        let raw = UserDefaults.standard.string(forKey: Keys.backgroundPreset)
        return BackgroundPreset(rawValue: raw ?? "") ?? .smokySageChampagne
    }

    private static var designCardPreset: DesignCardPreset {
        let raw = UserDefaults.standard.string(forKey: Keys.designCardPreset)
        return DesignCardPreset(rawValue: raw ?? "") ?? .roseChampagne
    }

    private static var itemCardPreset: ItemCardPreset {
        let raw = UserDefaults.standard.string(forKey: Keys.itemCardPreset)
        return ItemCardPreset(rawValue: raw ?? "") ?? .roseChampagne
    }

    private static var aiChartPreset: AIScoreChartPreset {
        let raw = UserDefaults.standard.string(forKey: Keys.aiChartPreset)
        return AIScoreChartPreset(rawValue: raw ?? "") ?? .freshGreen
    }

    /// 背景グラデーション（スモーキーセージ〜シャンパン）
    static func backgroundGradient(for preset: BackgroundPreset) -> LinearGradient {
        LinearGradient(colors: backgroundColors(for: preset), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 背景スタイルも従来9テーマの背景色を直接使い、カード色へ変換しない。
    static func backgroundColors(for preset: BackgroundPreset) -> [Color] {
        let colors: [Color]
        switch preset {
        case .smokySageChampagne:
            colors = [
                Color(red: 0.95, green: 0.97, blue: 0.94),
                Color(red: 0.90, green: 0.94, blue: 0.89),
                Color(red: 0.97, green: 0.92, blue: 0.84)
            ]
        case .stoneRose:
            colors = [
                Color(red: 0.94, green: 0.94, blue: 0.93),
                Color(red: 0.89, green: 0.87, blue: 0.88),
                Color(red: 0.93, green: 0.84, blue: 0.86)
            ]
        case .mistBlueTaupe:
            colors = [
                Color(red: 0.91, green: 0.95, blue: 0.98),
                Color(red: 0.85, green: 0.90, blue: 0.95),
                Color(red: 0.89, green: 0.86, blue: 0.82)
            ]
        case .graphiteMint:
            colors = [
                Color(red: 0.90, green: 0.93, blue: 0.92),
                Color(red: 0.80, green: 0.86, blue: 0.84),
                Color(red: 0.76, green: 0.82, blue: 0.80)
            ]
        case .ivoryCoral:
            colors = [
                Color(red: 0.98, green: 0.95, blue: 0.90),
                Color(red: 0.95, green: 0.90, blue: 0.84),
                Color(red: 0.93, green: 0.84, blue: 0.79)
            ]
        case .noirSilver:
            colors = [
                Color(red: 0.16, green: 0.17, blue: 0.20),
                Color(red: 0.20, green: 0.22, blue: 0.26),
                Color(red: 0.30, green: 0.32, blue: 0.36)
            ]
        case .noirGold:
            colors = [
                Color(red: 0.18, green: 0.15, blue: 0.12),
                Color(red: 0.25, green: 0.20, blue: 0.15),
                Color(red: 0.39, green: 0.31, blue: 0.20)
            ]
        case .ivoryGold:
            colors = [
                Color(red: 0.96, green: 0.94, blue: 0.90),
                Color(red: 0.93, green: 0.89, blue: 0.80),
                Color(red: 0.90, green: 0.82, blue: 0.66)
            ]
        case .rainbow:
            colors = [
                Color(hue: 0.00, saturation: 0.28, brightness: 0.99),
                Color(hue: 0.15, saturation: 0.24, brightness: 0.98),
                Color(hue: 0.33, saturation: 0.23, brightness: 0.97),
                Color(hue: 0.50, saturation: 0.24, brightness: 0.98),
                Color(hue: 0.62, saturation: 0.26, brightness: 0.98),
                Color(hue: 0.78, saturation: 0.24, brightness: 0.98)
            ]
        }
        return colors
    }

    /// オーブ（光）に使う色
    static func orbColors(for preset: BackgroundPreset) -> [Color] {
        switch preset {
        case .smokySageChampagne:
            return [
                Color(red: 0.79, green: 0.89, blue: 0.77).opacity(0.30),
                Color(red: 0.94, green: 0.86, blue: 0.76).opacity(0.28),
                Color(red: 0.86, green: 0.93, blue: 0.84).opacity(0.26)
            ]
        case .stoneRose:
            return [
                Color(red: 0.83, green: 0.82, blue: 0.82).opacity(0.30),
                Color(red: 0.92, green: 0.80, blue: 0.84).opacity(0.28),
                Color(red: 0.89, green: 0.86, blue: 0.84).opacity(0.26)
            ]
        case .mistBlueTaupe:
            return [
                Color(red: 0.72, green: 0.84, blue: 0.98).opacity(0.30),
                Color(red: 0.79, green: 0.88, blue: 0.95).opacity(0.28),
                Color(red: 0.90, green: 0.84, blue: 0.78).opacity(0.26)
            ]
        case .graphiteMint:
            return [
                Color(red: 0.56, green: 0.73, blue: 0.69).opacity(0.30),
                Color(red: 0.66, green: 0.80, blue: 0.75).opacity(0.28),
                Color(red: 0.60, green: 0.70, blue: 0.67).opacity(0.26)
            ]
        case .ivoryCoral:
            return [
                Color(red: 0.96, green: 0.81, blue: 0.73).opacity(0.30),
                Color(red: 0.94, green: 0.88, blue: 0.76).opacity(0.28),
                Color(red: 0.91, green: 0.77, blue: 0.71).opacity(0.26)
            ]
        case .noirSilver:
            return [
                Color(red: 0.62, green: 0.66, blue: 0.73).opacity(0.24),
                Color(red: 0.52, green: 0.57, blue: 0.64).opacity(0.22),
                Color(red: 0.76, green: 0.80, blue: 0.86).opacity(0.20)
            ]
        case .noirGold:
            return [
                Color(red: 0.80, green: 0.66, blue: 0.42).opacity(0.24),
                Color(red: 0.70, green: 0.56, blue: 0.34).opacity(0.22),
                Color(red: 0.88, green: 0.74, blue: 0.48).opacity(0.20)
            ]
        case .ivoryGold:
            return [
                Color(red: 0.84, green: 0.74, blue: 0.52).opacity(0.24),
                Color(red: 0.91, green: 0.84, blue: 0.68).opacity(0.22),
                Color(red: 0.79, green: 0.69, blue: 0.48).opacity(0.20)
            ]
        case .rainbow:
            return [
                Color(hue: 0.00, saturation: 0.62, brightness: 0.94).opacity(0.24),
                Color(hue: 0.33, saturation: 0.58, brightness: 0.90).opacity(0.24),
                Color(hue: 0.62, saturation: 0.64, brightness: 0.95).opacity(0.24)
            ]
        }
    }

    static var backgroundGradient: LinearGradient {
        backgroundGradient(for: backgroundPreset)
    }

    static var orbColors: [Color] {
        orbColors(for: backgroundPreset)
    }

    /// カード枠線（薄い黒）
    static var cardStrokeColor: Color {
        Color.black.opacity(0.12)
    }

    /// 既存呼び出しとの互換用
    static var cardStroke: Color { cardStrokeColor }

    /// カード影（最小限）
    static var cardShadowColor: Color {
        Color.black.opacity(0.15)
    }

    /// カード内部に使う淡いグラデーション
    static var cardFillGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.85),
                Color(red: 0.99, green: 0.93, blue: 1.0).opacity(0.80)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// カード角丸
    static var cardCornerRadius: CGFloat { 15 }

    /// 記録/用品カードの固定幅（iPhoneでも余白が残る程度）
    static let listCardWidth: CGFloat = 360

    static func designCardPalette(for preset: DesignCardPreset, variantIndex: Int = 0) -> DesignCardPalette {
        switch preset {
        case .roseChampagne:
            return DesignCardPalette(
                titleIcon: Color(red: 0.58, green: 0.49, blue: 0.53),
                titleText: Color(red: 0.34, green: 0.27, blue: 0.30),
                outerFillTop: Color(red: 0.91, green: 0.81, blue: 0.84),
                outerFillBottom: Color(red: 0.85, green: 0.73, blue: 0.77),
                outerStrokeStart: Color(red: 0.73, green: 0.47, blue: 0.54).opacity(0.96),
                outerStrokeEnd: Color(red: 0.52, green: 0.33, blue: 0.38).opacity(0.90),
                outerStroke: Color(red: 0.58, green: 0.37, blue: 0.42).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.92, green: 0.78, blue: 0.80),
                thumbnailStrokeEnd: Color(red: 0.86, green: 0.80, blue: 0.74),
                glowFillTop: Color(red: 0.99, green: 0.97, blue: 0.94),
                glowFillMid: Color(red: 0.97, green: 0.93, blue: 0.91),
                glowFillBottom: Color(red: 0.95, green: 0.91, blue: 0.90),
                glowStrokeStart: Color(red: 0.83, green: 0.64, blue: 0.67).opacity(0.48),
                glowStrokeEnd: Color(red: 0.93, green: 0.79, blue: 0.72).opacity(0.48),
                tagText: Color(red: 0.40, green: 0.31, blue: 0.34),
                tagStroke: Color(red: 0.82, green: 0.67, blue: 0.69).opacity(0.45),
                badgeStart: Color(red: 0.86, green: 0.60, blue: 0.67),
                badgeEnd: Color(red: 0.73, green: 0.58, blue: 0.62)
            )
        case .mauveBronze:
            return DesignCardPalette(
                titleIcon: Color(red: 0.49, green: 0.44, blue: 0.50),
                titleText: Color(red: 0.29, green: 0.27, blue: 0.32),
                outerFillTop: Color(red: 0.86, green: 0.81, blue: 0.83),
                outerFillBottom: Color(red: 0.80, green: 0.73, blue: 0.76),
                outerStrokeStart: Color(red: 0.61, green: 0.46, blue: 0.50).opacity(0.96),
                outerStrokeEnd: Color(red: 0.43, green: 0.33, blue: 0.36).opacity(0.90),
                outerStroke: Color(red: 0.47, green: 0.37, blue: 0.40).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.82, green: 0.74, blue: 0.71),
                thumbnailStrokeEnd: Color(red: 0.76, green: 0.70, blue: 0.66),
                glowFillTop: Color(red: 0.95, green: 0.94, blue: 0.93),
                glowFillMid: Color(red: 0.91, green: 0.88, blue: 0.89),
                glowFillBottom: Color(red: 0.88, green: 0.85, blue: 0.86),
                glowStrokeStart: Color(red: 0.65, green: 0.56, blue: 0.50).opacity(0.50),
                glowStrokeEnd: Color(red: 0.78, green: 0.67, blue: 0.58).opacity(0.50),
                tagText: Color(red: 0.34, green: 0.31, blue: 0.34),
                tagStroke: Color(red: 0.67, green: 0.59, blue: 0.55).opacity(0.46),
                badgeStart: Color(red: 0.67, green: 0.57, blue: 0.61),
                badgeEnd: Color(red: 0.56, green: 0.49, blue: 0.54)
            )
        case .sageGold:
            return DesignCardPalette(
                titleIcon: Color(red: 0.43, green: 0.49, blue: 0.44),
                titleText: Color(red: 0.24, green: 0.31, blue: 0.26),
                outerFillTop: Color(red: 0.84, green: 0.88, blue: 0.78),
                outerFillBottom: Color(red: 0.76, green: 0.81, blue: 0.70),
                outerStrokeStart: Color(red: 0.57, green: 0.64, blue: 0.44).opacity(0.96),
                outerStrokeEnd: Color(red: 0.36, green: 0.46, blue: 0.29).opacity(0.90),
                outerStroke: Color(red: 0.41, green: 0.50, blue: 0.33).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.84, green: 0.82, blue: 0.70),
                thumbnailStrokeEnd: Color(red: 0.74, green: 0.82, blue: 0.71),
                glowFillTop: Color(red: 0.95, green: 0.97, blue: 0.93),
                glowFillMid: Color(red: 0.90, green: 0.94, blue: 0.88),
                glowFillBottom: Color(red: 0.90, green: 0.92, blue: 0.84),
                glowStrokeStart: Color(red: 0.66, green: 0.70, blue: 0.52).opacity(0.50),
                glowStrokeEnd: Color(red: 0.79, green: 0.72, blue: 0.50).opacity(0.50),
                tagText: Color(red: 0.30, green: 0.37, blue: 0.30),
                tagStroke: Color(red: 0.70, green: 0.72, blue: 0.56).opacity(0.46),
                badgeStart: Color(red: 0.56, green: 0.67, blue: 0.49),
                badgeEnd: Color(red: 0.48, green: 0.58, blue: 0.44)
            )
        case .slateBlueSilver:
            return DesignCardPalette(
                titleIcon: Color(red: 0.38, green: 0.45, blue: 0.56),
                titleText: Color(red: 0.22, green: 0.28, blue: 0.36),
                outerFillTop: Color(red: 0.80, green: 0.85, blue: 0.91),
                outerFillBottom: Color(red: 0.72, green: 0.78, blue: 0.86),
                outerStrokeStart: Color(red: 0.47, green: 0.61, blue: 0.80).opacity(0.96),
                outerStrokeEnd: Color(red: 0.26, green: 0.38, blue: 0.56).opacity(0.90),
                outerStroke: Color(red: 0.31, green: 0.42, blue: 0.57).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.76, green: 0.83, blue: 0.93),
                thumbnailStrokeEnd: Color(red: 0.69, green: 0.77, blue: 0.88),
                glowFillTop: Color(red: 0.93, green: 0.95, blue: 0.98),
                glowFillMid: Color(red: 0.88, green: 0.91, blue: 0.96),
                glowFillBottom: Color(red: 0.84, green: 0.88, blue: 0.94),
                glowStrokeStart: Color(red: 0.54, green: 0.64, blue: 0.78).opacity(0.50),
                glowStrokeEnd: Color(red: 0.62, green: 0.71, blue: 0.84).opacity(0.50),
                tagText: Color(red: 0.27, green: 0.34, blue: 0.45),
                tagStroke: Color(red: 0.58, green: 0.67, blue: 0.80).opacity(0.46),
                badgeStart: Color(red: 0.48, green: 0.61, blue: 0.79),
                badgeEnd: Color(red: 0.40, green: 0.53, blue: 0.70)
            )
        case .terracottaCream:
            return DesignCardPalette(
                titleIcon: Color(red: 0.56, green: 0.40, blue: 0.33),
                titleText: Color(red: 0.37, green: 0.25, blue: 0.20),
                outerFillTop: Color(red: 0.92, green: 0.83, blue: 0.76),
                outerFillBottom: Color(red: 0.86, green: 0.74, blue: 0.66),
                outerStrokeStart: Color(red: 0.79, green: 0.53, blue: 0.38).opacity(0.96),
                outerStrokeEnd: Color(red: 0.55, green: 0.34, blue: 0.24).opacity(0.90),
                outerStroke: Color(red: 0.62, green: 0.40, blue: 0.29).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.91, green: 0.76, blue: 0.66),
                thumbnailStrokeEnd: Color(red: 0.85, green: 0.70, blue: 0.61),
                glowFillTop: Color(red: 0.98, green: 0.94, blue: 0.89),
                glowFillMid: Color(red: 0.95, green: 0.89, blue: 0.83),
                glowFillBottom: Color(red: 0.92, green: 0.84, blue: 0.77),
                glowStrokeStart: Color(red: 0.74, green: 0.52, blue: 0.40).opacity(0.50),
                glowStrokeEnd: Color(red: 0.82, green: 0.61, blue: 0.48).opacity(0.50),
                tagText: Color(red: 0.44, green: 0.30, blue: 0.23),
                tagStroke: Color(red: 0.76, green: 0.60, blue: 0.49).opacity(0.46),
                badgeStart: Color(red: 0.79, green: 0.51, blue: 0.39),
                badgeEnd: Color(red: 0.68, green: 0.44, blue: 0.34)
            )
        case .noirSilver:
            return DesignCardPalette(
                titleIcon: Color(red: 0.78, green: 0.82, blue: 0.88),
                titleText: Color(red: 0.87, green: 0.90, blue: 0.95),
                outerFillTop: Color(red: 0.30, green: 0.32, blue: 0.36),
                outerFillBottom: Color(red: 0.21, green: 0.23, blue: 0.27),
                outerStrokeStart: Color(red: 0.74, green: 0.78, blue: 0.85).opacity(0.96),
                outerStrokeEnd: Color(red: 0.52, green: 0.56, blue: 0.63).opacity(0.90),
                outerStroke: Color(red: 0.59, green: 0.64, blue: 0.72).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.68, green: 0.73, blue: 0.80),
                thumbnailStrokeEnd: Color(red: 0.55, green: 0.60, blue: 0.68),
                glowFillTop: Color(red: 0.35, green: 0.37, blue: 0.42),
                glowFillMid: Color(red: 0.28, green: 0.30, blue: 0.35),
                glowFillBottom: Color(red: 0.23, green: 0.25, blue: 0.30),
                glowStrokeStart: Color(red: 0.70, green: 0.74, blue: 0.82).opacity(0.50),
                glowStrokeEnd: Color(red: 0.50, green: 0.55, blue: 0.62).opacity(0.50),
                tagText: Color(red: 0.88, green: 0.91, blue: 0.95),
                tagStroke: Color(red: 0.63, green: 0.68, blue: 0.76).opacity(0.48),
                badgeStart: Color(red: 0.74, green: 0.78, blue: 0.86),
                badgeEnd: Color(red: 0.56, green: 0.60, blue: 0.70)
            )
        case .noirGold:
            return DesignCardPalette(
                titleIcon: Color(red: 0.88, green: 0.77, blue: 0.53),
                titleText: Color(red: 0.95, green: 0.88, blue: 0.71),
                outerFillTop: Color(red: 0.32, green: 0.26, blue: 0.18),
                outerFillBottom: Color(red: 0.22, green: 0.18, blue: 0.13),
                outerStrokeStart: Color(red: 0.90, green: 0.78, blue: 0.52).opacity(0.96),
                outerStrokeEnd: Color(red: 0.66, green: 0.52, blue: 0.30).opacity(0.90),
                outerStroke: Color(red: 0.74, green: 0.60, blue: 0.36).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.86, green: 0.73, blue: 0.48),
                thumbnailStrokeEnd: Color(red: 0.70, green: 0.55, blue: 0.33),
                glowFillTop: Color(red: 0.39, green: 0.31, blue: 0.21),
                glowFillMid: Color(red: 0.31, green: 0.25, blue: 0.17),
                glowFillBottom: Color(red: 0.25, green: 0.20, blue: 0.14),
                glowStrokeStart: Color(red: 0.85, green: 0.72, blue: 0.45).opacity(0.50),
                glowStrokeEnd: Color(red: 0.64, green: 0.49, blue: 0.28).opacity(0.50),
                tagText: Color(red: 0.96, green: 0.89, blue: 0.70),
                tagStroke: Color(red: 0.79, green: 0.64, blue: 0.39).opacity(0.48),
                badgeStart: Color(red: 0.90, green: 0.76, blue: 0.47),
                badgeEnd: Color(red: 0.69, green: 0.54, blue: 0.31)
            )
        case .ivoryGold:
            return DesignCardPalette(
                titleIcon: Color(red: 0.58, green: 0.47, blue: 0.27),
                titleText: Color(red: 0.43, green: 0.34, blue: 0.19),
                outerFillTop: Color(red: 0.94, green: 0.90, blue: 0.82),
                outerFillBottom: Color(red: 0.88, green: 0.81, blue: 0.66),
                outerStrokeStart: Color(red: 0.86, green: 0.72, blue: 0.43).opacity(0.96),
                outerStrokeEnd: Color(red: 0.67, green: 0.53, blue: 0.27).opacity(0.90),
                outerStroke: Color(red: 0.74, green: 0.60, blue: 0.32).opacity(0.95),
                thumbnailStrokeStart: Color(red: 0.88, green: 0.76, blue: 0.50),
                thumbnailStrokeEnd: Color(red: 0.73, green: 0.60, blue: 0.35),
                glowFillTop: Color(red: 0.98, green: 0.95, blue: 0.89),
                glowFillMid: Color(red: 0.94, green: 0.89, blue: 0.79),
                glowFillBottom: Color(red: 0.90, green: 0.83, blue: 0.68),
                glowStrokeStart: Color(red: 0.85, green: 0.71, blue: 0.42).opacity(0.50),
                glowStrokeEnd: Color(red: 0.66, green: 0.52, blue: 0.28).opacity(0.50),
                tagText: Color(red: 0.44, green: 0.34, blue: 0.19),
                tagStroke: Color(red: 0.74, green: 0.60, blue: 0.34).opacity(0.48),
                badgeStart: Color(red: 0.84, green: 0.70, blue: 0.40),
                badgeEnd: Color(red: 0.64, green: 0.50, blue: 0.27)
            )
        case .rainbow:
            let hue = rainbowHues[positiveModulo(variantIndex, rainbowHues.count)]
            return DesignCardPalette(
                titleIcon: Color(hue: hue, saturation: 0.54, brightness: 0.46),
                titleText: Color(hue: hue, saturation: 0.58, brightness: 0.30),
                outerFillTop: Color(hue: hue, saturation: 0.40, brightness: 0.94),
                outerFillBottom: Color(hue: hue, saturation: 0.55, brightness: 0.82),
                outerStrokeStart: Color(hue: hue, saturation: 0.78, brightness: 0.82).opacity(0.96),
                outerStrokeEnd: Color(hue: hue, saturation: 0.74, brightness: 0.54).opacity(0.90),
                outerStroke: Color(hue: hue, saturation: 0.74, brightness: 0.60).opacity(0.95),
                thumbnailStrokeStart: Color(hue: hue, saturation: 0.62, brightness: 0.88),
                thumbnailStrokeEnd: Color(hue: hue, saturation: 0.58, brightness: 0.74),
                glowFillTop: Color(hue: hue, saturation: 0.26, brightness: 0.98),
                glowFillMid: Color(hue: hue, saturation: 0.35, brightness: 0.94),
                glowFillBottom: Color(hue: hue, saturation: 0.42, brightness: 0.88),
                glowStrokeStart: Color(hue: hue, saturation: 0.58, brightness: 0.74).opacity(0.52),
                glowStrokeEnd: Color(hue: hue, saturation: 0.64, brightness: 0.60).opacity(0.52),
                tagText: Color(hue: hue, saturation: 0.56, brightness: 0.34),
                tagStroke: Color(hue: hue, saturation: 0.48, brightness: 0.64).opacity(0.48),
                badgeStart: Color(hue: hue, saturation: 0.76, brightness: 0.80),
                badgeEnd: Color(hue: hue, saturation: 0.72, brightness: 0.62)
            )
        }
    }

    static func itemCardPalette(for preset: ItemCardPreset, variantIndex: Int = 0) -> ItemCardPalette {
        let linkedPreset = linkedDesignPreset(for: preset)
        let base = designCardPalette(for: linkedPreset, variantIndex: variantIndex)
        return ItemCardPalette(
            fillTop: base.glowFillTop,
            fillBottom: base.glowFillBottom,
            outerFillTop: base.outerFillTop,
            outerFillBottom: base.outerFillBottom,
            outerStrokeStart: base.outerStrokeStart,
            outerStrokeEnd: base.outerStrokeEnd,
            outerStroke: base.outerStroke,
            strokeStart: base.glowStrokeStart,
            strokeEnd: base.glowStrokeEnd
        )
    }

    static var designCardPalette: DesignCardPalette {
        designCardPalette(for: designCardPreset)
    }

    static var itemCardPalette: ItemCardPalette {
        itemCardPalette(for: itemCardPreset)
    }

    static func aiScoreChartPalette(for preset: AIScoreChartPreset) -> AIScoreChartPalette {
        switch preset {
        case .freshGreen:
            return AIScoreChartPalette(
                haloInner: Color(red: 0.78, green: 0.95, blue: 0.84).opacity(0.22),
                haloMid: Color(red: 0.65, green: 0.86, blue: 0.74).opacity(0.12),
                gridOuter: Color(red: 0.38, green: 0.64, blue: 0.49).opacity(0.60),
                gridInner: Color(red: 0.50, green: 0.73, blue: 0.58).opacity(0.30),
                outerDash: Color(red: 0.44, green: 0.70, blue: 0.54).opacity(0.52),
                axis: Color(red: 0.52, green: 0.74, blue: 0.60).opacity(0.34),
                areaTop: Color(red: 0.38, green: 0.78, blue: 0.58).opacity(0.42),
                areaMid: Color(red: 0.36, green: 0.66, blue: 0.50).opacity(0.22),
                areaBottom: Color(red: 0.68, green: 0.90, blue: 0.78).opacity(0.14),
                lineStart: Color(red: 0.22, green: 0.66, blue: 0.45),
                lineEnd: Color(red: 0.27, green: 0.55, blue: 0.41),
                lineShadow: Color(red: 0.24, green: 0.64, blue: 0.44).opacity(0.35),
                pointGlow: Color(red: 0.64, green: 0.90, blue: 0.74).opacity(0.36),
                pointFill: Color(red: 0.95, green: 1.0, blue: 0.96).opacity(0.96),
                pointStroke: Color(red: 0.26, green: 0.68, blue: 0.46),
                centerFillStart: Color(red: 0.92, green: 0.99, blue: 0.94).opacity(0.96),
                centerFillEnd: Color(red: 0.84, green: 0.95, blue: 0.88).opacity(0.92),
                centerStrokeStart: Color(red: 0.34, green: 0.78, blue: 0.56),
                centerStrokeEnd: Color(red: 0.30, green: 0.62, blue: 0.45),
                centerScore: Color(red: 0.14, green: 0.50, blue: 0.31),
                centerTotal: Color(red: 0.27, green: 0.56, blue: 0.38),
                labelFill: Color(red: 0.91, green: 0.98, blue: 0.93).opacity(0.84),
                labelStroke: Color(red: 0.53, green: 0.77, blue: 0.61).opacity(0.58)
            )
        case .oceanBlue:
            return AIScoreChartPalette(
                haloInner: Color(red: 0.74, green: 0.88, blue: 1.0).opacity(0.24),
                haloMid: Color(red: 0.63, green: 0.80, blue: 0.98).opacity(0.14),
                gridOuter: Color(red: 0.32, green: 0.56, blue: 0.86).opacity(0.62),
                gridInner: Color(red: 0.44, green: 0.68, blue: 0.92).opacity(0.32),
                outerDash: Color(red: 0.40, green: 0.63, blue: 0.90).opacity(0.52),
                axis: Color(red: 0.48, green: 0.72, blue: 0.95).opacity(0.34),
                areaTop: Color(red: 0.34, green: 0.66, blue: 0.99).opacity(0.44),
                areaMid: Color(red: 0.30, green: 0.58, blue: 0.90).opacity(0.24),
                areaBottom: Color(red: 0.62, green: 0.82, blue: 0.99).opacity(0.16),
                lineStart: Color(red: 0.19, green: 0.53, blue: 0.92),
                lineEnd: Color(red: 0.18, green: 0.42, blue: 0.78),
                lineShadow: Color(red: 0.18, green: 0.47, blue: 0.84).opacity(0.35),
                pointGlow: Color(red: 0.62, green: 0.82, blue: 1.0).opacity(0.36),
                pointFill: Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.96),
                pointStroke: Color(red: 0.20, green: 0.56, blue: 0.92),
                centerFillStart: Color(red: 0.90, green: 0.96, blue: 1.0).opacity(0.96),
                centerFillEnd: Color(red: 0.82, green: 0.91, blue: 0.99).opacity(0.92),
                centerStrokeStart: Color(red: 0.30, green: 0.67, blue: 0.98),
                centerStrokeEnd: Color(red: 0.25, green: 0.52, blue: 0.86),
                centerScore: Color(red: 0.12, green: 0.38, blue: 0.72),
                centerTotal: Color(red: 0.22, green: 0.49, blue: 0.79),
                labelFill: Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.84),
                labelStroke: Color(red: 0.49, green: 0.70, blue: 0.94).opacity(0.58)
            )
        case .sunsetCoral:
            return AIScoreChartPalette(
                haloInner: Color(red: 1.0, green: 0.86, blue: 0.78).opacity(0.22),
                haloMid: Color(red: 0.99, green: 0.76, blue: 0.68).opacity(0.12),
                gridOuter: Color(red: 0.86, green: 0.45, blue: 0.36).opacity(0.60),
                gridInner: Color(red: 0.93, green: 0.57, blue: 0.48).opacity(0.30),
                outerDash: Color(red: 0.90, green: 0.54, blue: 0.44).opacity(0.52),
                axis: Color(red: 0.94, green: 0.64, blue: 0.55).opacity(0.34),
                areaTop: Color(red: 0.97, green: 0.50, blue: 0.39).opacity(0.42),
                areaMid: Color(red: 0.89, green: 0.44, blue: 0.35).opacity(0.22),
                areaBottom: Color(red: 1.0, green: 0.73, blue: 0.63).opacity(0.14),
                lineStart: Color(red: 0.89, green: 0.36, blue: 0.27),
                lineEnd: Color(red: 0.72, green: 0.29, blue: 0.22),
                lineShadow: Color(red: 0.82, green: 0.34, blue: 0.26).opacity(0.35),
                pointGlow: Color(red: 1.0, green: 0.74, blue: 0.66).opacity(0.36),
                pointFill: Color(red: 1.0, green: 0.97, blue: 0.95).opacity(0.96),
                pointStroke: Color(red: 0.90, green: 0.39, blue: 0.30),
                centerFillStart: Color(red: 1.0, green: 0.94, blue: 0.90).opacity(0.96),
                centerFillEnd: Color(red: 0.99, green: 0.86, blue: 0.80).opacity(0.92),
                centerStrokeStart: Color(red: 0.98, green: 0.55, blue: 0.43),
                centerStrokeEnd: Color(red: 0.82, green: 0.38, blue: 0.28),
                centerScore: Color(red: 0.64, green: 0.25, blue: 0.18),
                centerTotal: Color(red: 0.74, green: 0.34, blue: 0.25),
                labelFill: Color(red: 1.0, green: 0.93, blue: 0.89).opacity(0.84),
                labelStroke: Color(red: 0.91, green: 0.58, blue: 0.48).opacity(0.58)
            )
        case .violetSmoke:
            return AIScoreChartPalette(
                haloInner: Color(red: 0.88, green: 0.82, blue: 0.98).opacity(0.22),
                haloMid: Color(red: 0.78, green: 0.72, blue: 0.93).opacity(0.12),
                gridOuter: Color(red: 0.53, green: 0.43, blue: 0.74).opacity(0.60),
                gridInner: Color(red: 0.66, green: 0.56, blue: 0.84).opacity(0.30),
                outerDash: Color(red: 0.62, green: 0.52, blue: 0.82).opacity(0.52),
                axis: Color(red: 0.70, green: 0.62, blue: 0.88).opacity(0.34),
                areaTop: Color(red: 0.61, green: 0.49, blue: 0.88).opacity(0.42),
                areaMid: Color(red: 0.51, green: 0.41, blue: 0.76).opacity(0.22),
                areaBottom: Color(red: 0.81, green: 0.74, blue: 0.95).opacity(0.14),
                lineStart: Color(red: 0.45, green: 0.33, blue: 0.76),
                lineEnd: Color(red: 0.38, green: 0.27, blue: 0.62),
                lineShadow: Color(red: 0.43, green: 0.31, blue: 0.70).opacity(0.35),
                pointGlow: Color(red: 0.82, green: 0.75, blue: 0.96).opacity(0.36),
                pointFill: Color(red: 0.97, green: 0.95, blue: 1.0).opacity(0.96),
                pointStroke: Color(red: 0.49, green: 0.36, blue: 0.79),
                centerFillStart: Color(red: 0.95, green: 0.92, blue: 1.0).opacity(0.96),
                centerFillEnd: Color(red: 0.88, green: 0.82, blue: 0.98).opacity(0.92),
                centerStrokeStart: Color(red: 0.63, green: 0.52, blue: 0.90),
                centerStrokeEnd: Color(red: 0.48, green: 0.36, blue: 0.75),
                centerScore: Color(red: 0.29, green: 0.20, blue: 0.56),
                centerTotal: Color(red: 0.41, green: 0.30, blue: 0.66),
                labelFill: Color(red: 0.94, green: 0.91, blue: 0.99).opacity(0.84),
                labelStroke: Color(red: 0.68, green: 0.58, blue: 0.88).opacity(0.58)
            )
        case .amberOlive:
            return AIScoreChartPalette(
                haloInner: Color(red: 0.96, green: 0.90, blue: 0.72).opacity(0.22),
                haloMid: Color(red: 0.90, green: 0.82, blue: 0.60).opacity(0.12),
                gridOuter: Color(red: 0.65, green: 0.56, blue: 0.29).opacity(0.60),
                gridInner: Color(red: 0.74, green: 0.66, blue: 0.38).opacity(0.30),
                outerDash: Color(red: 0.68, green: 0.61, blue: 0.33).opacity(0.52),
                axis: Color(red: 0.78, green: 0.71, blue: 0.42).opacity(0.34),
                areaTop: Color(red: 0.78, green: 0.66, blue: 0.30).opacity(0.42),
                areaMid: Color(red: 0.66, green: 0.55, blue: 0.25).opacity(0.22),
                areaBottom: Color(red: 0.90, green: 0.84, blue: 0.56).opacity(0.14),
                lineStart: Color(red: 0.56, green: 0.46, blue: 0.18),
                lineEnd: Color(red: 0.46, green: 0.38, blue: 0.15),
                lineShadow: Color(red: 0.50, green: 0.42, blue: 0.16).opacity(0.35),
                pointGlow: Color(red: 0.89, green: 0.82, blue: 0.53).opacity(0.36),
                pointFill: Color(red: 1.0, green: 0.98, blue: 0.93).opacity(0.96),
                pointStroke: Color(red: 0.61, green: 0.51, blue: 0.21),
                centerFillStart: Color(red: 0.99, green: 0.96, blue: 0.87).opacity(0.96),
                centerFillEnd: Color(red: 0.95, green: 0.89, blue: 0.72).opacity(0.92),
                centerStrokeStart: Color(red: 0.81, green: 0.69, blue: 0.34),
                centerStrokeEnd: Color(red: 0.62, green: 0.51, blue: 0.24),
                centerScore: Color(red: 0.39, green: 0.31, blue: 0.10),
                centerTotal: Color(red: 0.50, green: 0.41, blue: 0.17),
                labelFill: Color(red: 0.98, green: 0.94, blue: 0.84).opacity(0.84),
                labelStroke: Color(red: 0.75, green: 0.66, blue: 0.36).opacity(0.58)
            )
        }
    }

    static var aiScoreChartPalette: AIScoreChartPalette {
        aiScoreChartPalette(for: aiChartPreset)
    }

    private static let rainbowHues: [Double] = [
        0.00, // red
        0.08, // orange
        0.15, // yellow
        0.33, // green
        0.50, // cyan
        0.62, // blue
        0.78  // purple
    ]

    private static func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        guard divisor != 0 else { return 0 }
        let remainder = value % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private static func linkedDesignPreset(for preset: ItemCardPreset) -> DesignCardPreset {
        switch preset {
        case .roseChampagne: return .roseChampagne
        case .mauveBronze: return .mauveBronze
        case .sageGold: return .sageGold
        case .slateBlueSilver: return .slateBlueSilver
        case .terracottaCream: return .terracottaCream
        case .noirSilver: return .noirSilver
        case .noirGold: return .noirGold
        case .ivoryGold: return .ivoryGold
        case .rainbow: return .rainbow
        }
    }
}
