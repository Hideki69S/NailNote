import SwiftUI

/// 星評価を表示する汎用ビュー（0.5刻み）。食べログ風。
struct StarRatingView: View {
    var rating: Double
    var maxRating: Int = 5
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Image(systemName: imageName(for: Double(index)))
                    .font(.system(size: size))
                    .foregroundStyle(Color.accentColor)
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
