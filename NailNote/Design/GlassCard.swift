import SwiftUI

/// Glassmorphism風カード。文字が白飛びしないよう前景色を制御。
struct GlassCard<Content: View>: View {
    let content: Content
    let maxWidth: CGFloat?

    init(maxWidth: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.maxWidth = maxWidth
    }

    var body: some View {
        content
            .foregroundStyle(.primary)
            .padding(16)
            .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
                    .stroke(GlassTheme.cardStrokeColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous))
            .shadow(color: GlassTheme.cardShadowColor, radius: 12, x: 0, y: 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .background(GlassTheme.cardFillGradient)
            .overlay(
                GlassTheme.cardFillGradient
                    .opacity(0.35)
            )
    }
}
