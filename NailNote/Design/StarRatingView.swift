import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// 星評価を表示する汎用ビュー（0.5刻み）。食べログ風。
struct StarRatingView: View {
    var rating: Double
    var maxRating: Int = 5
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                let value = Double(index)
                Image(systemName: imageName(for: value))
                    .font(.system(size: size))
                    .foregroundStyle(gradient(for: value / Double(maxRating)))
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

    private func gradient(for position: Double) -> LinearGradient {
        let clamped = max(0, min(1, position))
        let start = Color(red: 1.00, green: 0.45, blue: 0.70) // 濃いピンク
        let mid = Color(red: 0.98, green: 0.70, blue: 0.25)   // ゴールド
        let end = Color(red: 0.85, green: 0.50, blue: 0.08)   // ディープアンバー

        let colors: [Color]
        if clamped < 0.5 {
            let t = clamped / 0.5
            colors = [start, start.blend(with: mid, amount: t)]
        } else {
            let t = (clamped - 0.5) / 0.5
            colors = [mid, mid.blend(with: end, amount: t)]
        }

        return LinearGradient(colors: colors,
                              startPoint: .topLeading,
                              endPoint: .bottomTrailing)
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

private extension Color {
    func blend(with other: Color, amount: Double) -> Color {
        #if canImport(UIKit)
        let clamp = max(0, min(1, amount))
        let uiSelf = UIColor(self)
        let uiOther = UIColor(other)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiSelf.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiOther.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return Color(red: Double(r1 + (r2 - r1) * clamp),
                     green: Double(g1 + (g2 - g1) * clamp),
                     blue: Double(b1 + (b2 - b1) * clamp),
                     opacity: Double(a1 + (a2 - a1) * clamp))
        #else
        return self
        #endif
    }
}
