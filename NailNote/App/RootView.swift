import SwiftUI
import UIKit

enum NailNoteFeatureFlags {
    // AI評価は再開承認まで、ビルド構成やAPIキーにかかわらず停止する。
    static let aiEvaluationEnabled = false
}

struct RootView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 記録（Entries）
            EntryListView()
                .tabItem {
                    LuxuryTabLabel(kind: .design)
                }
                .tag(0)

            // 用品（Products）
            ProductListView()
                .tabItem {
                    LuxuryTabLabel(kind: .items)
                }
                .tag(1)

            // AIネイルスコア
            if NailNoteFeatureFlags.aiEvaluationEnabled {
                SimHomeView()
                    .tabItem {
                        Label("AI", systemImage: "pencil.and.outline")
                    }
                    .tag(3)
            }

            // 設定（Settings）
            SettingsView()
                .tabItem {
                    LuxuryTabLabel(kind: .settings)
                }
                .tag(2)
        }
        .toolbarBackground(.visible, for: .tabBar)
        .background {
            RefinedTabBarStyle(selectedTab: selectedTab)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct LuxuryTabLabel: View {
    let kind: LuxuryTabArtwork.Kind
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var presetRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @Environment(\.displayScale) private var scale

    var body: some View {
        let preset = GlassTheme.BackgroundPreset(rawValue: presetRaw) ?? .smokySageChampagne
        Label {
            Text(kind.title)
        } icon: {
            Image(uiImage: LuxuryTabArtwork.icon(kind: kind, preset: preset, selected: false, scale: scale))
                .renderingMode(.original)
                .accessibilityHidden(true)
        }
    }
}

/// パスを表示解像度で描く。PNGの拡大や参照画像の切り抜きは使わない。
private enum LuxuryTabArtwork {
    enum Kind: Int, CaseIterable {
        case design, items, settings
        var title: String {
            switch self {
            case .design: return "デザイン"
            case .items: return "アイテム"
            case .settings: return "設定"
            }
        }
    }

    private static let icons = NSCache<NSString, UIImage>()

    static func icon(kind: Kind, preset: GlassTheme.BackgroundPreset, selected: Bool, scale: CGFloat) -> UIImage {
        let key = "\(kind.rawValue)-\(preset.rawValue)-\(selected)-\(scale)" as NSString
        if let image = icons.object(forKey: key) { return image }
        let palette = preset.refinedSurfacePalette
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(1, scale)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28), format: format).image { renderer in
            let c = renderer.cgContext
            c.setLineJoin(.round)
            c.setLineCap(.round)
            c.setShadow(offset: CGSize(width: 0.3, height: 0.6), blur: selected ? 0.8 : 0.4, color: UIColor.black.withAlphaComponent(selected ? 0.14 : 0.08).cgColor)

            func face(_ path: CGPath, cap: Bool = false, hole: Bool = false) {
                c.saveGState()
                c.addPath(path)
                c.clip(using: hole ? .evenOdd : .winding)
                let fill = [UIColor(palette.glowFillTop).withAlphaComponent(selected ? 0.95 : 0.80).cgColor,
                            UIColor(cap ? palette.outerStrokeStart : palette.badgeStart).withAlphaComponent(selected ? 0.85 : 0.58).cgColor,
                            UIColor(palette.glowFillBottom).withAlphaComponent(0.92).cgColor] as CFArray
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fill, locations: [0, 0.48, 1])!
                c.drawLinearGradient(gradient, start: CGPoint(x: 4, y: 2), end: CGPoint(x: 25, y: 28), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                c.restoreGState()
                c.addPath(path)
                c.setStrokeColor(UIColor(palette.titleText).withAlphaComponent(selected ? 1 : 0.90).cgColor)
                c.setLineWidth(0.95)
                c.strokePath()
                c.setShadow(offset: .zero, blur: 0, color: nil)
            }

            switch kind {
            case .design:
                c.translateBy(x: 14, y: 14)
                c.rotate(by: 0.30)
                c.translateBy(x: -14, y: -14)
                let body = CGPath(roundedRect: CGRect(x: 8.5, y: 13, width: 12, height: 12.5), cornerWidth: 3.1, cornerHeight: 3.1, transform: nil)
                face(body)
                face(CGPath(roundedRect: CGRect(x: 11.6, y: 2, width: 5.8, height: 11.5), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil), cap: true)
                c.setStrokeColor(UIColor.white.withAlphaComponent(0.78).cgColor)
                c.setLineWidth(0.7)
                c.move(to: CGPoint(x: 10.7, y: 16))
                c.addLine(to: CGPoint(x: 10.7, y: 22))
                c.move(to: CGPoint(x: 13.1, y: 4))
                c.addLine(to: CGPoint(x: 13.1, y: 10))
                c.strokePath()
            case .items:
                face(CGPath(roundedRect: CGRect(x: 3.6, y: 4.2, width: 20.8, height: 20.8), cornerWidth: 2.3, cornerHeight: 2.3, transform: nil), cap: true)
                c.setStrokeColor(UIColor(palette.titleText).cgColor)
                c.setLineWidth(0.95)
                c.move(to: CGPoint(x: 4, y: 14.3))
                c.addLine(to: CGPoint(x: 24, y: 14.3))
                c.strokePath()
                c.setLineWidth(1.15)
                for y in [CGFloat(9), CGFloat(19.2)] {
                    c.move(to: CGPoint(x: 11, y: y))
                    c.addQuadCurve(to: CGPoint(x: 17, y: y), control: CGPoint(x: 14, y: y + 1))
                }
                c.strokePath()
                c.setStrokeColor(UIColor.white.withAlphaComponent(0.65).cgColor)
                c.setLineWidth(0.6)
                c.move(to: CGPoint(x: 5.5, y: 6))
                c.addLine(to: CGPoint(x: 22, y: 6))
                c.strokePath()
            case .settings:
                let gear = CGMutablePath()
                for index in 0..<32 {
                    let angle = Double(index) * .pi / 16 - .pi / 2
                    let radius = index % 4 == 1 || index % 4 == 2 ? 11.2 : 8.8
                    let point = CGPoint(x: 14 + cos(angle) * radius, y: 14 + sin(angle) * radius)
                    if index == 0 { gear.move(to: point) } else { gear.addLine(to: point) }
                }
                gear.closeSubpath()
                gear.addEllipse(in: CGRect(x: 9.6, y: 9.6, width: 8.8, height: 8.8))
                face(gear, cap: true, hole: true)
            }
        }.withRenderingMode(.alwaysOriginal)
        icons.totalCostLimit = 4 * 1024 * 1024
        icons.setObject(image, forKey: key, cost: Int(28 * 28 * format.scale * format.scale * 4))
        return image
    }

    static func selection(palette: GlassTheme.DesignCardPalette, dark: Bool, scale: CGFloat) -> UIImage {
        let size = CGSize(width: 76, height: 48)
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(1, scale)
        return TabGlassSurface.image(palette: palette, dark: dark, size: size, scale: format.scale, selected: true)
            .resizableImage(withCapInsets: UIEdgeInsets(top: 22, left: 24, bottom: 22, right: 24))
            .withRenderingMode(.alwaysOriginal)
    }
}

