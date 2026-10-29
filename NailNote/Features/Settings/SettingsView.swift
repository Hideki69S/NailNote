import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    private let supportLinks: [SupportLink] = [
        .init(title: "利用規約", systemImage: "doc.text", urlString: "https://example.com/terms"),
        .init(title: "不具合報告", systemImage: "ant.fill", urlString: "https://example.com/bug"),
        .init(title: "お問い合わせ", systemImage: "envelope", urlString: "https://example.com/contact"),
        .init(title: "プライバシーポリシー", systemImage: "lock.shield", urlString: "https://example.com/privacy")
    ]

    var body: some View {
        NavigationStack {
            GlassBackgroundView(appearanceArea: .settings) {
                List {
                    Section("アカウント") {
                        SettingInfoRow(
                            title: "アカウントについて",
                            description: "Apple IDでバックアップされ、複数端末から同じ記録にアクセスできます。今後はメールアドレス認証にも対応予定です。",
                            systemImage: "person.crop.circle"
                        )
                    }

                    if NailNoteFeatureFlags.aiEvaluationEnabled {
                        Section("サブスクリプション") {
                            SettingInfoRow(
                                title: "サブスクについて",
                                description: "月額プランでAIネイルスコアの追加利用枠やクラウド同期を提供予定です。価格と開始時期はアプリ内で告知します。",
                                systemImage: "creditcard"
                            )
                        }
                    }

                    Section("アプリ情報") {
                        SettingInfoRow(
                            title: "アプリについて",
                            description: NailNoteFeatureFlags.aiEvaluationEnabled
                                ? "NailNoteはネイル施術記録と用品管理を一体化したプライベートログアプリです。Glass UIを基調に、写真・カテゴリ・AIスコアを一画面で確認できます。"
                                : "NailNoteはネイル施術記録と用品管理を一体化したプライベートログアプリです。写真・カテゴリ・自己評価で記録を振り返り、所持アイテムを管理できます。",
                            systemImage: "sparkles.rectangle.stack"
                        )
                        HStack {
                            Label("バージョン 1.0.0", systemImage: "info.circle")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    Section("サポート") {
                        ForEach(supportLinks) { link in
                            Button {
                                link.open(with: openURL)
                            } label: {
                                Label(link.title, systemImage: link.systemImage)
                            }
                        }
                    }

                    Section {
                        NavigationLink("外観カスタマイズ", destination: NailAppearanceSettingsView())
                    } header: {
                        Text("外観カスタマイズ")
                    } footer: {
                        Text("全体・画面別の色と質感を設定できます。標準ではカスタマイズ内の従来テーマを使用します。")
                    }




                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .modifier(NailAppearanceEnvironment(area: .settings))
        }
    }


}


/// 保存キーと選択値をそのまま使い、配置だけをカスタマイズ内へまとめる。
private struct LegacyThemeSettingsSection: View {
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundPresetRaw: String = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    @AppStorage(GlassTheme.Keys.itemCardPreset) private var itemCardPresetRaw: String = GlassTheme.ItemCardPreset.roseChampagne.rawValue
    @AppStorage(GlassTheme.Keys.aiChartPreset) private var aiChartPresetRaw: String = GlassTheme.AIScoreChartPreset.freshGreen.rawValue
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("従来の背景の見本").font(.caption).foregroundStyle(.secondary)
                NailAppearancePreview(choice: .init(), area: .design)
                    .frame(height: 130).clipped()
            }
            Picker("ページ背景", selection: backgroundPresetBinding) {
                ForEach(GlassTheme.BackgroundPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Picker("デザインカード", selection: designCardPresetBinding) {
                ForEach(GlassTheme.DesignCardPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Picker("アイテムカード", selection: itemCardPresetBinding) {
                ForEach(GlassTheme.ItemCardPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            ForEach([NailAppearance.Area.design, .items, .settings]) { area in
                Text(legacyBackgroundStatus(area))
                    .font(.caption).foregroundStyle(.secondary)
            }

            if NailNoteFeatureFlags.aiEvaluationEnabled {
                Picker("AI評価チャート", selection: aiChartPresetBinding) {
                    ForEach(GlassTheme.AIScoreChartPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
            }
        } header: {
            Text("従来のテーマ（標準時に使用）")
        } footer: {
            Text("標準を使用するエリアには、この背景・カードテーマが反映されます。背景スタイルを別に指定した場合は、その質感を使います。新しいプリセット・自由色が有効なエリアでは追加設定が優先されます。外観リセットでも、ここで選んだテーマは保持されます。")
        }

    }
    private var backgroundPresetBinding: Binding<GlassTheme.BackgroundPreset> {
        NailBackgroundSelection.binding(raw: $backgroundPresetRaw)
    }

    private func legacyBackgroundStatus(_ area: NailAppearance.Area) -> String {
        let document = NailAppearance.Document.decode(appearanceRaw)
        guard let choice = document.resolved(area), choice.changesColor else {
            return "\(area.title)：従来の背景色を使用"
        }
        let source = document.overrides[area.rawValue] == nil ? "全体" : "個別"
        return "\(area.title)：\(source)カラーを優先中。従来テーマを反映するには、エリア別のカラーを標準に戻してください。"
    }

    private var designCardPresetBinding: Binding<GlassTheme.DesignCardPreset> {
        Binding(
            get: { GlassTheme.DesignCardPreset(rawValue: designCardPresetRaw) ?? .roseChampagne },
            set: { designCardPresetRaw = $0.rawValue }
        )
    }

    private var itemCardPresetBinding: Binding<GlassTheme.ItemCardPreset> {
        Binding(
            get: { GlassTheme.ItemCardPreset(rawValue: itemCardPresetRaw) ?? .roseChampagne },
            set: { itemCardPresetRaw = $0.rawValue }
        )
    }

    private var aiChartPresetBinding: Binding<GlassTheme.AIScoreChartPreset> {
        Binding(
            get: { GlassTheme.AIScoreChartPreset(rawValue: aiChartPresetRaw) ?? .freshGreen },
            set: { aiChartPresetRaw = $0.rawValue }
        )
    }
}

/// Pickerと検証が同じ選択処理を通り、旧キーのrawValueだけを更新する。
enum NailBackgroundSelection {
    static func binding(raw: Binding<String>) -> Binding<GlassTheme.BackgroundPreset> {
        Binding(get: { GlassTheme.BackgroundPreset(rawValue: raw.wrappedValue) ?? .smokySageChampagne },
                set: { raw.wrappedValue = $0.rawValue })
    }
}

/// 編集中の値は保存済み設定と分離し、プレビューから個別設定で隠さない。
final class NailAppearanceEditSession: ObservableObject {
    let area: NailAppearance.Area?
    @Published private(set) var choice: NailAppearance.Choice
    private(set) var hasEdits = false

    init(area: NailAppearance.Area?, choice: NailAppearance.Choice) { self.area = area; self.choice = choice }

    var presetBinding: Binding<NailAppearance.Preset> {
        Binding(get: { self.choice.preset }, set: { preset in
            self.hasEdits = true
            self.choice.preset = preset
            if preset == .custom && self.choice.customColor == nil { self.choice.customColor = preset.rgb }
        })
    }
    var styleBinding: Binding<NailAppearance.Background?> {
        Binding(get: { self.choice.background }, set: { self.hasEdits = true; self.choice.background = $0 })
    }
    var colorBinding: Binding<Color> {
        Binding(get: { self.choice.rgb.color }, set: { color in
            self.hasEdits = true
            self.choice.customColor = NailAppearance.RGB(color: color)
            self.choice.preset = .custom
        })
    }
    func result(in document: NailAppearance.Document) -> NailAppearance.Document {
        var document = document
        var saved = choice
        if area?.hasBackground == false { saved.background = nil }
        document.set(saved, for: area)
        return document
    }
    func save(to defaults: UserDefaults = .standard) {
        let document = NailAppearance.Document.decode(defaults.string(forKey: NailAppearance.key) ?? "")
        defaults.set(result(in: document).encoded, forKey: NailAppearance.key)
        hasEdits = false
    }
    func refreshIfClean(from document: NailAppearance.Document) {
        guard !hasEdits else { return }
        choice = area.flatMap { document.resolved($0) } ?? (area == nil ? document.global : nil) ?? .init()
    }
}

/// 編集途中は下書きだけを変更し、保存時に対象の設定だけを更新する。
struct NailAppearanceSettingsView: View {
    @AppStorage(NailAppearance.key) private var raw = ""
    @State private var confirmingReset = false
    private var document: NailAppearance.Document { .decode(raw) }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    NailAppearanceEditor(area: nil, initial: document.global ?? .init())
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("全体設定・全エリアに適用")
                        Text(document.global.map { appearanceSummary($0, showsBackground: true) } ?? "従来のテーマを使用")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("全体設定を保存しても、個別設定のあるエリアは上書きしません。個別設定を解除すると全体設定を継承します。")
            }
            Section("エリア別設定") {
                ForEach(NailAppearance.Area.allCases) { area in
                    NavigationLink {
                        NailAppearanceEditor(area: area, initial: document.resolved(area) ?? .init())
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(area.title)
                            Text(status(area)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            LegacyThemeSettingsSection()
            Section {
                Button("外観カスタマイズだけをリセット", role: .destructive) { confirmingReset = true }
            } footer: {
                Text("従来の9種類のテーマ設定、記録、用品、写真、フィルター、その他の設定は変更しません。")
            }
        }
        .navigationTitle("外観カスタマイズ")
        .confirmationDialog("外観カスタマイズを標準に戻しますか？", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("外観だけをリセット", role: .destructive) { raw = "" }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func status(_ area: NailAppearance.Area) -> String {
        if let choice = document.overrides[area.rawValue] { return "個別：\(appearanceSummary(choice, showsBackground: area.hasBackground))" }
        if let global = document.global { return "全体を継承：\(appearanceSummary(global, showsBackground: area.hasBackground))" }
        return "標準：従来のテーマ"
    }
}

private func appearanceSummary(_ choice: NailAppearance.Choice, showsBackground: Bool) -> String {
    guard showsBackground else { return choice.preset.title }
    let style = choice.background?.title ?? (choice.changesColor ? "Silk（自動）" : "従来の背景")
    return "\(choice.preset.title) ／ \(style)"
}

struct NailAppearanceEditor: View {
    let area: NailAppearance.Area?
    @StateObject private var draft: NailAppearanceEditSession
    @State private var previewArea: NailAppearance.Area = .design
    @AppStorage(NailAppearance.key) private var raw = ""
    @Environment(\.dismiss) private var dismiss

    init(area: NailAppearance.Area?, initial: NailAppearance.Choice, session: NailAppearanceEditSession? = nil) {
        self.area = area
        _draft = StateObject(wrappedValue: session ?? NailAppearanceEditSession(area: area, choice: initial))
    }

    var body: some View {
        Form {
            Section("編集中の見本（保存前）") {
                if area == nil {
                    Picker("プレビュー対象", selection: $previewArea) {
                        Text("デザイン").tag(NailAppearance.Area.design)
                        Text("アイテム").tag(NailAppearance.Area.items)
                        Text("設定").tag(NailAppearance.Area.settings)
                    }
                    .pickerStyle(.segmented)
                }
                NailAppearancePreview(choice: draft.choice, area: area ?? previewArea)
                    .frame(height: 160).clipped()
                    .listRowInsets(EdgeInsets())
                if area == nil && document.overrides[previewArea.rawValue] != nil {
                    Text("この画面には個別設定があります。全体の変更は適用されません。反映するには、エリア別設定で個別設定を解除してください。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if area == nil && document.overrides[previewArea.rawValue] != nil {
                Section("保存後の画面（個別設定を優先）") {
                    NailAppearancePreview(choice: previewChoice, area: previewArea)
                        .frame(height: 130).clipped()
                }
            }
            Section("カラー") {
                Picker("プリセット", selection: draft.presetBinding) {
                    ForEach(NailAppearance.Preset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                ColorPicker("自由なカラー", selection: draft.colorBinding, supportsOpacity: false)
                Text("標準は従来のテーマを使います。個別に標準を保存すると、そのエリアでは全体の配色を使用しません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if area?.hasBackground != false {
                Section {
                    Picker("背景スタイル", selection: draft.styleBinding) {
                        Text("標準の質感").tag(Optional<NailAppearance.Background>.none)
                        ForEach(NailAppearance.Background.allCases) { style in
                            Text(style.title).tag(Optional(style))
                        }
                    }
                } footer: {
                    Text(area == nil
                         ? "個別設定がないデザイン・アイテム・設定画面に適用します。個別設定がある画面は上書きしません。タブバーと＋ボタンは色だけが対象です。"
                         : "保存すると、この画面の実際の背景に適用します。標準の質感は、標準カラーでは従来テーマ、それ以外ではSilkです。")
                }
            }
            Section {
                Button(area == nil ? "全体設定を解除" : "個別設定を解除して全体を継承") {
                    var document = NailAppearance.Document.decode(raw)
                    document.set(nil, for: area)
                    raw = document.encoded
                    dismiss()
                }
            }
        }
        .navigationTitle(area?.title ?? "全体設定")
        .onAppear { draft.refreshIfClean(from: document) }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    draft.save()
                    dismiss()
                }
            }
        }
    }

    private var document: NailAppearance.Document { .decode(raw) }
    private var previewChoice: NailAppearance.Choice {
        draft.result(in: document).resolved(area ?? previewArea) ?? .init()
    }
}

struct NailAppearancePreview: View {
    let choice: NailAppearance.Choice
    let area: NailAppearance.Area?
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue

    var body: some View {
        let base = (GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne).refinedSurfacePalette
        let p = NailAppearance.designPalette(base, choice: choice)
        ZStack {
            if choice.changesColor || choice.background != nil {
                NailAppearanceBackground(choice: choice, preset: GlassTheme.BackgroundPreset(rawValue: backgroundRaw) ?? .smokySageChampagne)
            } else {
                GlassBackgroundView(refined: area != .items) { Color.clear }
            }
            HStack(spacing: 12) {
                Image(systemName: area == .addButton ? "plus" : "square.stack")
                VStack(alignment: .leading, spacing: 6) {
                    Text(choice.preset.title).font(.headline)
                    Text("色・質感のイメージ").font(.caption)
                }
            }
            .foregroundStyle(p.titleText)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20).fill(p.glowFillMid.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(LinearGradient(colors: [p.outerStrokeStart, p.outerStrokeEnd], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ItemIconPreviewGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let candidates: [String] = [
        "drop.fill",
        "paintbrush.fill",
        "pouch",
        "pouch.fill",
        "eyedropper",
        "sparkles",
        "wand.and.stars"
    ]

    private let emojiCandidates: [String] = [
        "💅",
        "🧴",
        "🧪"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("アイテム向けに見やすい候補だけを表示しています。")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(candidates, id: \.self) { symbolName in
                    SymbolPreviewChip(symbolName: symbolName, label: "アイテム")
                }
            }

            Text("絵文字候補")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(emojiCandidates, id: \.self) { emoji in
                    EmojiPreviewChip(emoji: emoji, label: "アイテム")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DesignIconPreviewGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private let candidates: [String] = [
        "paintpalette.fill",
        "paintbrush.pointed.fill",
        "sparkles",
        "wand.and.stars",
        "hand.draw"
    ]

    private let emojiCandidates: [String] = [
        "💅"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ネイルの雰囲気に寄せやすい候補だけを表示しています。")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(candidates, id: \.self) { symbolName in
                    SymbolPreviewChip(symbolName: symbolName, label: "デザイン")
                }
            }

            Text("絵文字候補")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(emojiCandidates, id: \.self) { emoji in
                EmojiPreviewChip(emoji: emoji, label: "デザイン")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SymbolPreviewChip: View {
    let symbolName: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 22, alignment: .center)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(symbolName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct EmojiPreviewChip: View {
    let emoji: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(emoji)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct SettingInfoRow: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct SupportLink: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let urlString: String

    func open(with openURL: OpenURLAction) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}
