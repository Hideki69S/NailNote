import SwiftUI

struct SimHomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("画像シミュレーション（レベル1）")
                    .font(.headline)
                Text("月3回（低画質）＋追加は回数券\n※ここは後で実装")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("シミュ")
        }
    }
}
