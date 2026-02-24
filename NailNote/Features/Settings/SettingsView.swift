import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundPresetRaw: String = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    @AppStorage(GlassTheme.Keys.itemCardPreset) private var itemCardPresetRaw: String = GlassTheme.ItemCardPreset.roseChampagne.rawValue
    @AppStorage(GlassTheme.Keys.aiChartPreset) private var aiChartPresetRaw: String = GlassTheme.AIScoreChartPreset.freshGreen.rawValue

    private let supportLinks: [SupportLink] = [
        .init(title: "利用規約", systemImage: "doc.text", urlString: "https://example.com/terms"),
        .init(title: "不具合報告", systemImage: "ant.fill", urlString: "https://example.com/bug"),
        .init(title: "お問い合わせ", systemImage: "envelope", urlString: "https://example.com/contact"),
        .init(title: "プライバシーポリシー", systemImage: "lock.shield", urlString: "https://example.com/privacy")
    ]

    var body: some View {
        NavigationStack {
            GlassBackgroundView {
                List {
                    Section("アカウント") {
                        SettingInfoRow(
                            title: "アカウントについて",
                            description: "Apple IDでバックアップされ、複数端末から同じ記録にアクセスできます。今後はメールアドレス認証にも対応予定です。",
                            systemImage: "person.crop.circle"
                        )
                    }

                    Section("サブスクリプション") {
                        SettingInfoRow(
                            title: "サブスクについて",
                            description: "月額プランでAIネイルスコアの追加利用枠やクラウド同期を提供予定です。価格と開始時期はアプリ内で告知します。",
                            systemImage: "creditcard"
                        )
                    }

                    Section("アプリ情報") {
                        SettingInfoRow(
                            title: "アプリについて",
                            description: "NailNoteはネイル施術記録と用品管理を一体化したプライベートログアプリです。Glass UIを基調に、写真・カテゴリ・AIスコアを一画面で確認できます。",
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

                    Section("テーマ") {
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

                        Picker("AI評価チャート", selection: aiChartPresetBinding) {
                            ForEach(GlassTheme.AIScoreChartPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
        }
    }

    private var backgroundPresetBinding: Binding<GlassTheme.BackgroundPreset> {
        Binding(
            get: { GlassTheme.BackgroundPreset(rawValue: backgroundPresetRaw) ?? .smokySageChampagne },
            set: { backgroundPresetRaw = $0.rawValue }
        )
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
