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
            case .add: return "所持ネイルアイテムを追加"
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
    @State private var productURLText: String = ""
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NailProduct.purchasePlace, ascending: true)],
        animation: .default
    )
    private var existingProducts: FetchedResults<NailProduct>

    // 写真（商品）
    @State private var mainPhotoItem: PhotosPickerItem?
    @State private var mainUIImage: UIImage?
    @State private var removeMain: Bool = false

    // 写真（サンプルカラー）
    @State private var samplePhotoItem: PhotosPickerItem?
    @State private var sampleUIImage: UIImage?
    @State private var removeSample: Bool = false
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    private static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }()
    private static let japaneseLocale = Locale(identifier: "ja_JP")

    var body: some View {
        NavigationStack {
            GlassBackgroundView {
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
                        .environment(\.calendar, Self.gregorianCalendar)
                        .environment(\.locale, Self.japaneseLocale)
                    }

                    ShopSelectionField(title: "購入場所", options: shopOptions, selection: $purchasePlace)

                    TextField("商品ページURL（任意）", text: $productURLText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    if linkURL != nil || shareItem != nil {
                        HStack(spacing: 12) {
                            if let linkURL {
                                Link(destination: linkURL) {
                                    Label("開く", systemImage: "safari")
                                }
                            }
                            if let shareItem {
                                ShareLink(item: shareItem) {
                                    Label("共有", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    }

                    HStack {
                        Text("購入金額")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("¥0", text: formattedPriceBinding)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
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
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
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
            productURLText = ""

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
        productURLText = p.productUrl ?? ""

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
        let trimmedURL = productURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        p.productUrl = trimmedURL.isEmpty ? nil : trimmedURL

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

    private var shopOptions: [String] {
        let rawValues = existingProducts.compactMap { product -> String? in
            guard let place = product.purchasePlace?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !place.isEmpty else { return nil }
            return place
        }
        return Array(Set(rawValues)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var linkURL: URL? {
        let trimmed = productURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(trimmed)")
    }

    private var shareItem: URL? {
        let trimmed = productURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed) {
            return url
        } else if let fallback = URL(string: "https://\(trimmed)") {
            return fallback
        }
        return nil
    }

    private var formattedPriceBinding: Binding<String> {
        Binding<String>(
            get: { formattedPriceFieldText },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                priceText = digits
            }
        )
    }

    private var formattedPriceFieldText: String {
        guard let value = Int(priceText),
              let formatted = Self.currencyFormatter.string(from: NSNumber(value: value)) else {
            return ""
        }
        return "¥\(formatted)"
    }
}

private struct ShopSelectionField: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    @State private var isAddingCustom = false
    @State private var customName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                Button {
                    selection = ""
                } label: {
                    labelRow(title: "未選択", isSelected: selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ForEach(options, id: \.self) { shop in
                    Button {
                        selection = shop
                        isAddingCustom = false
                    } label: {
                        labelRow(title: shop, isSelected: selection == shop)
                    }
                }

                Divider()

                Button {
                    customName = ""
                    isAddingCustom = true
                } label: {
                    Label("新規追加", systemImage: "plus.circle")
                }
            } label: {
                HStack {
                    Text(title)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectionDisplayTitle)
                        .foregroundStyle(selection.isEmpty ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }
            }

            if isAddingCustom {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("ショップ名を入力", text: $customName)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    HStack {
                        Button("キャンセル", role: .cancel) {
                            isAddingCustom = false
                            customName = ""
                        }
                        Spacer()
                        Button("追加") {
                            let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            selection = trimmed
                            customName = ""
                            isAddingCustom = false
                        }
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var selectionDisplayTitle: String {
        let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未選択" : trimmed
    }

    @ViewBuilder
    private func labelRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}
