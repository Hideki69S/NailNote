import SwiftUI
import CoreData
import PhotosUI
import UIKit

struct AddEntryView: View {
    @State private var originalFields: [String]?
    @State private var saving = false
    @State private var saveCompleted = false
    @State private var saveID = UUID()
    @State private var saveMessage: String?
    private var editFields: [String] {
        [title, String(date.timeIntervalSince1970), note, designCategory?.rawValue ?? "", colorTone?.rawValue ?? "", String(rating), selectedProductIDs.map(\.uuidString).joined(separator: ","), selectedUIImage.map { String(describing: ObjectIdentifier($0)) } ?? "", String(photoItem != nil)]
    }
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.designCardPreset) private var cardPresetRaw = GlassTheme.DesignCardPreset.ivoryGold.rawValue
    @FocusState private var focusedField: InputField?
    private enum InputField: Hashable { case title, note }
    private var palette: GlassTheme.DesignCardPalette {
        NailAppearance.designPalette(GlassTheme.designCardPalette(for: GlassTheme.DesignCardPreset(rawValue: cardPresetRaw) ?? .ivoryGold),
                                     choice: NailAppearance.Document.decode(appearanceRaw).resolved(.design))
    }

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
    @State private var showingPhotoPicker = false
    @State private var showingPhotoChangeConfirm = false
    @State private var showingPhotoDeleteConfirm = false
    @State private var photoViewer: NailPhotoPresentation?

    var body: some View {
        NavigationStack {
            GlassBackgroundView(refined: true, appearanceArea: .design) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            basicInformationCard
                            photoCard
                            card("自己評価", icon: "star") {
                                StarRatingInputView(rating: $rating)
                                    .frame(minHeight: 64).accessibilityIdentifier("addEntry.rating")
                            }
                            card("メモ", icon: "text.alignleft") { memoEditor }
                                .id(InputField.note)
                            usedItemsCard
                        }
                        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.never)
                    .onChange(of: focusedField) { _, field in
                        if field == .note {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(InputField.note, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .tint(palette.titleIcon)
            .environment(\.colorScheme, editorIsDark ? .dark : .light)
            .toolbarColorScheme(editorIsDark ? .dark : .light, for: .navigationBar)
            .navigationTitle("記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(saving)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(LinearGradient(colors: [palette.badgeStart, palette.badgeEnd], startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
                        .overlay(Capsule().stroke(palette.outerStroke.opacity(0.5), lineWidth: 0.8))
                        .accessibilityIdentifier("addEntry.save")
                        .disabled(!isBasicInfoValid || saving || saveCompleted)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("入力を完了") { focusedField = nil }
                        .frame(minHeight: 44).accessibilityIdentifier("addEntry.keyboardDone")
                }
            }
            .alert("必須項目を入力してください", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("タイトル・実施日付・デザイン・カラー系統をすべて入力してください。")
            }
            .confirmationDialog("写真を変更しますか？", isPresented: $showingPhotoChangeConfirm, titleVisibility: .visible) {
                Button("写真を変更") {
                    showingPhotoPicker = true
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(NailNoteFeatureFlags.aiEvaluationEnabled
                     ? "この写真に紐づくAIスコアはリセットされます。"
                     : "別の写真を選択します。")
            }
            .confirmationDialog("写真を削除しますか？", isPresented: $showingPhotoDeleteConfirm, titleVisibility: .visible) {
                Button("写真を削除", role: .destructive) {
                    selectedUIImage = nil
                    photoItem = nil
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(NailNoteFeatureFlags.aiEvaluationEnabled
                     ? "この写真に紐づくAIスコアはリセットされます。"
                     : "選択した写真を取り除きます。")
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { await loadImage(from: newItem) }
            }
            .modifier(NailEditorExit(dirty: !saveCompleted && (originalFields.map { $0 != editFields } ?? false), blocked: saving, onReturn: { dismiss() }))
        }
        .modifier(NailPhotoSaveFeedback(message: $saveMessage, completed: saveCompleted, retry: save, close: { dismiss() }))
        .nailPhotoViewer($photoViewer)
        .onAppear { if originalFields == nil { originalFields = editFields } }
        .modifier(NailTabExitProtection(dirty: !saveCompleted && (originalFields.map { $0 != editFields } ?? false), blocked: saving))
    }

    private var editorIsDark: Bool {
        if let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.design), choice.changesColor { return choice.dark }
        return cardPresetRaw == GlassTheme.DesignCardPreset.noirGold.rawValue || cardPresetRaw == GlassTheme.DesignCardPreset.noirSilver.rawValue
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard(contentPadding: 12,
                  strokeGradient: LinearGradient(colors: [palette.outerStrokeStart.opacity(0.9), palette.outerStrokeEnd.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing),
                  backgroundGradient: LinearGradient(colors: [palette.outerFillTop.opacity(0.94), palette.outerFillBottom.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)) {
            VStack(alignment: .leading, spacing: 7) {
                Label(title, systemImage: icon).font(.subheadline.weight(.semibold)).foregroundStyle(palette.titleIcon)
                Rectangle().fill(LinearGradient(colors: [palette.outerStrokeStart.opacity(0.7), palette.outerStrokeEnd.opacity(0.08)], startPoint: .leading, endPoint: .trailing)).frame(height: 0.6)
                content()
            }.foregroundStyle(palette.titleText)
        }
    }

    private var basicInformationCard: some View {
        card("基本情報", icon: "square.and.pencil") {
            VStack(alignment: .leading, spacing: 8) {
                inlineTitleRow.id(InputField.title)
                Divider().overlay(palette.outerStroke.opacity(0.15))
                inlineDateRow
                inlineDesignRow
                inlineColorRow
            }
            Text("※タイトル・実施日付・デザイン・カラー系統は必須です")
                .font(.caption).foregroundStyle(palette.titleText.opacity(0.7)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var photoCard: some View {
        card("写真", icon: "photo.on.rectangle") {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    focusedField = nil
                    if let page = NailPhotoPage.design(id: nil, image: selectedUIImage) { photoViewer = NailPhotoPresentation(pages: [page]) }
                } label: {
                    photoPreview.overlay(alignment: .bottomTrailing) {
                        if selectedUIImage != nil {
                            Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption2)
                                .padding(5).background(.ultraThinMaterial, in: Circle())
                        }
                    }
                }.buttonStyle(.plain).disabled(selectedUIImage == nil)
                    .accessibilityLabel("デザイン写真を拡大").accessibilityIdentifier("photo.entry.add")
                VStack(alignment: .leading, spacing: 0) {
                    Button { focusedField = nil; showingPhotoChangeConfirm = true } label: {
                        Label("写真を選ぶ", systemImage: "photo.on.rectangle").font(.subheadline).frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityIdentifier("addEntry.choosePhoto")
                    if selectedUIImage != nil {
                        Button(role: .destructive) { focusedField = nil; showingPhotoDeleteConfirm = true } label: {
                            Label("写真を外す", systemImage: "trash").font(.subheadline)
                                .foregroundStyle(palette.titleText.opacity(0.75)).frame(minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("選択した写真を外す")
                            .accessibilityHint("写真の選択を取り消します")
                            .accessibilityIdentifier("addEntry.removePhoto")
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var memoEditor: some View {
        TextEditor(text: $note).font(.body).foregroundStyle(palette.titleText)
            .scrollContentBackground(.hidden).padding(6)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 180 : 132)
            .background(palette.glowFillMid.opacity(0.32), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.outerStroke.opacity(0.25), lineWidth: 0.6))
            .focused($focusedField, equals: .note).accessibilityLabel("メモ").accessibilityIdentifier("addEntry.note")
    }

    private var usedItemsCard: some View {
        card("使用したアイテム", icon: "square.stack") {
            if products.isEmpty {
                Text("アイテムがまだ登録されていません").font(.subheadline).foregroundStyle(palette.titleText.opacity(0.7))
                    .frame(minHeight: 44)
            } else {
                CategoryTabBar(selected: $selectedCategory, palette: palette)
                if filteredProducts.isEmpty {
                    Text("このカテゴリのアイテムがありません").font(.subheadline).frame(minHeight: 44)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredProducts, id: \.objectID) { product in
                            Button { focusedField = nil; toggle(product) } label: {
                                SelectableProductRow(product: product, isSelected: isSelected(product), palette: palette)
                                    .frame(minHeight: 52).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("addEntry.item." + (product.id?.uuidString ?? "unknown"))
                                .accessibilityValue(isSelected(product) ? "選択中" : "未選択")
                        }
                    }
                }
            }
            if !selectedProductIDs.isEmpty {
                Divider()
                Label("選択済み（順番）", systemImage: "list.number").font(.subheadline.weight(.semibold)).foregroundStyle(palette.titleIcon)
                LazyVStack(spacing: 8) {
                    ForEach(selectedProductIDs, id: \.self) { pid in
                        if let p = product(for: pid) { SelectedProductRow(product: p, palette: palette).frame(minHeight: 52) }
                    }
                }
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

    @ViewBuilder private func adaptiveRow<LabelView: View, Value: View>(@ViewBuilder label: () -> LabelView, @ViewBuilder value: () -> Value) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) { label(); value() }.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 8) { label(); Spacer(minLength: 4); value() }.frame(minHeight: 44)
        }
    }

    private var inlineDateRow: some View {
        adaptiveRow { requiredFieldLabel("実施日付") } value: {
            DatePicker("実施日付", selection: $date, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
                .labelsHidden().datePickerStyle(.compact)
        }
    }

    private var inlineDesignRow: some View {
        adaptiveRow { requiredFieldLabel("デザイン") } value: {
            Picker("デザイン", selection: $designCategory) {
                Text("選択なし").tag(NailDesignCategory?.none)
                ForEach(NailDesignCategory.allCases) { category in Text(category.displayName).tag(Optional(category)) }
            }.pickerStyle(.menu).labelsHidden().accessibilityIdentifier("addEntry.design")
        }
    }

    private var inlineColorRow: some View {
        adaptiveRow { requiredFieldLabel("カラー系統") } value: {
            Picker("カラー系統", selection: $colorTone) {
                Text("選択なし").tag(NailColorTone?.none)
                ForEach(NailColorTone.allCases) { tone in Text(tone.displayName).tag(Optional(tone)) }
            }.pickerStyle(.menu).labelsHidden().accessibilityIdentifier("addEntry.color")
        }
    }

    private var inlineTitleRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            requiredFieldLabel("タイトル")
            TextField("例：春ネイル / オフのみ など", text: $title)
                .textInputAutocapitalization(.sentences).padding(10).frame(minHeight: 44)
                .background(palette.glowFillMid.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.outerStroke.opacity(0.25), lineWidth: 0.6))
                .focused($focusedField, equals: .title).accessibilityIdentifier("addEntry.title")
        }
    }

    private func requiredFieldLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.subheadline.weight(.medium))
            Text("必須").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 3)
                .background(palette.outerStrokeStart.opacity(0.18), in: Capsule()).foregroundStyle(palette.titleIcon)
        }.fixedSize(horizontal: false, vertical: true)
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
                        .fill(palette.glowFillMid.opacity(0.4))
                    VStack(spacing: 5) { Image(systemName: "photo"); Text("写真なし").font(.caption) }
                        .foregroundStyle(palette.titleText.opacity(0.65))
                }
            }
        }
        .frame(width: 90, height: 90)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(palette.outerStroke.opacity(0.5), lineWidth: 0.8))
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
        guard !saving, !saveCompleted else { return }
        guard isBasicInfoValid else { showValidationAlert = true; return }
        let input = PhotoSaveTransaction.EntryInput(target: .create(saveID), title: trimmedTitle, date: date,
            note: note, category: designCategory?.rawValue, color: colorTone?.rawValue, rating: rating,
            products: selectedProductIDs, photo: selectedUIImage.map { .replace($0) } ?? .keep)
        saving = true
        Task { @MainActor in
            await Task.yield()
            defer { saving = false }
            do {
                let result = try PhotoSaveTransaction.saveEntry(input, in: viewContext)
                saveCompleted = true
                if let warning = result.cleanupWarning { saveMessage = warning } else { dismiss() }
            } catch { saveMessage = error.localizedDescription }
        }
    }
}

