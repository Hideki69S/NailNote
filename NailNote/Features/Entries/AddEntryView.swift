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
        let entry = NailEntry(context: viewContext)
        entry.id = UUID()
        entry.date = date
        entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.note = note
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
