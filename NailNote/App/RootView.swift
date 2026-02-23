import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            // 記録（Entries）
            EntryListView()
                .tabItem {
                    Label("記録", systemImage: "list.bullet.rectangle")
                }

            // 用品（Products）
            ProductListView()
                .tabItem {
                    Label("用品", systemImage: "bag")
                }

            // AIネイルスコア
            SimHomeView()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }

            // 設定（Settings）
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}
