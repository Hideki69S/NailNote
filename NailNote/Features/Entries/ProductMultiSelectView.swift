import SwiftUI
import CoreData

struct ProductMultiSelectView: View {
    @Environment(\.managedObjectContext) private var context

    /// 選択された用品（NailProduct.id）の集合
    @Binding var selectedProductIDs: Set<UUID>

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \NailProduct.category, ascending: true),
            NSSortDescriptor(keyPath: \NailProduct.updatedAt, ascending: false)
        ],
        animation: .default
    )
    private var products: FetchedResults<NailProduct>

    var body: some View {
        List {
            ForEach(groupedCategories, id: \.self) { category in
                Section(category) {
                    ForEach(productsInCategory(category)) { product in
                        Button {
                            toggle(product)
                        } label: {
                            HStack {
                                Text(product.name ?? "（名称未設定）")
                                Spacer()
                                if isSelected(product) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("使用した用品")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("クリア") {
                    selectedProductIDs.removeAll()
                }
                .disabled(selectedProductIDs.isEmpty)
            }
        }
    }

    // MARK: - Grouping

    private var groupedCategories: [String] {
        let categories: [String] = products
            .compactMap { ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.isEmpty ? "未分類" : $0 }

        return Array(Set(categories)).sorted()
    }

    private func productsInCategory(_ category: String) -> [NailProduct] {
        products.filter {
            let c = (($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            let normalized = c.isEmpty ? "未分類" : c
            return normalized == category
        }
    }

    // MARK: - Selection

    private func isSelected(_ product: NailProduct) -> Bool {
        guard let id = product.id else { return false }
        return selectedProductIDs.contains(id)
    }

    private func toggle(_ product: NailProduct) {
        guard let id = product.id else { return }
        if selectedProductIDs.contains(id) {
            selectedProductIDs.remove(id)
        } else {
            selectedProductIDs.insert(id)
        }
    }
}