// MARK: - Product Selection UI

private struct CategoryTabBar: View {
    @Binding var selected: NailProductCategory
    let palette: GlassTheme.DesignCardPalette

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
                            .frame(minHeight: 44)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(selected == category ? palette.badgeEnd
                                                              : palette.glowFillMid.opacity(0.4))
                            )
                            .foregroundStyle(palette.titleText)
                            .overlay(Capsule().stroke(palette.outerStroke.opacity(selected == category ? 0.7 : 0.25), lineWidth: 0.7))
                    }.buttonStyle(.plain).accessibilityValue(selected == category ? "選択中" : "未選択")
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SelectableProductRow: View {
    let product: NailProduct
    let isSelected: Bool
    let palette: GlassTheme.DesignCardPalette

    var body: some View {
        HStack(spacing: 12) {
            ProductThumb(photoId: product.photoId)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.titleText)
                    .lineLimit(2)

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
                .foregroundStyle(isSelected ? palette.titleIcon : palette.titleText.opacity(0.6))
        }
    }

    private var displayName: String {
        let name = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（名称未設定）" : name
    }
}

private struct SelectedProductRow: View {
    let product: NailProduct
    let palette: GlassTheme.DesignCardPalette

    var body: some View {
        HStack(spacing: 12) {
            ProductThumb(photoId: product.photoId)
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.titleText)
                    .lineLimit(2)
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

// 保存失敗は入力を保持して再試行可能にする。後片付けの警告は保存成功と区別する。
struct NailPhotoSaveFeedback: ViewModifier {
    @Binding var message: String?
    let completed: Bool
    let retry: () -> Void
    let close: () -> Void
    func body(content: Content) -> some View {
        content.background {
            Color.clear.alert(completed ? "保存は完了しました" : "保存できませんでした", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                if completed {
                    Button("一覧へ戻る") { message = nil; close() }
                } else {
                    Button("再試行") { message = nil; retry() }
                    Button("編集を続ける", role: .cancel) { message = nil }
                }
            } message: { Text(message ?? "") }
        }
    }
}
