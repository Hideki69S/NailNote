import SwiftUI

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var backgroundPresetRaw: String = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    @AppStorage(GlassTheme.Keys.itemCardPreset) private var itemCardPresetRaw: String = GlassTheme.ItemCardPreset.roseChampagne.rawValue
    @AppStorage(GlassTheme.Keys.aiChartPreset) private var aiChartPresetRaw: String = GlassTheme.AIScoreChartPreset.freshGreen.rawValue
    /// 一時プレビュー用。不要になったら `false` にするかセクションごと削除する。
    private let showDesignIconPreview = true
    /// 一時プレビュー用。不要になったら `false` にするかセクションごと削除する。
    private let showItemIconPreview = true

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

                    if showDesignIconPreview {
                        Section("デザインアイコン候補（プレビュー）") {
                            Text("デザインフィルタ用の候補です。決まったらこのセクションは削除できます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DesignIconPreviewGrid()
                        }
                    }

                    if showItemIconPreview {
                        Section("アイテムアイコン候補（プレビュー）") {
                            Text("マニキュア/ネイル用品向けの候補です。決まったらこのセクションは削除できます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ItemIconPreviewGrid()
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