/// 広告枠と標準バーの表示用パレット。背景と記録カードの設定は独立したまま保つ。
extension GlassTheme.BackgroundPreset {
    var refinedSurfacePalette: GlassTheme.DesignCardPalette {
        let linked: GlassTheme.DesignCardPreset
        switch self {
        case .smokySageChampagne, .graphiteMint: linked = .sageGold
        case .stoneRose: linked = .mauveBronze
        case .mistBlueTaupe: linked = .slateBlueSilver
        case .ivoryCoral: linked = .terracottaCream
        case .noirSilver: linked = .noirSilver
        case .noirGold: linked = .noirGold
        case .ivoryGold: linked = .ivoryGold
        case .rainbow: linked = .rainbow
        }
        return GlassTheme.designCardPalette(for: linked)
    }
}

/// 標準タブバーの形状・配置・選択処理を保ち、公開Appearance APIで素材だけを設定する。
private struct RefinedTabBarStyle: UIViewControllerRepresentable {
    let selectedTab: Int
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var presetRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeUIViewController(context: Context) -> MaterialController { MaterialController() }

    func updateUIViewController(_ controller: MaterialController, context: Context) {
        controller.presetRaw = presetRaw
        controller.reduceTransparency = reduceTransparency
        controller.selectedTab = selectedTab
        Task { @MainActor [weak controller] in controller?.applyMaterial() }
    }

    final class MaterialController: UIViewController {
        var presetRaw = ""
        var reduceTransparency = false
        var selectedTab = 0
        private weak var styledBar: UITabBar?
        private var appliedKey = ""
        private let glassBackdrop = UIVisualEffectView()
        private let glassFace = CALayer()
        private let selectedFace = CALayer()
        private let selectedRim = CALayer()
        private let metalRim = CALayer()
        private var decorationKey = ""

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyMaterial()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyMaterial()
        }

