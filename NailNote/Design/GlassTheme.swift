import SwiftUI

/// Glassmorphism用の共通カラーテーマ
struct GlassTheme {
    /// 背景グラデーション（青紫〜ミント）で白飛びを抑制
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.83, blue: 0.94),
                Color(red: 0.78, green: 0.86, blue: 0.99),
                Color(red: 0.72, green: 0.94, blue: 0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// オーブ（光）に使う色
    static var orbColors: [Color] {
        [
            Color(red: 1.00, green: 0.67, blue: 0.82).opacity(0.35),
            Color(red: 0.58, green: 0.78, blue: 0.99).opacity(0.32),
            Color(red: 0.64, green: 0.95, blue: 0.79).opacity(0.30)
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
}
