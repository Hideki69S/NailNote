import SwiftUI

/// 画面全体に敷くカラフルなガラス風背景
struct GlassBackgroundView<Content: View>: View {
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundPresetRaw: String = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let preset = GlassTheme.BackgroundPreset(rawValue: backgroundPresetRaw) ?? .smokySageChampagne
        let orbColors = GlassTheme.orbColors(for: preset)

        ZStack {
            GlassTheme.backgroundGradient(for: preset)
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    orb(size: proxy.size, scale: 0.55, offset: CGPoint(x: -0.25, y: -0.2), colorIndex: 0, orbColors: orbColors)
                    orb(size: proxy.size, scale: 0.45, offset: CGPoint(x: 0.40, y: -0.35), colorIndex: 1, orbColors: orbColors)
                    orb(size: proxy.size, scale: 0.60, offset: CGPoint(x: 0.35, y: 0.45), colorIndex: 2, orbColors: orbColors)
                }
                .allowsHitTesting(false)
            }

            content
        }
    }

    private func orb(size: CGSize, scale: CGFloat, offset: CGPoint, colorIndex: Int, orbColors: [Color]) -> some View {
        let diameter = min(size.width, size.height) * scale
        let color = orbColors[colorIndex % orbColors.count]
        return Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.18)
            .offset(x: size.width * offset.x, y: size.height * offset.y)
    }
}