        func applyMaterial() {
            guard let root = view.window?.rootViewController,
                  let bar = findTabController(in: root)?.tabBar else { return }
            guard bar.bounds.width > 0, bar.bounds.height > 0 else { return }
            let scale = bar.traitCollection.displayScale
            let key = presetRaw + String(reduceTransparency) + String(describing: bar.bounds.size) + String(describing: scale)
            let preset = GlassTheme.BackgroundPreset(rawValue: presetRaw) ?? .smokySageChampagne
            decorateGlass(in: bar, palette: preset.refinedSurfacePalette, dark: preset == .noirSilver || preset == .noirGold, scale: scale)
            guard styledBar !== bar || appliedKey != key else { return }
            let palette = preset.refinedSurfacePalette
            let dark = preset == .noirSilver || preset == .noirGold
            // OSの外観と背景テーマが異なる場合も、バー内の文字とアイコンを読みやすくする。
            bar.overrideUserInterfaceStyle = dark ? .dark : .light
            bar.unselectedItemTintColor = UIColor(palette.titleText)
            bar.tintColor = UIColor(palette.titleIcon)
            let appearance = bar.standardAppearance.copy()
            if #available(iOS 27.0, *) {
                appearance.overrideUserInterfaceStyle = dark ? .dark : .light
            }
            appearance.backgroundEffect = reduceTransparency ? nil : UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.backgroundColor = UIColor(palette.glowFillMid).withAlphaComponent(reduceTransparency ? 1 : (dark ? 0.66 : 0.20))
            appearance.backgroundImage = surfaceImage(palette: palette, dark: dark, size: bar.bounds.size)
            appearance.shadowColor = UIColor(palette.outerStrokeEnd).withAlphaComponent(0.36)
            // 選択カプセルの輪郭や寸法はOSに任せ、テーマ色の薄い面だけを与える。
            appearance.selectionIndicatorTintColor = UIColor(palette.outerStrokeStart).withAlphaComponent(dark ? 0.22 : 0.14)
            appearance.selectionIndicatorImage = LuxuryTabArtwork.selection(palette: palette, dark: dark, scale: scale)
            for item in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
                item.normal.iconColor = UIColor(palette.titleText)
                item.normal.titleTextAttributes[.foregroundColor] = UIColor(palette.titleText)
                item.selected.iconColor = UIColor(palette.titleIcon)
                item.selected.titleTextAttributes[.foregroundColor] = UIColor(palette.titleText)
                let highlight = NSShadow()
                highlight.shadowColor = UIColor.white.withAlphaComponent(dark ? 0.10 : 0.38)
                highlight.shadowOffset = CGSize(width: 0, height: -0.5)
                highlight.shadowBlurRadius = 1
                item.selected.titleTextAttributes[.shadow] = highlight
            }
            bar.standardAppearance = appearance
            bar.scrollEdgeAppearance = appearance
            // 各タブの外観がバー全体を上書きするため、同じ表示設定を渡す。
            for item in bar.items ?? [] {
                item.standardAppearance = appearance
                item.scrollEdgeAppearance = appearance
                if let kind = LuxuryTabArtwork.Kind.allCases.first(where: { $0.title == item.title }) {
                    item.image = LuxuryTabArtwork.icon(kind: kind, preset: preset, selected: false, scale: scale)
                    item.selectedImage = LuxuryTabArtwork.icon(kind: kind, preset: preset, selected: true, scale: scale)
                    item.largeContentSizeImage = LuxuryTabArtwork.icon(kind: kind, preset: preset, selected: true, scale: scale * 2)
                    item.accessibilityLabel = kind.title
                }
            }
            bar.layer.shadowColor = UIColor.black.cgColor
            bar.layer.shadowOpacity = dark ? 0.14 : 0.08
            bar.layer.shadowRadius = 9
            bar.layer.shadowOffset = CGSize(width: 1, height: 4)
            styledBar = bar
            appliedKey = key
        }

        private func decorateGlass(in bar: UITabBar, palette: GlassTheme.DesignCardPalette, dark: Bool, scale: CGFloat) {
            // 標準UIControlの公開座標から内側の装飾領域を求め、ボタン自体は変更しない。
            var rectangles: [CGRect] = []
            func collect(_ view: UIView) {
                guard !view.isHidden, view.alpha > 0.01 else { return }
                if view is UIControl, view.bounds.width >= 45, view.bounds.height >= 36 {
                    let rect = view.convert(view.bounds, to: bar)
                    if bar.bounds.contains(rect), !rectangles.contains(rect) { rectangles.append(rect) }
                }
                for child in view.subviews { collect(child) }
            }
            collect(bar)
            rectangles.sort { $0.minX < $1.minX }
            guard rectangles.count == bar.items?.count, !rectangles.isEmpty else {
                glassBackdrop.removeFromSuperview()
                glassFace.removeFromSuperlayer()
                selectedFace.removeFromSuperlayer()
                selectedRim.removeFromSuperlayer()
                metalRim.removeFromSuperlayer()
                decorationKey = ""
                return
            }
            let outer = rectangles.reduce(CGRect.null) { $0.union($1) }
            let itemIndex = bar.items?.firstIndex(where: { $0 === bar.selectedItem }) ?? min(selectedTab, rectangles.count - 1)
            let direction = UIView.userInterfaceLayoutDirection(for: bar.semanticContentAttribute)
            let index = direction == .rightToLeft ? rectangles.count - 1 - itemIndex : itemIndex
            let panel = rectangles[index].insetBy(dx: 2, dy: 1)
            let key = presetRaw + String(reduceTransparency) + String(describing: outer) + String(describing: panel) + String(describing: scale)
            guard key != decorationKey || glassFace.superlayer !== bar.layer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // 実際の背景をぼかす薄いガラス層。背後の文字をそのまま透かさない。
            glassBackdrop.frame = outer
            glassBackdrop.overrideUserInterfaceStyle = dark ? .dark : .light
            glassBackdrop.effect = reduceTransparency ? nil : UIBlurEffect(style: .systemUltraThinMaterial)
            glassBackdrop.backgroundColor = reduceTransparency ? UIColor(palette.glowFillMid) : .clear
            glassBackdrop.isUserInteractionEnabled = false
            glassBackdrop.isAccessibilityElement = false
            glassBackdrop.layer.cornerRadius = outer.height / 2
            glassBackdrop.clipsToBounds = true
            if glassBackdrop.superview !== bar { bar.insertSubview(glassBackdrop, at: 0) }
            glassFace.frame = outer
            glassFace.contentsScale = scale
            glassFace.contents = surfaceImage(palette: palette, dark: dark, size: outer.size).cgImage
            glassFace.cornerRadius = outer.height / 2
            glassFace.masksToBounds = true
            glassFace.opacity = 1
            selectedFace.frame = panel
            selectedFace.contentsScale = scale
            selectedFace.contents = LuxuryTabArtwork.selection(palette: palette, dark: dark, scale: scale).cgImage
            selectedFace.contentsCenter = CGRect(x: 24.0 / 76, y: 22.0 / 48, width: 28.0 / 76, height: 4.0 / 48)
            selectedFace.cornerRadius = panel.height / 2
            selectedFace.masksToBounds = false
            selectedFace.shadowPath = CGPath(roundedRect: CGRect(origin: .zero, size: panel.size).insetBy(dx: 1, dy: 1), cornerWidth: panel.height / 2, cornerHeight: panel.height / 2, transform: nil)
            selectedFace.shadowColor = UIColor(palette.outerStrokeEnd).cgColor
            selectedFace.shadowOpacity = dark ? 0.26 : 0.20
            selectedFace.shadowRadius = 2.5
            selectedFace.shadowOffset = CGSize(width: 0.5, height: 1.5)
            bar.layer.insertSublayer(glassFace, above: glassBackdrop.layer)
            bar.layer.insertSublayer(selectedFace, above: glassFace)
            // 選択面の縁だけを前面へ描き、アイコンとラベルの面は覆わない。
            metalRim.frame = outer
            metalRim.contentsScale = scale
            metalRim.contents = TabGlassSurface.image(palette: palette, dark: dark, size: outer.size, scale: scale, edgeOnly: true).cgImage
            bar.layer.addSublayer(metalRim)
            selectedRim.frame = panel
            selectedRim.contentsScale = scale
            selectedRim.contents = TabGlassSurface.image(palette: palette, dark: dark, size: panel.size, scale: scale, selected: true, edgeOnly: true).cgImage
            bar.layer.addSublayer(selectedRim)
            CATransaction.commit()
            decorationKey = key
        }

        private func findTabController(in controller: UIViewController) -> UITabBarController? {
            if let tabs = controller as? UITabBarController { return tabs }
            return controller.children.lazy.compactMap { self.findTabController(in: $0) }.first
        }

        private func surfaceImage(palette: GlassTheme.DesignCardPalette, dark: Bool, size: CGSize) -> UIImage {
            TabGlassSurface.image(palette: palette, dark: dark, size: size, scale: view.traitCollection.displayScale, opaque: reduceTransparency)
        }
    }
}

