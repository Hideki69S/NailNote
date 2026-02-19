import SwiftUI
import CoreData

struct ProductListView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \NailProduct.category, ascending: true),
            NSSortDescriptor(keyPath: \NailProduct.updatedAt, ascending: false)
        ],
        animation: .default
    )
    private var products: FetchedResults<NailProduct>

    @State private var showingAddSheet = false
    @State private var editingProduct: NailProduct?

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedCategories, id: \.self) { category in
                    Section(header: Text(category)) {
                        ForEach(productsInCategory(category)) { product in
                            Button {
                                editingProduct = product
                            } label: {
                                ProductRow(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            delete(at: indexSet, in: category)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Item")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    AddOrEditProductView(mode: .add)
                }
            }
            .sheet(item: $editingProduct) { product in
                NavigationStack {
                    AddOrEditProductView(mode: .edit(product))
                }
            }
        }
    }

    // MARK: - Grouping

    private var groupedCategories: [String] {
        let categories: [String] = products
            .compactMap { ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.isEmpty ? "Uncategorized" : $0 }

        return Array(Set(categories)).sorted()
    }

    private func productsInCategory(_ category: String) -> [NailProduct] {
        products.filter {
            let c = (($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
            let normalized = c.isEmpty ? "Uncategorized" : c
            return normalized == category
        }
    }

    // MARK: - Delete

    private func delete(at offsets: IndexSet, in category: String) {
        let items = productsInCategory(category)
        for index in offsets {
            let item = items[index]
            context.delete(item)
        }
        saveContext()
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            print("CoreData save error: \(error)")
        }
    }
}

// MARK: - Row

private struct ProductRow: View {
    let product: NailProduct

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(photoId: product.photoId)

            VStack(alignment: .leading, spacing: 4) {
                let name = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                Text(name.isEmpty ? "（名称未設定）" : name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let place = product.purchasePlace,
                       !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(place)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let purchasedAt = product.purchasedAt {
                        Text(Self.dateFormatter.string(from: purchasedAt))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Text("¥\(product.priceYenTaxIn)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Thumbnail

private struct ProductThumbnail: View {
    let photoId: UUID?

    var body: some View {
        Group {
            if let photoId,
               let uiImage = ProductPhotoStore.shared.loadImage(photoId: photoId) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }
}
