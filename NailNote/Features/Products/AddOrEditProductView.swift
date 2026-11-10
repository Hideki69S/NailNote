import SwiftUI
import CoreData
import PhotosUI
import UIKit

struct AddOrEditProductView: View {
    @State private var originalFields: [String]?
    @State private var saving = false
    @State private var saveCompleted = false
    @State private var saveID = UUID()
    @State private var saveMessage: String?
    @State private var photoSaveVersion: PhotoSaveTransaction.Version?
    private var editFields: [String] {
        [name, category.rawValue, String(purchasedAt.timeIntervalSince1970), purchasePlace, priceText, productURLText, mainUIImage.map { String(describing: ObjectIdentifier($0)) } ?? "", sampleUIImage.map { String(describing: ObjectIdentifier($0)) } ?? "", String(removeMain), String(removeSample), String(mainPhotoItem != nil), String(samplePhotoItem != nil)]
    }
    enum Mode {
        case add
        case edit(NailProduct)

        var title: String {
            switch self {
            case .add: return "アイテムを追加"
            case .edit: return "アイテムを編集"
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
    @State private var showingMainPhotoPicker: Bool = false

    // 写真（サンプルカラー）
    @State private var samplePhotoItem: PhotosPickerItem?
    @State private var sampleUIImage: UIImage?
    @State private var removeSample: Bool = false
    @State private var showingSamplePhotoPicker: Bool = false
    @State private var photoViewer: NailPhotoPresentation?
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
                    HStack(spacing: 8) {
                        Text("商品名")
                        RequiredBadge()
                        Spacer()
                        TextField("必須", text: $name)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack(spacing: 8) {
                        Text("カテゴリ")
                        RequiredBadge()
                        Spacer()
                        Picker("", selection: $category) {
                            ForEach(NailProductCategory.allCases) { c in
                                Text(c.displayName).tag(c)
                            }
                        }
                        .labelsHidden()
                    }

                    DatePicker("購入日", selection: $purchasedAt, displayedComponents: .date)
                        .environment(\.calendar, Self.gregorianCalendar)
                        .environment(\.locale, Self.japaneseLocale)

                    ShopSelectionField(title: "購入場所", options: shopOptions, selection: $purchasePlace)

                    HStack {
                        Text("商品ページURL")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        TextField("未入力", text: $productURLText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }

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
                        Button { openPhoto(sample: false) } label: { mainPhotoPreview }
                            .buttonStyle(.borderless).disabled(!hasAnyMainPhoto)
                            .accessibilityLabel("商品写真を拡大").accessibilityIdentifier("photo.product.main")
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                showingMainPhotoPicker = true
                            } label: {
                                Label(mode.isEdit ? "写真を変更" : "写真を選ぶ", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.borderless)

                            if hasAnyMainPhoto {
                                Button(role: .destructive) {
                                    mainUIImage = nil
                                    mainPhotoItem = nil
                                    removeMain = true
                                } label: {
                                    Label("写真を削除", systemImage: "trash")
                                }
                                .buttonStyle(.borderless)
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
                        Button { openPhoto(sample: true) } label: { samplePhotoPreview }
                            .buttonStyle(.borderless).disabled(!hasAnySamplePhoto)
                            .accessibilityLabel("サンプル写真を拡大").accessibilityIdentifier("photo.product.sample")
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                showingSamplePhotoPicker = true
                            } label: {
                                Label(mode.isEdit ? "写真を変更" : "写真を選ぶ", systemImage: "photo.on.rectangle")
                            }
                            .buttonStyle(.borderless)

                            if hasAnySamplePhoto {
                                Button(role: .destructive) {
                                    sampleUIImage = nil
                                    samplePhotoItem = nil
                                    removeSample = true
                                } label: {
                                    Label("写真を削除", systemImage: "trash")
                                }
                                .buttonStyle(.borderless)
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
            .disabled(saving)
            .modifier(NailPhotoSaveFeedback(message: $saveMessage, completed: saveCompleted, retry: save, close: { dismiss() }))
            .photosPicker(isPresented: $showingMainPhotoPicker, selection: $mainPhotoItem, matching: .images)
            .photosPicker(isPresented: $showingSamplePhotoPicker, selection: $samplePhotoItem, matching: .images)
            .nailPhotoViewer($photoViewer)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving || saveCompleted)
                }
            }
            .onAppear {
                if originalFields == nil { loadInitialState(); originalFields = editFields; photoSaveVersion = mode.product.map { PhotoSaveTransaction.version($0) } }
            }
            .modifier(NailEditorExit(dirty: !saveCompleted && (originalFields.map { $0 != editFields } ?? false), blocked: saving, onReturn: { dismiss() }))
        }
        .modifier(NailTabExitProtection(dirty: !saveCompleted && (originalFields.map { $0 != editFields } ?? false), blocked: saving))
    }

    // MARK: - Previews

    private func openPhoto(sample: Bool) {
        let main = NailPhotoPage.product(id: mode.product?.photoId, image: mainUIImage, sample: false, removed: removeMain)
        let samplePage = NailPhotoPage.product(id: mode.product?.samplePhotoId, image: sampleUIImage, sample: true, removed: removeSample)
        let pages = [main, samplePage].compactMap { $0 }
        guard !pages.isEmpty else { return }
        photoViewer = NailPhotoPresentation(pages: pages, initialIndex: sample && main != nil ? 1 : 0)
    }

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

        purchasedAt = p.purchasedAt ?? Date()

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
        guard !saving, !saveCompleted else { return }
        let target: PhotoSaveTransaction.Target
        switch mode {
        case .add: target = .create(saveID)
        case .edit(let product):
            guard let version = photoSaveVersion else { saveMessage = PhotoSaveTransaction.Failure.conflict.localizedDescription; return }
            target = .edit(product.objectID, version)
        }
        let url = productURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = PhotoSaveTransaction.ProductInput(target: target, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.rawValue, purchasedAt: purchasedAt, place: purchasePlace.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url.isEmpty ? nil : url, price: Int32(Int(priceText) ?? 0),
            main: removeMain ? .remove : (mainUIImage.map { .replace($0) } ?? .keep),
            sample: removeSample ? .remove : (sampleUIImage.map { .replace($0) } ?? .keep))
        saving = true
        Task { @MainActor in
            await Task.yield()
            defer { saving = false }
            do {
                let result = try PhotoSaveTransaction.saveProduct(input, in: context)
                saveCompleted = true
                if let warning = result.cleanupWarning { saveMessage = warning } else { dismiss() }
            } catch { saveMessage = error.localizedDescription }
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

private struct RequiredBadge: View {
    var body: some View {
        Text("必須")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.12))
            .foregroundStyle(Color.red)
            .clipShape(Capsule())
    }
}

private struct ShopSelectionField: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    @State private var isAddingCustom = false
    @State private var customName: String = ""
    @State private var addedOptions: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                Button {
                    selection = ""
                } label: {
                    labelRow(title: "未選択", isSelected: selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ForEach(availableOptions, id: \.self) { shop in
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
            .tint(.primary)
            .buttonStyle(.plain)

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
                            let shop = availableOptions.first {
                                $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
                            } ?? trimmed
                            if !availableOptions.contains(shop) {
                                addedOptions.append(shop)
                            }
                            selection = shop
                            customName = ""
                            isAddingCustom = false
                        }
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    // Formの行全体で両ボタンが実行されるのを防ぐ。
                    .buttonStyle(.borderless)
                }
                .padding(.top, 4)
            }
        }
    }

    private var availableOptions: [String] {
        let names = (options + addedOptions + [selection])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(names)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
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
