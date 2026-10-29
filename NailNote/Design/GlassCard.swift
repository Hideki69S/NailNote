import SwiftUI
import UIKit

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

/// デザイン・用品で、素材・配色・操作面・余白を共有する追加ボタン。
struct NailFloatingAddButton: View {
    @AppStorage(GlassTheme.Keys.designCardPreset) private var presetRaw = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    private var customPalette: GlassTheme.DesignCardPalette? {
        guard let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.addButton), choice.changesColor else { return nil }
        return NailAppearance.designPalette(GlassTheme.designCardPalette(for: .roseChampagne), choice: choice)
    }

    // 標準時は採用済みのデザイン側の配色を基準にし、画面別の色に引きずられない。
    private var palette: GlassTheme.DesignCardPalette {
        GlassTheme.designCardPalette(for: GlassTheme.DesignCardPreset(rawValue: presetRaw) ?? .roseChampagne)
    }
    let accessibilityLabel: String
    var action: () -> Void

    private var symbolColor: Color {
        let luminances = [palette.outerStrokeStart, palette.outerStrokeEnd].map { color -> Double in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ component: CGFloat) -> Double {
                let value = Double(component)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let whiteContrast = 1.05 / ((luminances.max() ?? 0) + 0.05)
        let blackContrast = ((luminances.min() ?? 1) + 0.05) / 0.05
        return whiteContrast >= blackContrast ? .white : .black
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(customPalette?.titleText ?? symbolColor)
                .frame(width: 58, height: 58)
                .contentShape(Rectangle())
                .background(
                    Circle()
                        .fill(LinearGradient(colors: customPalette.map { [$0.glowFillTop, $0.glowFillBottom] } ?? [palette.outerStrokeStart, palette.outerStrokeEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.8), palette.outerStrokeEnd], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                        .overlay(Circle().inset(by: 2).strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.18), radius: 9, x: 0, y: 5)
                )
        }
        .buttonStyle(NailFloatingAddButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .padding(.bottom, 24)
        .padding(.trailing, 24)
    }
}


/// 周囲のButtonStyleに左右されず、両画面で同じ控えめな押下表現にする。
private struct NailFloatingAddButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
