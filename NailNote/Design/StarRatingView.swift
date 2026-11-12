import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 星評価を表示する汎用ビュー（0.5刻み）。食べログ風。
struct StarRatingView: View {
    var rating: Double
    var maxRating: Int = 5
    var size: CGFloat = 16
    @AppStorage(GlassTheme.Keys.designCardPreset) private var presetRaw = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    private var palette: GlassTheme.DesignCardPalette {
        NailAppearance.designPalette(GlassTheme.designCardPalette(for: GlassTheme.DesignCardPreset(rawValue: presetRaw) ?? .roseChampagne),
                                     choice: NailAppearance.Document.decode(appearanceRaw).resolved(.design))
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                let value = Double(index)
                Image(systemName: imageName(for: value))
                    .font(.system(size: size))
                    .foregroundStyle(NailRatingStarStyle.gradient(at: index))
                    .shadow(color: NailRatingStarStyle.edge(on: [palette.glowFillTop, palette.glowFillMid, palette.glowFillBottom]).opacity(NailRatingStarStyle.shadowOpacity),
                            radius: NailRatingStarStyle.shadowRadius, x: 0, y: 0)
            }
        }
        .accessibilityLabel("評価 \(String(format: "%.1f", rating))")
    }

    private func imageName(for value: Double) -> String {
        if rating >= value {
            return "star.fill"
        } else if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }


}

/// 星評価を操作できる入力ビュー（Slider + 星表示）。
struct StarRatingInputView: View {
    @Binding var rating: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StarRatingView(rating: rating, size: 18)
                Text(String(format: "%.1f", rating))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $rating, in: 0...5, step: 0.5)
                .tint(.accentColor)
        }
    }
}

// 一覧・追加・編集が共有する星の配色と表面表現。評価値は参照しない。
enum NailRatingStarStyle {
    static let shadowOpacity = 0.55
    static let shadowRadius: CGFloat = 0.35
    static func colors(at index: Int) -> [Color] {
        let colors = [Color(red: 0.98, green: 0.88, blue: 0.50),
                      Color(red: 0.91, green: 0.68, blue: 0.23),
                      Color(red: 0.92, green: 0.64, blue: 0.60),
                      Color(red: 0.94, green: 0.43, blue: 0.65),
                      Color(red: 0.75, green: 0.20, blue: 0.47)]
        let color = colors[min(4, max(0, index - 1))]
        return [mix(color, .white, 0.28), mix(color, .black, 0.06)]
    }

    private static func mix(_ first: Color, _ second: Color, _ fraction: Double) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        var x: CGFloat = 0, y: CGFloat = 0, z: CGFloat = 0, w: CGFloat = 0
        UIColor(first).getRed(&r, green: &g, blue: &b, alpha: &a)
        UIColor(second).getRed(&x, green: &y, blue: &z, alpha: &w)
        return Color(red: Double(r) + Double(x - r) * fraction,
                     green: Double(g) + Double(y - g) * fraction,
                     blue: Double(b) + Double(z - b) * fraction)
    }

    static func gradient(at index: Int) -> LinearGradient {
        LinearGradient(colors: colors(at: index), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func edge(on backgrounds: [Color]) -> Color {
        let surfaces = backgrounds.map { luminance($0) }
        return minimumContrast(.white, surfaces: surfaces) > minimumContrast(.black, surfaces: surfaces) ? .white : .black
    }

    private static func minimumContrast(_ color: Color, surfaces: [Double]) -> Double {
        let foreground = luminance(color)
        return surfaces.map { (max(foreground, $0) + 0.05) / (min(foreground, $0) + 0.05) }.min() ?? 1
    }

    private static func luminance(_ color: Color) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ value: CGFloat) -> Double {
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
