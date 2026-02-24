import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            // 記録（Entries）
            EntryListView()
                .tabItem {
                    Label("デザイン", systemImage: "hand.raised.fill")
                }

            // 用品（Products）
            ProductListView()
                .tabItem {
                    Label("アイテム", systemImage: "drop.fill")
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
