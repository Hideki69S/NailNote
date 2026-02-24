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
    @State private var designCategory: NailDesignCategory?
    @State private var colorTone: NailColorTone?
    @State private var rating: Double = 0
    @State private var selectedCategory: NailProductCategory = .color

    @State private var selectedProductIDs: [UUID] = []
    @State private var showValidationAlert = false

    // 写真
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedUIImage: UIImage?

    var body: some View {
        NavigationStack {
            GlassBackgroundView {
                Form {
                Section("基本情報") {
                    VStack(spacing: 12) {
                        inlineTitleRow
                        inlineDateRow
                        inlineDesignRow
                        inlineColorRow
                    }
                    .padding(.vertical, 4)

                    Text("※タイトル・実施日付・デザイン・カラー系統は必須です")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
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
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("ネイルデザインの登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isBasicInfoValid)
                }
            }
            .alert("必須項目を入力してください", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("タイトル・実施日付・デザイン・カラー系統をすべて入力してください。")
            }
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isBasicInfoValid: Bool {
        !trimmedTitle.isEmpty && designCategory != nil && colorTone != nil
    }

    private var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private var inlineDateRow: some View {
        HStack(alignment: .center, spacing: 12) {
            requiredFieldLabel("実施日付")
                .foregroundStyle(.primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ja_JP"))
                    .environment(\.calendar, Calendar(identifier: .gregorian))
                    .labelsHidden()
            }
        }
    }

    private var inlineDesignRow: some View {
        HStack(spacing: 12) {
            requiredFieldLabel("デザイン")
            Spacer()
            Picker("", selection: $designCategory) {
                Text("選択なし").tag(NailDesignCategory?.none)
                ForEach(NailDesignCategory.allCases) { category in
                    Text(category.displayName).tag(Optional(category))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var inlineColorRow: some View {
        HStack(spacing: 12) {
            requiredFieldLabel("カラー系統")
            Spacer()
            Picker("", selection: $colorTone) {
                Text("選択なし").tag(NailColorTone?.none)
                ForEach(NailColorTone.allCases) { tone in
                    Text(tone.displayName).tag(Optional(tone))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var inlineTitleRow: some View {
        HStack(spacing: 12) {
            requiredFieldLabel("タイトル")
            Spacer()
            TextField("例：春ネイル / オフのみ など", text: $title)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.sentences)
        }
    }

    private func requiredFieldLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.body)
            Text("必須")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .foregroundStyle(Color.red)
                .clipShape(Capsule())
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
        guard isBasicInfoValid else {
            showValidationAlert = true
            return
        }

        let entry = NailEntry(context: viewContext)
        entry.id = UUID()
        entry.date = date
        entry.title = trimmedTitle
        entry.note = note
        entry.designCategory = designCategory?.rawValue
        entry.colorCategory = colorTone?.rawValue
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
