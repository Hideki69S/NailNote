import SwiftUI
import CoreData
import PhotosUI
import UIKit

struct EditEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let entry: NailEntry

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NailProduct.name, ascending: true)],
        animation: .default
    )
    private var products: FetchedResults<NailProduct>

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""

    @State private var selectedProductIDs: [UUID] = []

    // 写真
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedUIImage: UIImage?
    @State private var removeExistingPhoto: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル") {
                    TextField("例：春ネイル / オフのみ など", text: $title)
                }

                Section("日付") {
                    DatePicker("施術日", selection: $date, displayedComponents: .date)
                }

                Section("写真") {
                    HStack(spacing: 12) {
                        photoPreview
                        VStack(alignment: .leading, spacing: 8) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Label("写真を変更", systemImage: "photo.on.rectangle")
                            }

                            if entry.photoId != nil || selectedUIImage != nil {
                                Button(role: .destructive) {
                                    // 既存写真を削除したい意思表示
                                    selectedUIImage = nil
                                    photoItem = nil
                                    removeExistingPhoto = true
                                } label: {
                                    Label("写真を削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .onChange(of: photoItem) { _, newItem in
                    guard let newItem else { return }
                    removeExistingPhoto = false
                    Task { await loadImage(from: newItem) }
                }

                Section("メモ") {
                    TextEditor(text: $note)
                        .frame(minHeight: 100)
                }

                // MARK: - カテゴリ別用品表示
                if products.isEmpty {
                    Section("使用した用品") {
                        Text("用品がまだ登録されていません")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(categoryKeys, id: \.self) { category in
                        Section(category) {
                            ForEach(products(in: category), id: \.objectID) { product in
                                Button {
                                    toggle(product)
                                } label: {
                                    HStack {
                                        Text(product.name ?? "（名称未設定）")
                                        Spacer()
                                        if isSelected(product) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !selectedProductIDs.isEmpty {
                    Section("選択済み（順番）") {
                        ForEach(selectedProductIDs, id: \.self) { pid in
                            if let p = product(for: pid) {
                                Text(p.name ?? "（名称未設定）")
                            }
                        }
                    }
                }
            }
            .navigationTitle("記録を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                loadFromEntry()
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
            } else if let pid = entry.photoId,
                      !removeExistingPhoto,
                      let img = EntryPhotoStore.loadThumbnail(photoId: pid) {
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

    // MARK: - Load

    private func loadFromEntry() {
        title = entry.title ?? ""
        date = entry.date ?? Date()
        note = entry.note ?? ""

        let ordered = (entry.usedItems?.array as? [NailEntryUsedItem]) ?? []
        let sorted = ordered.sorted { $0.orderIndex < $1.orderIndex }
        selectedProductIDs = sorted.compactMap { $0.product?.id }

        selectedUIImage = nil
        photoItem = nil
        removeExistingPhoto = false
    }

    // MARK: - Category Logic

    private var categoryKeys: [String] {
        let keys = products.map {
            let trimmed = ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "未分類" : trimmed
        }
        return Array(Set(keys)).sorted()
    }

    private func products(in category: String) -> [NailProduct] {
        products
            .filter {
                let trimmed = ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return (trimmed.isEmpty ? "未分類" : trimmed) == category
            }
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
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
        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.date = date
        entry.note = note
        entry.updatedAt = Date()

        // 用品（既存を削除して作り直す）
        if let existing = entry.usedItems?.array as? [NailEntryUsedItem] {
            for item in existing {
                viewContext.delete(item)
            }
        }
        for (idx, pid) in selectedProductIDs.enumerated() {
            guard let product = product(for: pid) else { continue }
            let used = NailEntryUsedItem(context: viewContext)
            used.id = UUID()
            used.orderIndex = Int16(idx)
            used.entry = entry
            used.product = product
        }

        // 写真
        applyPhotoChange()

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("編集保存エラー: \(error)")
        }
    }

    private func applyPhotoChange() {
        // 1) 削除が要求されている場合
        if removeExistingPhoto {
            if let old = entry.photoId {
                EntryPhotoStore.delete(photoId: old)
            }
            entry.photoId = nil
            return
        }

        // 2) 新しい画像が選ばれている場合（差し替え）
        if let img = selectedUIImage {
            // 古い写真があれば削除
            if let old = entry.photoId {
                EntryPhotoStore.delete(photoId: old)
            }

            let newId = UUID()
            EntryPhotoStore.save(image: img, photoId: newId)
            entry.photoId = newId
        }
        // 3) 何もしてない場合はそのまま
    }
}