/// 左上光源のガラス面と金属の細い断面を静止画像化し、既存の操作面の内側に描く。
private enum TabGlassSurface {
    static func image(palette: GlassTheme.DesignCardPalette, dark: Bool, size: CGSize, scale: CGFloat, selected: Bool = false, edgeOnly: Bool = false, opaque: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(1, scale)
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let c = renderer.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            let height = size.height
            func path(_ inset: CGFloat) -> CGPath {
                CGPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), cornerWidth: max(0, height / 2 - inset), cornerHeight: max(0, height / 2 - inset), transform: nil)
            }
            func gradient(_ colors: [UIColor], _ locations: [CGFloat], _ start: CGPoint, _ end: CGPoint) {
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: locations)!
                c.drawLinearGradient(g, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
            let metalLight = UIColor(palette.outerStrokeStart)
            let metalShade = UIColor(palette.outerStrokeEnd)
            let glass = UIColor(palette.glowFillMid)
            if !edgeOnly {
                c.saveGState()
                c.addPath(path(1.4)); c.clip()
                if dark {
                    // 濃色は白い文字とのコントラストを維持する。
                    gradient([UIColor(palette.glowFillTop).withAlphaComponent(opaque ? 1 : 0.38),
                              glass.withAlphaComponent(opaque ? 1 : (selected ? 0.32 : 0.16)),
                              metalShade.withAlphaComponent(opaque ? 1 : 0.30)],
                             [0, 0.48, 1], .zero, CGPoint(x: size.width * 0.2, y: height))
                } else {
                    // 追加ボタンの2色へガラス色を混ぜ、少し淡い同系色にそろえる。
                    func softened(_ color: UIColor) -> UIColor {
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        var gr: CGFloat = 0, gg: CGFloat = 0, gb: CGFloat = 0, ga: CGFloat = 0
                        color.getRed(&r, green: &g, blue: &b, alpha: &a)
                        glass.getRed(&gr, green: &gg, blue: &gb, alpha: &ga)
                        let mix: CGFloat = selected ? 0.22 : 0.28
                        return UIColor(red: r + (gr - r) * mix, green: g + (gg - g) * mix, blue: b + (gb - b) * mix, alpha: opaque ? 1 : 0.80)
                    }
                    gradient([softened(metalLight), softened(metalShade)], [0, 1], .zero, CGPoint(x: size.width, y: height))
                }
                // ガラス内部の縁の陰影。反射帯とは別の層で厚みを示す。
                gradient([metalShade.withAlphaComponent(dark ? 0.25 : 0.09), .clear, .clear, metalShade.withAlphaComponent(dark ? 0.30 : 0.12)],
                         [0, 0.14, 0.77, 1], .zero, CGPoint(x: 0, y: height))
                // 光の帯は局所的に置き、アイコンや文字を白い面で覆わない。
                gradient([.clear, UIColor.white.withAlphaComponent(dark ? 0.13 : (selected ? 0.46 : 0.32)), .clear,
                          UIColor(palette.glowFillTop).withAlphaComponent(0.11), .clear],
                         [0, 0.25, 0.43, 0.69, 1], CGPoint(x: size.width * 0.08, y: 0), CGPoint(x: size.width * 0.92, y: height))
                c.restoreGState()
            }
            // 外側の暗いエッジ、金属反射、内側の切削面を細く分離する。
            func edge(_ inset: CGFloat, _ width: CGFloat, _ colors: [UIColor], _ stops: [CGFloat]) {
                c.saveGState()
                c.addPath(path(inset)); c.setLineWidth(width); c.replacePathWithStrokedPath(); c.clip()
                gradient(colors, stops, .zero, CGPoint(x: size.width * 0.24, y: height))
                c.restoreGState()
            }
            edge(0.65, 0.65, [metalLight.withAlphaComponent(0.62), metalShade.withAlphaComponent(0.80), metalShade.withAlphaComponent(0.88)], [0, 0.50, 1])
            edge(1.45, 0.85, [UIColor.white.withAlphaComponent(0.94), metalLight.withAlphaComponent(0.86), metalShade.withAlphaComponent(0.68), metalLight.withAlphaComponent(0.90), metalShade.withAlphaComponent(0.85)], [0, 0.20, 0.48, 0.72, 1])
            edge(2.30, 0.55, [metalShade.withAlphaComponent(0.58), metalLight.withAlphaComponent(0.30), UIColor.white.withAlphaComponent(dark ? 0.30 : 0.80)], [0, 0.40, 1])
            edge(3.05, 0.50, [UIColor.white.withAlphaComponent(dark ? 0.40 : 0.88), UIColor.white.withAlphaComponent(0.10), metalShade.withAlphaComponent(0.30)], [0, 0.36, 1])
        }
    }
}
