import SwiftUI
import CoreGraphics
import UIKit

private struct NailDesignBackgroundCanvasKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    // 保存設定ではなく、試作タブバーの上下で共有する背景の描画領域。
    var nailDesignBackgroundCanvas: CGRect? {
        get { self[NailDesignBackgroundCanvasKey.self] }
        set { self[NailDesignBackgroundCanvasKey.self] = newValue }
    }
}

/// 画面全体に敷くカラフルなガラス風背景
struct GlassBackgroundView<Content: View>: View {
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundPresetRaw: String = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @Environment(\.nailDesignBackgroundCanvas) private var designCanvas
    let content: Content
    let refined: Bool
    let appearanceArea: NailAppearance.Area?
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""

    init(refined: Bool = false, appearanceArea: NailAppearance.Area? = nil, @ViewBuilder content: () -> Content) {
        self.refined = refined
        self.appearanceArea = appearanceArea
        self.content = content()
    }

    var body: some View {
        let preset = GlassTheme.BackgroundPreset(rawValue: backgroundPresetRaw) ?? .smokySageChampagne
        let orbColors = GlassTheme.orbColors(for: preset)
        let choice = appearanceArea.flatMap { NailAppearance.Document.decode(appearanceRaw).resolved($0) }

        ZStack {
            if let canvas = designCanvas, refined, appearanceArea == .design {
                // NavigationStack内の背景を保ちつつ、下部背景と同じ切り抜き位置に揃える。
                GeometryReader { proxy in
                    NailAppearanceBackground(choice: choice ?? .init(), preset: preset)
                        .frame(width: canvas.width, height: canvas.height)
                        .offset(x: canvas.minX - proxy.frame(in: .global).minX,
                                y: canvas.minY - proxy.frame(in: .global).minY)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            } else if let choice, choice.changesColor || choice.background != nil {
                customizedBackground(choice, preset: preset)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                GlassTheme.backgroundGradient(for: preset)
                    .ignoresSafeArea()

                if refined {
                    silkBackground(isDark: preset == .noirSilver || preset == .noirGold)
                        .ignoresSafeArea()
                } else {
                    GeometryReader { proxy in
                        ZStack {
                            orb(size: proxy.size, scale: 0.55, offset: CGPoint(x: -0.25, y: -0.2), colorIndex: 0, orbColors: orbColors)
                            orb(size: proxy.size, scale: 0.45, offset: CGPoint(x: 0.40, y: -0.35), colorIndex: 1, orbColors: orbColors)
                            orb(size: proxy.size, scale: 0.60, offset: CGPoint(x: 0.35, y: 0.45), colorIndex: 2, orbColors: orbColors)
                        }
                        .allowsHitTesting(false)
                    }
                }
            }

            content
        }
    }

    private func customizedBackground(_ choice: NailAppearance.Choice, preset: GlassTheme.BackgroundPreset) -> some View {
        NailAppearanceBackground(choice: choice, preset: preset)
    }

    private func silkBackground(isDark: Bool) -> some View {
        RefinedSilkLayer(isDark: isDark)
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

/// 実画面と下書きプレビューが共有する背景スタイル。操作・情報レイヤーは含まない。
struct NailAppearanceBackground: View {
    let choice: NailAppearance.Choice
    let preset: GlassTheme.BackgroundPreset

    var body: some View {
        let palette = NailAppearance.designPalette(preset.refinedSurfacePalette, choice: choice)
        let colors = choice.changesColor
            ? [palette.glowFillTop, palette.glowFillMid, palette.glowFillBottom]
            : GlassTheme.backgroundColors(for: preset)
        let dark = choice.changesColor ? choice.dark : (preset == .noirGold || preset == .noirSilver)
        ZStack {
            if choice.background == .solid {
                colors[colors.count / 2]
            } else {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                switch choice.background ?? .silk {
                case .silk: RefinedSilkLayer(isDark: dark)
                case .satin: RefinedSatinLayer(isDark: dark, strength: 0.9, surface: .satinBackground)
                case .gradient, .solid: EmptyView()
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 既存の布素材はSilkだけへ合成し、他スタイルへ重ねない。
private struct RefinedSilkLayer: View {
    let isDark: Bool
    var body: some View {
        if UIImage(named: "RefinedSilkLuminance") != nil {
            GeometryReader { proxy in
                Image("RefinedSilkLuminance")
                    .resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .blendMode(.softLight)
            .opacity(isDark ? 0.38 : 0.72)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        } else {
            RefinedSatinLayer(isDark: isDark)
        }
    }
}

/// 曲面の法線から求めた静止反射。内容の配置やタップ領域は持たない。
struct RefinedSatinLayer: View {
    let isDark: Bool
    var strength: Double = 1
    var surface: SatinReliefRenderer.Surface = .fabric

    var body: some View {
        Canvas { context, size in
            if let image = SatinReliefRenderer.image(size: size, surface: surface, isDark: isDark) {
                context.draw(Image(decorative: image, scale: 1), in: CGRect(origin: .zero, size: size))
            }
        }
        .opacity(strength)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// 布の曲線断面を高さ場へ重ね、拡散反射・異方性の弱い反射・谷の遮蔽を計算する。
/// 元のテーマ色へ無彩色の光と影だけを合成するため、設定色は置き換えない。
enum SatinReliefRenderer {
    enum Surface: String { case fabric, glass, tab, satinBackground }

    private struct Fold {
        let base: Double
        let slope: Double
        let bend: Double
        let width: Double
        let height: Double
    }

    private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()

    static func image(size: CGSize, surface: Surface, isDark: Bool) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        // 広い曲面は低周波なので画面幅を上限とし、カードごとの高解像度再生成を避ける。
        let width = max(64, min(384, Int(size.width.rounded())))
        let height = max(32, min(1024, Int((Double(width) * size.height / size.width).rounded())))
        let key = "\(surface.rawValue)-\(width)-\(height)-\(isDark)" as NSString
        if let image = cache.object(forKey: key) { return image }
        let folds: [Fold]
        switch surface {
        case .fabric:
            folds = [Fold(base: -0.03, slope: 0.36, bend: -0.34, width: 0.025, height: 0.018),
                     Fold(base: 0.11, slope: 0.45, bend: -0.38, width: 0.055, height: 0.045),
                     Fold(base: 0.49, slope: -0.52, bend: 0.24, width: 0.045, height: 0.050),
                     Fold(base: 0.40, slope: -0.52, bend: 0.24, width: 0.025, height: 0.014),
                     Fold(base: 0.70, slope: 0.42, bend: -0.36, width: 0.075, height: 0.065),
                     Fold(base: 1.12, slope: -0.58, bend: 0.12, width: 0.045, height: 0.045),
                     Fold(base: 0.93, slope: -0.20, bend: -0.32, width: 0.025, height: 0.018)]
        case .glass:
            folds = [Fold(base: 0.93, slope: -1.20, bend: 0.28, width: 0.14, height: 0.075),
                     Fold(base: 1.28, slope: -0.58, bend: -0.12, width: 0.21, height: 0.055)]
        case .tab:
            folds = [Fold(base: 0.27, slope: 0.54, bend: -0.32, width: 0.24, height: 0.09),
                     Fold(base: 1.05, slope: -0.75, bend: 0.15, width: 0.20, height: 0.065)]
        case .satinBackground:
            // カード用の文字領域減衰を使わず、背景全体へ広いサテンの起伏を描く。
            folds = [Fold(base: 0.13, slope: 0.33, bend: -0.16, width: 0.09, height: 0.08),
                     Fold(base: 0.52, slope: -0.33, bend: 0.17, width: 0.13, height: 0.10),
                     Fold(base: 0.87, slope: 0.22, bend: -0.15, width: 0.17, height: 0.06)]
        }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let v = Double(y) / Double(max(1, height - 1))
            for x in 0..<width {
                let u = Double(x) / Double(max(1, width - 1))
                var dx = 0.0, dy = 0.0, valley = 0.0, crest = 0.0
                for fold in folds {
                    let center = fold.base + fold.slope * u + fold.bend * u * u
                    let q = (v - center) / fold.width
                    let ridge = fold.height * exp(-0.5 * q * q)
                    let derivative = ridge * q / fold.width
                    dx += derivative * (fold.slope + 2 * fold.bend * u)
                    dy -= derivative
                    valley += exp(-0.5 * pow((q - 1.6) / 0.85, 2)) * 0.035
                    crest += exp(-0.5 * pow((q + 0.32) / 0.22, 2)) * (surface == .fabric ? 0.24 : 0.16)
                }
                // 縦横比を補正して光源を揃え、サイズが違っても反射の向きを保つ。
                let nx = -dx * min(2.2, Double(height) / Double(width))
                let ny = -dy
                let inverseLength = 1 / sqrt(nx * nx + ny * ny + 1)
                let diffuse = (nx * -0.44 + ny * -0.55 + 0.71) * inverseLength
                let halfDot = max(0, (nx * -0.24 + ny * -0.30 + 0.923) * inverseLength)
                let specular = pow(halfDot, 18) - pow(0.923, 18)
                var response = (diffuse - 0.71) * 0.72 + specular * 0.22 + crest - valley
                if surface == .fabric {
                    // 粒ではなく連続したごく弱い繊維反射。発光・乱数・動きは加えない。
                    response += sin(u * 310 + sin(v * 12) * 4) * 0.004 * max(0, diffuse)
                } else if surface != .satinBackground {
                    // 右側中央の文字領域に強い反射を置かない。
                    let readingArea = exp(-pow((u - 0.72) / 0.40, 2) - pow((v - 0.48) / 0.32, 2))
                    response *= (surface == .glass ? 0.85 : 0.70) * (1 - readingArea * 0.75)
                }
                let limit = response >= 0 ? (isDark ? 0.24 : (surface == .glass ? 0.30 : 0.46)) : (isDark ? 0.22 : (surface == .glass ? 0.09 : 0.16))
                let shadowGain = surface == .satinBackground ? 0.60 : (isDark ? 0.35 : 0.22)
                let opacity = min(limit, abs(response) * (response >= 0 ? (isDark ? 0.50 : 1.35) : shadowGain))
                let alpha = UInt8((opacity * 255).rounded())
                let index = (y * width + x) * 4
                let component: UInt8 = response >= 0 ? alpha : 0
                pixels[index] = component
                pixels[index + 1] = component
                pixels[index + 2] = component
                pixels[index + 3] = alpha
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        cache.setObject(image, forKey: key, cost: width * height * 4)
        return image
    }
}
