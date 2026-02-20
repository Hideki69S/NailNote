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
    @State private var selectedCategory: NailProductCategory = .color

    var body: some View {
        GlassBackgroundView {
            NavigationStack {
                VStack(spacing: 0) {
                    List {
                        Section {
                            if filteredProducts.isEmpty {
                                ContentUnavailableView("該当する用品がありません", systemImage: "cube.box")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(filteredProducts) { product in
                                    Button {
                                        editingProduct = product
                                    } label: {
                                        ProductRow(product: product)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                }
                                .onDelete(perform: deleteSelectedProducts)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .padding(.top, 8)
                }
                .safeAreaInset(edge: .bottom) {
                    CategoryTabBar(selected: $selectedCategory)
                        .padding(.bottom, 8)
                        .padding(.horizontal, 16)
                }
                .navigationTitle("用品")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
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

    // MARK: - Filtering

    private var filteredProducts: [NailProduct] {
        products.filter { product in
            category(for: product) == selectedCategory
        }
    }

    private func category(for product: NailProduct) -> NailProductCategory {
        let raw = (product.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return NailProductCategory(rawValue: raw) ?? .other
    }

    // MARK: - Delete

    private func deleteSelectedProducts(at offsets: IndexSet) {
        let items = filteredProducts
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
        GlassCard {
            HStack(spacing: 16) {
                ThumbnailPair(mainId: product.photoId, sampleId: product.samplePhotoId)

                VStack(alignment: .leading, spacing: 6) {
                    let name = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(name.isEmpty ? "（名称未設定）" : name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .padding(.trailing, 4)
                        .layoutPriority(1)

                    VStack(alignment: .leading, spacing: 2) {
                        if let place = product.purchasePlace,
                           !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(place)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }

                        if let purchasedAt = product.purchasedAt {
                            Text(Self.dateFormatter.string(from: purchasedAt))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }
            .contentShape(Rectangle())
        }
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
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GlassTheme.cardStroke, lineWidth: 1)
        )
    }
}

// MARK: - Sample Thumbnail Pair

private struct ThumbnailPair: View {
    let mainId: UUID?
    let sampleId: UUID?

    var body: some View {
        HStack(spacing: 8) {
            ProductThumbnail(photoId: mainId)
            SampleThumbnail(photoId: sampleId)
        }
    }
}

private struct SampleThumbnail: View {
    let photoId: UUID?

    var body: some View {
        Group {
            if let photoId,
               let uiImage = ProductPhotoStore.loadThumbnail(photoId: photoId, kind: "sample") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.12))
                    Image(systemName: "paintpalette")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GlassTheme.cardStroke, lineWidth: 1)
        )
    }
}

// MARK: - Category Tab Bar

private struct CategoryTabBar: View {
    @Binding var selected: NailProductCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(NailProductCategory.allCases) { category in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selected = category
                        }
                    } label: {
                        Text(category.displayName)
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                Capsule()
                                    .fill(selected == category ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.85))
                            )
                            .foregroundStyle(selected == category ? Color.white : .primary)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}
