import SwiftUI

/// Glassmorphism風カード。文字が白飛びしないよう前景色を制御。
struct GlassCard<Content: View>: View {
    let content: Content
    let maxWidth: CGFloat?
    let contentPadding: CGFloat
    let strokeColor: Color
    let strokeGradient: LinearGradient?
    let customBackgroundGradient: LinearGradient?

    init(
        maxWidth: CGFloat? = nil,
        contentPadding: CGFloat = 16,
        strokeColor: Color = GlassTheme.cardStrokeColor,
        strokeGradient: LinearGradient? = nil,
        backgroundGradient: LinearGradient? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.maxWidth = maxWidth
        self.contentPadding = contentPadding
        self.strokeColor = strokeColor
        self.strokeGradient = strokeGradient
        self.customBackgroundGradient = backgroundGradient
    }

    var body: some View {
        content
            .foregroundStyle(.primary)
            .padding(contentPadding)
            .frame(maxWidth: maxWidth ?? .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
                    .stroke(strokeGradient ?? defaultStrokeGradient, lineWidth: 1.25)
            )
            .clipShape(RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous))
            .shadow(color: GlassTheme.cardShadowColor, radius: 12, x: 0, y: 8)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if let customBackgroundGradient {
            RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
                .fill(customBackgroundGradient)
                .overlay(customBackgroundGradient.opacity(0.22))
        } else {
            RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius, style: .continuous)
                .fill(.regularMaterial)
                .background(GlassTheme.cardFillGradient)
                .overlay(
                    GlassTheme.cardFillGradient
                        .opacity(0.35)
                )
        }
    }

    private var defaultStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [strokeColor.opacity(0.95), strokeColor.opacity(0.55)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
