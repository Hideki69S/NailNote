import SwiftUI

/// 画面全体に敷くカラフルなガラス風背景
struct GlassBackgroundView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            GlassTheme.backgroundGradient
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack {
                    orb(size: proxy.size, scale: 0.55, offset: CGPoint(x: -0.25, y: -0.2), colorIndex: 0)
                    orb(size: proxy.size, scale: 0.45, offset: CGPoint(x: 0.40, y: -0.35), colorIndex: 1)
                    orb(size: proxy.size, scale: 0.60, offset: CGPoint(x: 0.35, y: 0.45), colorIndex: 2)
                }
                .allowsHitTesting(false)
            }

            content
        }
    }

    private func orb(size: CGSize, scale: CGFloat, offset: CGPoint, colorIndex: Int) -> some View {
        let diameter = min(size.width, size.height) * scale
        let color = GlassTheme.orbColors[colorIndex % GlassTheme.orbColors.count]
        return Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .blur(radius: diameter * 0.18)
            .offset(x: size.width * offset.x, y: size.height * offset.y)
    }
}
