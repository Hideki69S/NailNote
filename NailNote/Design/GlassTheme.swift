import SwiftUI

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

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .smokySageChampagne: return "スモーキーセージ"
            case .stoneRose: return "ストーンローズ"
            case .mistBlueTaupe: return "ミストブルー"
            case .graphiteMint: return "グラファイトミント"
            case .ivoryCoral: return "アイボリーコーラル"
            }
        }
    }

    enum DesignCardPreset: String, CaseIterable, Identifiable {
        case roseChampagne
        case mauveBronze
        case sageGold
        case slateBlueSilver
        case terracottaCream

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .roseChampagne: return "ローズシャンパン"
            case .mauveBronze: return "モーブブロンズ"
            case .sageGold: return "セージゴールド"
            case .slateBlueSilver: return "スレートブルー"
            case .terracottaCream: return "テラコッタクリーム"
            }
        }
    }

    enum ItemCardPreset: String, CaseIterable, Identifiable {
        case mintStone
        case blueGray
        case warmBeige
        case oliveClay
        case plumSmoke

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .mintStone: return "ミントストーン"
            case .blueGray: return "ブルーグレー"
            case .warmBeige: return "ウォームベージュ"
            case .oliveClay: return "オリーブクレイ"
            case .plumSmoke: return "プラムスモーク"
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
        return ItemCardPreset(rawValue: raw ?? "") ?? .mintStone
    }

    private static var aiChartPreset: AIScoreChartPreset {
        let raw = UserDefaults.standard.string(forKey: Keys.aiChartPreset)
        return AIScoreChartPreset(rawValue: raw ?? "") ?? .freshGreen
    }

    /// 背景グラデーション（スモーキーセージ〜シャンパン）
    static func backgroundGradient(for preset: BackgroundPreset) -> LinearGradient {
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
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
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

    static func designCardPalette(for preset: DesignCardPreset) -> DesignCardPalette {
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
        }
    }

    static func itemCardPalette(for preset: ItemCardPreset) -> ItemCardPalette {
        switch preset {
        case .mintStone:
            return ItemCardPalette(
                fillTop: Color(red: 0.95, green: 0.98, blue: 0.95),
                fillBottom: Color(red: 0.90, green: 0.95, blue: 0.90),
                outerFillTop: Color(red: 0.84, green: 0.91, blue: 0.84),
                outerFillBottom: Color(red: 0.75, green: 0.85, blue: 0.75),
                outerStrokeStart: Color(red: 0.47, green: 0.66, blue: 0.50).opacity(0.96),
                outerStrokeEnd: Color(red: 0.29, green: 0.46, blue: 0.31).opacity(0.90),
                outerStroke: Color(red: 0.34, green: 0.53, blue: 0.36).opacity(0.95),
                strokeStart: Color(red: 0.64, green: 0.79, blue: 0.66).opacity(0.48),
                strokeEnd: Color(red: 0.78, green: 0.86, blue: 0.70).opacity(0.48)
            )
        case .blueGray:
            return ItemCardPalette(
                fillTop: Color(red: 0.94, green: 0.96, blue: 0.98),
                fillBottom: Color(red: 0.88, green: 0.92, blue: 0.96),
                outerFillTop: Color(red: 0.82, green: 0.87, blue: 0.93),
                outerFillBottom: Color(red: 0.72, green: 0.80, blue: 0.89),
                outerStrokeStart: Color(red: 0.45, green: 0.62, blue: 0.82).opacity(0.96),
                outerStrokeEnd: Color(red: 0.25, green: 0.39, blue: 0.58).opacity(0.90),
                outerStroke: Color(red: 0.34, green: 0.47, blue: 0.64).opacity(0.95),
                strokeStart: Color(red: 0.59, green: 0.68, blue: 0.82).opacity(0.48),
                strokeEnd: Color(red: 0.69, green: 0.77, blue: 0.89).opacity(0.48)
            )
        case .warmBeige:
            return ItemCardPalette(
                fillTop: Color(red: 0.98, green: 0.95, blue: 0.91),
                fillBottom: Color(red: 0.94, green: 0.90, blue: 0.84),
                outerFillTop: Color(red: 0.91, green: 0.84, blue: 0.76),
                outerFillBottom: Color(red: 0.84, green: 0.76, blue: 0.66),
                outerStrokeStart: Color(red: 0.75, green: 0.58, blue: 0.42).opacity(0.96),
                outerStrokeEnd: Color(red: 0.52, green: 0.38, blue: 0.27).opacity(0.90),
                outerStroke: Color(red: 0.58, green: 0.45, blue: 0.33).opacity(0.95),
                strokeStart: Color(red: 0.78, green: 0.67, blue: 0.56).opacity(0.48),
                strokeEnd: Color(red: 0.88, green: 0.77, blue: 0.64).opacity(0.48)
            )
        case .oliveClay:
            return ItemCardPalette(
                fillTop: Color(red: 0.93, green: 0.94, blue: 0.86),
                fillBottom: Color(red: 0.88, green: 0.89, blue: 0.79),
                outerFillTop: Color(red: 0.84, green: 0.85, blue: 0.72),
                outerFillBottom: Color(red: 0.76, green: 0.77, blue: 0.64),
                outerStrokeStart: Color(red: 0.64, green: 0.67, blue: 0.40).opacity(0.96),
                outerStrokeEnd: Color(red: 0.40, green: 0.42, blue: 0.24).opacity(0.90),
                outerStroke: Color(red: 0.49, green: 0.51, blue: 0.31).opacity(0.95),
                strokeStart: Color(red: 0.66, green: 0.67, blue: 0.47).opacity(0.48),
                strokeEnd: Color(red: 0.76, green: 0.78, blue: 0.56).opacity(0.48)
            )
        case .plumSmoke:
            return ItemCardPalette(
                fillTop: Color(red: 0.93, green: 0.90, blue: 0.95),
                fillBottom: Color(red: 0.88, green: 0.84, blue: 0.91),
                outerFillTop: Color(red: 0.84, green: 0.78, blue: 0.88),
                outerFillBottom: Color(red: 0.76, green: 0.70, blue: 0.81),
                outerStrokeStart: Color(red: 0.61, green: 0.46, blue: 0.72).opacity(0.96),
                outerStrokeEnd: Color(red: 0.38, green: 0.27, blue: 0.49).opacity(0.90),
                outerStroke: Color(red: 0.47, green: 0.34, blue: 0.54).opacity(0.95),
                strokeStart: Color(red: 0.64, green: 0.53, blue: 0.72).opacity(0.48),
                strokeEnd: Color(red: 0.74, green: 0.63, blue: 0.80).opacity(0.48)
            )
        }
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
}
