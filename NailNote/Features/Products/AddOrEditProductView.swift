import SwiftUI
import CoreData
import PhotosUI
import UIKit

struct AddOrEditProductView: View {
    enum Mode {
        case add
        case edit(NailProduct)

        var title: String {
            switch self {
            case .add: return "用品を追加"
            case .edit: return "用品を編集"
            }
        }

        var isEdit: Bool {
            switch self {
            case .add: return false
            case .edit: return true
            }
        }

        var product: NailProduct? {
            switch self {
            case .add: return nil
            case .edit(let p): return p
            }
        }
    }

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    // Form state
    @State private var name: String = ""
    @State private var category: NailProductCategory = .color
    @State private var purchasedAtEnabled: Bool = false
    @State private var purchasedAt: Date = Date()
    @State private var purchasePlace: String = ""
    @State private var priceText: String = ""   // 空スタート

    // 写真（商品）
    @State private var mainPhotoItem: PhotosPickerItem?
    @State private var mainUIImage: UIImage?
    @State private var removeMain: Bool = false

    // 写真（サンプルカラー）
    @State private var samplePhotoItem: PhotosPickerItem?
    @State private var sampleUIImage: UIImage?
    @State private var removeSample: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("商品名", text: $name)

                    Picker("カテゴリ", selection: $category) {
                        ForEach(NailProductCategory.allCases) { c in
                            Text(c.displayName).tag(c)
                        }
                    }

                    Toggle("購入日を記録する", isOn: $purchasedAtEnabled)
                    if purchasedAtEnabled {
                        DatePicker("購入日", selection: $purchasedAt, displayedComponents: .date)
                    }

                    TextField("購入場所", text: $purchasePlace)

