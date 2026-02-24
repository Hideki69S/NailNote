import SwiftUI

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
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
        }
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
