import SwiftUI
import CoreData
import PhotosUI
import UIKit

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NailProduct.name, ascending: true)],
        animation: .default
    )
    private var products: FetchedResults<NailProduct>

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var designCategory: NailDesignCategory = .oneColor
    @State private var colorTone: NailColorTone = .pink
    @State private var rating: Double = 0
    @State private var selectedCategory: NailProductCategory = .color

    @State private var selectedProductIDs: [UUID] = []

    // 写真
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedUIImage: UIImage?

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("例：春ネイル / オフのみ など", text: $title)
                }

                Section("日付") {
                    DatePicker("施術日", selection: $date, displayedComponents: .date)
                }

                Section("デザイン") {
                    Picker("カテゴリ", selection: $designCategory) {
                        ForEach(NailDesignCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("カラー系統") {
                    Picker("カラー", selection: $colorTone) {
                        ForEach(NailColorTone.allCases) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("自己評価") {
                    StarRatingInputView(rating: $rating)
                }

                Section("写真") {
                    HStack(spacing: 12) {
                        photoPreview
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                            }

                            if selectedUIImage != nil {
                                Button(role: .destructive) {
                                    selectedUIImage = nil
                                    photoItem = nil
                                } label: {
                                    Label("写真を外す", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .onChange(of: photoItem) { _, newItem in
                    guard let newItem else { return }
                    Task { await loadImage(from: newItem) }
                }

                Section("メモ") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }

                Section("使用した用品") {
                    if products.isEmpty {
                        Text("用品がまだ登録されていません")
                            .foregroundStyle(.secondary)
                    } else {
                        CategoryTabBar(selected: $selectedCategory)
                            .padding(.bottom, 4)

                        if filteredProducts.isEmpty {
                            Text("このカテゴリの用品がありません")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(filteredProducts, id: \.objectID) { product in
                                Button {
                                    toggle(product)
                                } label: {
                                    SelectableProductRow(product: product,
                                                         isSelected: isSelected(product))
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                if !selectedProductIDs.isEmpty {
                    Section("選択済み（順番）") {
                        ForEach(selectedProductIDs, id: \.self) { pid in
                            if let p = product(for: pid) {
                                SelectedProductRow(product: p)
                            }
                        }
                    }
                }
            }
            .navigationTitle("新規記録")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    // MARK: - Photo UI

    private var photoPreview: some View {
        Group {
            if let img = selectedUIImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.gray.opacity(0.15))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadImage(from item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.selectedUIImage = uiImage
                }
            }
        } catch {
            print("写真読み込みエラー: \(error)")
        }
    }

    // MARK: - Category Logic

    private var filteredProducts: [NailProduct] {
        products
            .filter { normalizedCategory(for: $0) == selectedCategory }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private func normalizedCategory(for product: NailProduct) -> NailProductCategory {
        let raw = (product.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return NailProductCategory(rawValue: raw) ?? .other
    }

    // MARK: - Selection

    private func isSelected(_ product: NailProduct) -> Bool {
        guard let pid = product.id else { return false }
        return selectedProductIDs.contains(pid)
    }

    private func toggle(_ product: NailProduct) {
        guard let pid = product.id else { return }
        if let idx = selectedProductIDs.firstIndex(of: pid) {
            selectedProductIDs.remove(at: idx)
        } else {
            selectedProductIDs.append(pid)
        }
    }

    private func product(for id: UUID) -> NailProduct? {
        products.first(where: { $0.id == id })
    }

    // MARK: - Save

    private func save() {
        let entry = NailEntry(context: viewContext)
        entry.id = UUID()
        entry.date = date
        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.note = note
        entry.designCategory = designCategory.rawValue
        entry.colorCategory = colorTone.rawValue
        entry.rating = rating
        entry.createdAt = Date()
        entry.updatedAt = Date()

        // 写真保存（選択されている場合のみ）
        if let img = selectedUIImage {
            let pid = UUID()
            EntryPhotoStore.save(image: img, photoId: pid)
            entry.photoId = pid
        }

        // 選択順で usedItems を作成
        for (idx, pid) in selectedProductIDs.enumerated() {
            guard let product = product(for: pid) else { continue }

            let used = NailEntryUsedItem(context: viewContext)
            used.id = UUID()
            used.orderIndex = Int16(idx)
            used.entry = entry
            used.product = product
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("新規保存エラー: \(error)")
        }
    }
}

// MARK: - Product Selection UI

private struct CategoryTabBar: View {
    @Binding var selected: NailProductCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(NailProductCategory.allCases) { category in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            selected = category
                        }
                    } label: {
                        Text(category.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(selected == category ? Color.accentColor.opacity(0.95)
                                                              : Color.white.opacity(0.9))
                            )
                            .foregroundStyle(selected == category ? Color.white : .primary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SelectableProductRow: View {
    let product: NailProduct
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProductThumb(photoId: product.photoId)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let place = product.purchasePlace,
                   !place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }

    private var displayName: String {
        let name = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（名称未設定）" : name
    }
}

private struct SelectedProductRow: View {
    let product: NailProduct

    var body: some View {
        HStack(spacing: 12) {
            ProductThumb(photoId: product.photoId)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(categoryLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var displayName: String {
        let name = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（名称未設定）" : name
    }

    private var categoryLabel: String {
        let raw = (product.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return NailProductCategory(rawValue: raw)?.displayName ?? "未分類"
    }
}

private struct ProductThumb: View {
    let photoId: UUID?

    var body: some View {
        Group {
            if let photoId,
               let image = ProductPhotoStore.shared.loadImage(photoId: photoId) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.18))
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