                    TextField("価格（税込）", text: $priceText)
                        .keyboardType(.numberPad)
                }

                // MARK: - 商品写真
                Section("商品写真") {
                    HStack(spacing: 12) {
                        mainPhotoPreview
                        VStack(alignment: .leading, spacing: 10) {
                            PhotosPicker(selection: $mainPhotoItem, matching: .images) {
                                Label(mode.isEdit ? "写真を変更" : "写真を選ぶ", systemImage: "photo.on.rectangle")
                            }

                            if hasAnyMainPhoto {
                                Button(role: .destructive) {
                                    mainUIImage = nil
                                    mainPhotoItem = nil
                                    removeMain = true
                                } label: {
                                    Label("写真を削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .onChange(of: mainPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    removeMain = false
                    Task { await loadImage(from: newItem) { img in self.mainUIImage = img } }
                }

                // MARK: - サンプルカラー写真
                Section("サンプルカラー写真") {
                    HStack(spacing: 12) {
                        samplePhotoPreview
                        VStack(alignment: .leading, spacing: 10) {
                            PhotosPicker(selection: $samplePhotoItem, matching: .images) {
                                Label(mode.isEdit ? "写真を変更" : "写真を選ぶ", systemImage: "photo.on.rectangle")
                            }

                            if hasAnySamplePhoto {
                                Button(role: .destructive) {
                                    sampleUIImage = nil
                                    samplePhotoItem = nil
                                    removeSample = true
                                } label: {
                                    Label("写真を削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .onChange(of: samplePhotoItem) { _, newItem in
                    guard let newItem else { return }
                    removeSample = false
                    Task { await loadImage(from: newItem) { img in self.sampleUIImage = img } }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                loadInitialState()
            }
        }
    }

    // MARK: - Previews

    private var hasAnyMainPhoto: Bool {
        if removeMain { return false }
        if mainUIImage != nil { return true }
        if let p = mode.product, p.photoId != nil { return true }
        return false
    }

    private var hasAnySamplePhoto: Bool {
        if removeSample { return false }
        if sampleUIImage != nil { return true }
        if let p = mode.product, p.samplePhotoId != nil { return true }
        return false
    }

    private var mainPhotoPreview: some View {
        Group {
            if let img = mainUIImage {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let p = mode.product,
                      let pid = p.photoId,
                      !removeMain,
                      let img = ProductPhotoStore.loadThumbnail(photoId: pid, kind: "main") {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                placeholder(systemName: "camera")
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var samplePhotoPreview: some View {
        Group {
            if let img = sampleUIImage {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let p = mode.product,
                      let pid = p.samplePhotoId,
                      !removeSample,
                      let img = ProductPhotoStore.loadThumbnail(photoId: pid, kind: "sample") {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                placeholder(systemName: "paintpalette")
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func placeholder(systemName: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.gray.opacity(0.15))
            Image(systemName: systemName)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Load

    private func loadInitialState() {
        guard let p = mode.product else {
            // add の初期値
            name = ""
            category = .color
            purchasedAtEnabled = false
            purchasedAt = Date()
            purchasePlace = ""
            priceText = ""

            mainUIImage = nil
            mainPhotoItem = nil
            removeMain = false

            sampleUIImage = nil
            samplePhotoItem = nil
            removeSample = false
            return
        }

        // edit の初期値
        name = p.name ?? ""
        // category は CoreDataが String の想定：NailProductCategory と相互変換
        category = NailProductCategory(rawValue: (p.category ?? "")) ?? .color

        if let d = p.purchasedAt {
            purchasedAtEnabled = true
            purchasedAt = d
        } else {
            purchasedAtEnabled = false
            purchasedAt = Date()
        }

        purchasePlace = p.purchasePlace ?? ""
        priceText = p.priceYenTaxIn == 0 ? "" : "\(p.priceYenTaxIn)"

        mainUIImage = nil
        mainPhotoItem = nil
        removeMain = false

        sampleUIImage = nil
        samplePhotoItem = nil
        removeSample = false
    }

    // MARK: - Photos

    private func loadImage(from item: PhotosPickerItem, set: @escaping (UIImage) -> Void) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run { set(uiImage) }
            }
        } catch {
            print("写真読み込みエラー: \(error)")
        }
    }

    // MARK: - Save

    private func save() {
        let p: NailProduct

        switch mode {
        case .add:
            p = NailProduct(context: context)
            p.id = UUID()
            p.createdAt = Date()
        case .edit(let existing):
            p = existing
        }

        p.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.category = category.rawValue
        p.purchasedAt = purchasedAtEnabled ? purchasedAt : nil
        p.purchasePlace = purchasePlace.trimmingCharacters(in: .whitespacesAndNewlines)

        // 価格
        let price = Int32(Int(priceText) ?? 0)
        p.priceYenTaxIn = price

        p.updatedAt = Date()

        // 写真の変更適用（ファイル掃除含む）
        applyPhotoChanges(to: p)

        do {
            try context.save()
            dismiss()
        } catch {
            print("用品保存エラー: \(error)")
        }
    }

    private func applyPhotoChanges(to p: NailProduct) {
        // --- 商品写真（main / photoId） ---
        if removeMain {
            if let old = p.photoId {
                ProductPhotoStore.delete(photoId: old, kind: "main")
            }
            p.photoId = nil
        } else if let img = mainUIImage {
            if let old = p.photoId {
                ProductPhotoStore.delete(photoId: old, kind: "main")
            }
            let newId = UUID()
            ProductPhotoStore.save(image: img, photoId: newId, kind: "main")
            p.photoId = newId
        }

        // --- サンプルカラー（sample / samplePhotoId） ---
        if removeSample {
            if let old = p.samplePhotoId {
                ProductPhotoStore.delete(photoId: old, kind: "sample")
            }
            p.samplePhotoId = nil
        } else if let img = sampleUIImage {
            if let old = p.samplePhotoId {
                ProductPhotoStore.delete(photoId: old, kind: "sample")
            }
            let newId = UUID()
            ProductPhotoStore.save(image: img, photoId: newId, kind: "sample")
            p.samplePhotoId = newId
        }
    }
}
