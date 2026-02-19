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

            // シミュレーション（Sim）
            SimHomeView()
                .tabItem {
                    Label("シミュ", systemImage: "sparkles")
                }

            // 設定（Settings）
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
    }
}
