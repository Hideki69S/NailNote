import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("アプリ") {
                    Label("バージョン", systemImage: "info.circle")
                }
            }
            .navigationTitle("設定")
        }
    }
}
