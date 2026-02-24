import SwiftUI

/// Glassmorphism用の共通カラーテーマ
struct GlassTheme {
    /// 背景グラデーション（スモーキーセージ〜シャンパン）
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.97, blue: 0.94),
                Color(red: 0.90, green: 0.94, blue: 0.89),
                Color(red: 0.97, green: 0.92, blue: 0.84)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// オーブ（光）に使う色
    static var orbColors: [Color] {
        [
            Color(red: 0.79, green: 0.89, blue: 0.77).opacity(0.30),
            Color(red: 0.94, green: 0.86, blue: 0.76).opacity(0.28),
            Color(red: 0.86, green: 0.93, blue: 0.84).opacity(0.26)
        ]
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
    static var cardCornerRadius: CGFloat { 22 }

    /// 記録/用品カードの固定幅（iPhoneでも余白が残る程度）
    static let listCardWidth: CGFloat = 360
}
