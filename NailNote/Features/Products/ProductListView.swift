import SwiftUI
import CoreData
import Combine

struct ProductListView: View {
    @Environment(\.nailTabResetID) private var tabResetID
    var bottomNavigationTop: CGFloat? = nil
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \NailProduct.category, ascending: true),
            NSSortDescriptor(keyPath: \NailProduct.updatedAt, ascending: false)
        ],
        animation: .default
    )
    private var products: FetchedResults<NailProduct>

    @StateObject private var deletion = NailDeletionController()
    @State private var selectingForDeletion = false
    @State private var deletionSelection: Set<NSManagedObjectID> = []
    @State private var showingAddSheet = false
    @State private var editingProduct: NailProduct?
    @State private var photoViewer: NailPhotoPresentation?
    @State private var selectedCategories = NailProductCategorySelection()
    @State private var shopFilterText: String = ""
    @State private var keywordFilterText: String = ""
    @AppStorage("FavoriteProductIDs") private var favoriteIDsRaw: String = ""
    @AppStorage("ProductsShowFavoritesOnly") private var showFavoritesOnly: Bool = false

    var body: some View {
        NavigationStack {
            GlassBackgroundView(appearanceArea: .items) {
                GeometryReader { page in
                VStack(spacing: 10) {
                    if dynamicTypeSize.isAccessibilitySize {
                        // 大きな文字でも全ボタンへ到達できるよう、上部だけを縦にスクロールする。
                        ScrollView(.vertical) {
                            productHeader
                        }
                        .frame(maxHeight: page.size.height * 0.65)
                    } else {
                        productHeader
                    }

                    GeometryReader { proxy in
                        // デザイン一覧と同じ境界で、バー背後のカードへのタップを防ぐ。
                        let availableHeight = bottomNavigationTop.map {
                            max(0, min(proxy.size.height, $0 - proxy.frame(in: .global).minY))
                        } ?? proxy.size.height
                        productList
                            .contentMargins(.bottom, max(0, proxy.size.height - availableHeight), for: .scrollContent)
                            .frame(height: availableHeight)
                            .clipped()
                            .contentShape(Rectangle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .bottomTrailing) {
                    NailFloatingAddButton(accessibilityLabel: "アイテムを追加") {
                        showingAddSheet = true
                    }
                }
                }
            }
        }
        .nailPhotoViewer($photoViewer)
        .modifier(NailTabStackReset())
        .onChange(of: tabResetID) { _, _ in showingAddSheet = false; editingProduct = nil; photoViewer = nil; deletion.cancel(); selectingForDeletion = false; deletionSelection = [] }
        .onChange(of: deletion.completed) { _, _ in selectingForDeletion = false; deletionSelection = [] }
        .modifier(NailDeletionDialogs(deletion: deletion, context: context))
        .modifier(NailAppearanceEnvironment(area: .items))
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

    // MARK: - Filtering

    private var filteredProducts: [NailProduct] {
        products.filter { product in
            matchesCategory(product) &&
            matchesShop(product) &&
            matchesKeyword(product) &&
            matchesFavoriteFilter(product)
        }
    }

    private func category(for product: NailProduct) -> NailProductCategory {
        let raw = (product.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = raw.isEmpty ? "other" : raw
        return NailProductCategory(rawValue: normalized) ?? .other
    }

    private func selectOrEdit(_ product: NailProduct) {
        guard !deletion.working else { return }
        if selectingForDeletion {
            if !deletionSelection.insert(product.objectID).inserted { deletionSelection.remove(product.objectID) }
        } else { editingProduct = product }
    }

    // MARK: - Delete

    private func deleteSelectedProducts(at offsets: IndexSet) {
        let items = filteredProducts
        let ids = offsets.compactMap { items.indices.contains($0) ? items[$0].objectID : nil }
        deletion.request(.items, ids: ids, in: context)
    }

}

private extension ProductListView {
    var productList: some View {
        List {
            if filteredProducts.isEmpty {
                ContentUnavailableView("該当するアイテムがありません", systemImage: "cube.box")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(Array(filteredProducts.enumerated()), id: \.element.objectID) { index, product in
                    HStack(spacing: 0) {
                        if selectingForDeletion {
                            Button { selectOrEdit(product) } label: {
                                Image(systemName: deletionSelection.contains(product.objectID) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(Color.accentColor).frame(width: 44, height: 44)
                            }.buttonStyle(.borderless).accessibilityLabel("削除対象の選択を切り替える")
                        }
                        Spacer(minLength: 0)
                        ProductRow(product: product, cardIndex: index, isFavorite: isFavorite(product),
                                   toggleFavorite: { toggleFavorite(product) }, onOpen: { selectOrEdit(product) },
                                   onPhoto: {
                            guard !deletion.working else { return }
                            if selectingForDeletion { selectOrEdit(product); return }
                            let pages = [NailPhotoPage.product(id: product.photoId, sample: false),
                                         NailPhotoPage.product(id: product.samplePhotoId, sample: true)].compactMap { $0 }
                            guard !pages.isEmpty else { return }
                            photoViewer = NailPhotoPresentation(pages: pages)
                        })
                        Spacer(minLength: 0)
                    }
                    .accessibilityValue(selectingForDeletion ? (deletionSelection.contains(product.objectID) ? "削除対象に選択中" : "未選択") : "")
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteSelectedProducts)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 0)
    }
}

// MARK: - Row

private struct ProductRow: View {
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    let product: NailProduct
    let cardIndex: Int
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    let onOpen: () -> Void
    let onPhoto: () -> Void
    @AppStorage(GlassTheme.Keys.itemCardPreset) private var itemCardPresetRaw: String = GlassTheme.ItemCardPreset.roseChampagne.rawValue
    private let textInset: CGFloat = 8
    private let mediaShiftLeft: CGFloat = 6
    private var palette: GlassTheme.ItemCardPalette {
        let preset = GlassTheme.ItemCardPreset(rawValue: itemCardPresetRaw) ?? .roseChampagne
        return NailAppearance.itemPalette(GlassTheme.itemCardPalette(for: preset, variantIndex: cardIndex), choice: NailAppearance.Document.decode(appearanceRaw).resolved(.items))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ","
        return formatter
    }()

    var body: some View {
        GlassCard(
            maxWidth: GlassTheme.listCardWidth,
            contentPadding: 9,
            strokeColor: palette.outerStroke,
            strokeGradient: LinearGradient(
                colors: [palette.outerStrokeStart, palette.outerStrokeEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            backgroundGradient: LinearGradient(
                colors: [palette.outerFillTop, palette.outerFillBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            ZStack {
                ItemCardToneLayer(palette: palette)
                VStack(alignment: .leading, spacing: 16) {
                    // 上段：用品名
                    Text(displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, textInset)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    // 下段：左・中央・右ブロック
                    HStack(alignment: .bottom, spacing: 16) {
                        // 左：購入情報
                        VStack(alignment: .leading, spacing: 8) {
                            ProductInfoTag(title: "[購入情報]", systemImage: "cart")

                            Text(purchasedAtDisplayText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(placeDisplayText)
                                .font(.subheadline)
                                .foregroundStyle(hasPlace ? Color.secondary : Color.secondary.opacity(0.6))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Text(priceDisplayText)
                                .font(.subheadline)
                                .foregroundStyle(hasPrice ? Color.secondary : Color.secondary.opacity(0.6))
                        }
                        .padding(.leading, textInset)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // 中央：使用回数リング
                        UsageCountRing(count: usageCount)
                            .frame(width: 82, height: 82)
                            .frame(maxWidth: .infinity)
                            .offset(x: -mediaShiftLeft)

                        // 右：写真＋お気に入り
                        ZStack(alignment: .topTrailing) {
                            photoThumbnail

                            FavoriteButton(isFavorite: isFavorite, action: toggleFavorite)
                                .offset(x: 6, y: -6)
                        }
                        .offset(x: -mediaShiftLeft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    Button(action: onOpen) { Color.clear.contentShape(Rectangle()) }
                        .buttonStyle(.borderless).accessibilityLabel("アイテムを編集、\(displayName)")
                        .accessibilityIdentifier("product.row." + (product.id?.uuidString ?? "unknown"))
                }
            }
        }
    }

    private var formattedPrice: String? {
        guard product.priceYenTaxIn > 0 else { return nil }
        let value = NSNumber(value: product.priceYenTaxIn)
        let formatted = Self.priceFormatter.string(from: value) ?? "\(product.priceYenTaxIn)"
        return "¥\(formatted)"
    }

    @ViewBuilder private var photoThumbnail: some View {
        if product.photoId != nil || product.samplePhotoId != nil {
            Button(action: onPhoto) {
                ProductThumbnail(photoId: product.photoId ?? product.samplePhotoId, size: 92)
                    .frame(width: 92, height: 92)
            }.buttonStyle(.borderless).accessibilityLabel("アイテム写真を拡大")
                .accessibilityIdentifier("photo.product." + (product.id?.uuidString ?? "unknown"))
        } else {
            ProductThumbnail(photoId: nil, size: 92).frame(width: 92, height: 92)
                .accessibilityLabel("写真なし")
        }
    }

    private var placeText: String? {
        guard let place = product.purchasePlace?.trimmingCharacters(in: .whitespacesAndNewlines),
              !place.isEmpty else { return nil }
        return place
    }

    private var displayName: String {
        let name = (product.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "（名称未設定）" : name
    }

    private var purchasedAtDisplayText: String {
        if let purchasedAt = product.purchasedAt {
            return Self.dateFormatter.string(from: purchasedAt)
        } else {
            return "購入日未設定"
        }
    }

    private var placeDisplayText: String {
        placeText ?? "ショップ未設定"
    }

    private var priceDisplayText: String {
        formattedPrice ?? "金額未設定"
    }

    private var hasPlace: Bool {
        placeText != nil
    }

    private var hasPrice: Bool {
        formattedPrice != nil
    }

    private var usageCount: Int {
        if let ordered = product.usedInEntries as? Set<NailEntryUsedItem> {
            return ordered.count
        } else if let objects = product.usedInEntries?.allObjects {
            return objects.count
        }
        return 0
    }

    // Share/Link buttons are shown only in the registration/editing screen.
}

private struct ItemCardToneLayer: View {
    let palette: GlassTheme.ItemCardPalette

    var body: some View {
        RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius - 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [palette.fillTop, palette.fillBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius - 4, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [palette.strokeStart, palette.strokeEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius - 6, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.7)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
            .padding(.horizontal, -2)
            .padding(.vertical, -4)
            .allowsHitTesting(false)
    }
}

// MARK: - Thumbnail

private struct ProductThumbnail: View {
    let photoId: UUID?
    var size: CGFloat = 52
    private var cornerRadius: CGFloat { size * 0.27 }

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
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(GlassTheme.cardStroke, lineWidth: 1)
        )
    }
}

// MARK: - Category Tab Bar

private struct CategoryTabBar: View {
    @Environment(\.dynamicTypeSize) private var categoryTypeSize
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    @AppStorage(GlassTheme.Keys.itemCardPreset) private var itemPresetRaw = GlassTheme.ItemCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
        let preset = GlassTheme.DesignCardPreset(rawValue: itemPresetRaw) ?? .roseChampagne
        return NailAppearance.designPalette(GlassTheme.designCardPalette(for: preset), choice: NailAppearance.Document.decode(appearanceRaw).resolved(.items))
    }
    private var isDark: Bool {
        if let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.items), choice.changesColor {
            return choice.dark
        }
        return itemPresetRaw == GlassTheme.ItemCardPreset.noirGold.rawValue || itemPresetRaw == GlassTheme.ItemCardPreset.noirSilver.rawValue
    }

    // 領域別設定を解決した既存パレットのアクセントから、濃い同系色を作る。
    private var selectedColors: [Color] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let accent = UIColor(palette.outerStrokeEnd)
        if !accent.getRed(&r, green: &g, blue: &b, alpha: &a) {
            UIColor(palette.titleIcon).getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        let ink = NailAppearance.RGB(r: 0.04, g: 0.04, b: 0.05)
        var base = NailAppearance.RGB(r: Double(r), g: Double(g), b: Double(b)).mixed(with: ink, amount: 0.25)
        func luminance(_ value: NailAppearance.RGB) -> Double {
            func linear(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(value.r) + 0.7152 * linear(value.g) + 0.0722 * linear(value.b)
        }
        // 明るい自由色でも白文字との明暗差を確保する。保存色そのものは変更しない。
        while luminance(base) > 0.15 { base = base.mixed(with: ink, amount: 0.10) }
        return [base.color, base.mixed(with: ink, amount: 0.20).color]
    }

    @Binding var selected: NailProductCategorySelection

    var body: some View {
        let selectedFill = selectedColors
        ProductCategoryGridLayout(columns: categoryTypeSize.isAccessibilitySize ? 2 : 4) {
                ForEach(NailProductCategoryFilter.allCases) { category in
                    let isSelected = selected.isSelected(category)
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selected.toggle(category)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                .frame(width: 10).opacity(isSelected ? 1 : 0).accessibilityHidden(true)
                            ZStack {
                                Text(category.buttonTitle).font(.footnote.weight(.semibold)).hidden().accessibilityHidden(true)
                                Text(category.buttonTitle).font(.footnote.weight(isSelected ? .semibold : .regular))
                            }
                        }
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                            .frame(minHeight: 34)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                Capsule()
                                    .fill(LinearGradient(colors: isSelected ? selectedFill : [palette.glowFillTop.opacity(isDark ? 0.85 : 0.45), palette.glowFillBottom.opacity(isDark ? 0.75 : 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .overlay(Capsule().strokeBorder(isSelected ? palette.outerStrokeStart : palette.outerStrokeEnd.opacity(0.30), lineWidth: isSelected ? 1 : 0.6))
                                    .shadow(color: palette.outerStrokeEnd.opacity(isSelected ? 0.12 : 0.03), radius: 2, x: 0, y: 1)
                            )
                            .foregroundStyle(isSelected ? Color.white : palette.titleText.opacity(isDark ? 0.90 : 0.78))
                            // 見える面は34pt、操作面は上下5ptずつ広げて44pt以上にする。
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityValue(isSelected ? "オン" : "オフ")
                    .accessibilityIdentifier("product.category.\(category.rawValue)")
                }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 通常は4列、文字拡大時は2列で、全セルへ文字が収まる共通の自然高を提案する。
private struct ProductCategoryGridLayout: Layout {
    var columns = 4
    private let spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let cellWidth = max(0, (width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let height = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height
        }.max() ?? 44
        let rows = (subviews.count + columns - 1) / columns
        return CGSize(width: width, height: max(44, height) * CGFloat(rows) + spacing * CGFloat(max(0, rows - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = max(1, (subviews.count + columns - 1) / columns)
        let width = max(0, (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let height = max(44, (bounds.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + CGFloat(index % columns) * (width + spacing),
                                     y: bounds.minY + CGFloat(index / columns) * (height + spacing)),
                          anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height))
        }
    }
}

// MARK: - Filters & Floating Button

private extension ProductListView {
    var productHeader: some View {
        VStack(spacing: 10) {
            NailDesignAdPlaceholderRow(appearanceArea: .items)
                .padding(.top, 12)
                .padding(.horizontal, 16)
            VStack(spacing: 8) {
                filterControls
                CategoryTabBar(selected: $selectedCategories)
                HStack {
                    Button(selectingForDeletion ? "選択をキャンセル" : "選択して削除") {
                        selectingForDeletion.toggle(); deletionSelection = []
                    }.frame(minHeight: 44).accessibilityIdentifier("product.delete.selection")
                    Spacer(minLength: 4)
                    if selectingForDeletion {
                        Button("\(deletionSelection.count)件を削除", role: .destructive) {
                            deletion.request(.items, ids: deletionSelection.sorted { $0.uriRepresentation().absoluteString < $1.uriRepresentation().absoluteString }, in: context)
                        }
                        .frame(minHeight: 44).disabled(deletionSelection.isEmpty)
                        .accessibilityIdentifier("product.delete.selected")
                    }
                }.font(.subheadline)
            }
            .padding(.horizontal, 16)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    var filterControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("フィルタ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Text("❤️お気に入りのみ")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Toggle("", isOn: $showFavoritesOnly)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                        .scaleEffect(0.72)
                }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 10) {
                ShopFilterMenu(
                    title: shopFilterTitle,
                    options: shopOptions,
                    selection: $shopFilterText
                )
                StyledFilterField(title: "キーワード", systemImage: "text.magnifyingglass", text: $keywordFilterText)
            }
        }
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
    }

    func matchesCategory(_ product: NailProduct) -> Bool {
        selectedCategories.matches(category(for: product))
    }

    var shopOptions: [String] {
        let rawValues = products.compactMap { product -> String? in
            guard let place = product.purchasePlace?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !place.isEmpty else { return nil }
            return place
        }
        return Array(Set(rawValues)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var shopFilterTitle: String {
        let trimmed = shopFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "SHOP" : trimmed
    }

    func matchesShop(_ product: NailProduct) -> Bool {
        let query = shopFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let place = (product.purchasePlace ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return place == query
    }

    func matchesKeyword(_ product: NailProduct) -> Bool {
        let query = keywordFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let name = (product.name ?? "").lowercased()
        let place = (product.purchasePlace ?? "").lowercased()
        return name.contains(query.lowercased()) || place.contains(query.lowercased())
    }

    func matchesFavoriteFilter(_ product: NailProduct) -> Bool {
        guard showFavoritesOnly else { return true }
        return isFavorite(product)
    }

    private var favoriteIDs: Set<UUID> {
        get {
            let components = favoriteIDsRaw.split(separator: ",")
            let ids = components.compactMap { UUID(uuidString: String($0)) }
            return Set(ids)
        }
        nonmutating set {
            let list = newValue.map { $0.uuidString }.sorted()
            favoriteIDsRaw = list.joined(separator: ",")
        }
    }

    private func isFavorite(_ product: NailProduct) -> Bool {
        guard let id = product.id else { return false }
        return favoriteIDs.contains(id)
    }

    private func toggleFavorite(_ product: NailProduct) {
        guard let id = product.id else { return }
        var ids = favoriteIDs
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        favoriteIDs = ids
    }
}


private struct StyledFilterField: View {
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    private var customPalette: GlassTheme.DesignCardPalette? {
        guard let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.items), choice.changesColor else { return nil }
        return NailAppearance.designPalette(GlassTheme.designCardPalette(for: .roseChampagne), choice: choice)
    }

    let title: String
    let systemImage: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)

            NailCenteredFilterTextField(title: title, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .modifier(NailFilterControlLayout())
        .background(customPalette?.glowFillMid ?? Color.white)
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

private struct ShopFilterMenu: View {
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""
    private var customPalette: GlassTheme.DesignCardPalette? {
        guard let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.items), choice.changesColor else { return nil }
        return NailAppearance.designPalette(GlassTheme.designCardPalette(for: .roseChampagne), choice: choice)
    }

    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        Menu {
            Button {
                selection = ""
            } label: {
                labelRow(title: "すべて", isSelected: selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(options, id: \.self) { shop in
                Button {
                    selection = shop
                } label: {
                    labelRow(title: shop, isSelected: selection == shop)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "storefront")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .modifier(NailFilterControlLayout())
            .background(customPalette?.glowFillMid ?? Color.white)
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .accessibilityLabel("SHOP絞り込み")
    }

    private func labelRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

private struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                .padding(6)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "お気に入り解除" : "お気に入りに追加")
    }
}

private struct ProductInfoTag: View {
    let title: String
    let systemImage: String
    @AppStorage(GlassTheme.Keys.itemCardPreset) private var itemCardPresetRaw: String = GlassTheme.ItemCardPreset.roseChampagne.rawValue
    @AppStorage(NailAppearance.key) private var appearanceRaw = ""

    private var custom: GlassTheme.DesignCardPalette? {
        guard let choice = NailAppearance.Document.decode(appearanceRaw).resolved(.items), choice.changesColor else { return nil }
        return NailAppearance.designPalette(GlassTheme.designCardPalette(for: .roseChampagne), choice: choice)
    }

    private var palette: GlassTheme.ItemCardPalette {
        let preset = GlassTheme.ItemCardPreset(rawValue: itemCardPresetRaw) ?? .roseChampagne
        return GlassTheme.itemCardPalette(for: preset)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            Text(title)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(custom?.tagText ?? palette.outerStrokeEnd)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(custom?.glowFillMid ?? Color.white.opacity(0.74))
                .overlay(
                    Capsule()
                        .stroke(palette.strokeStart, lineWidth: 0.7)
                )
        )
        .fixedSize(horizontal: true, vertical: true)
    }
}

private struct UsageCountRing: View {
    let count: Int
    private let goal: Double = 20

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 1)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.98, green: 0.62, blue: 0.86),
                            Color(red: 0.74, green: 0.71, blue: 0.99),
                            Color(red: 0.59, green: 0.87, blue: 0.99)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text("使用回数")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(count)")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
            }
        }
    }

    private var progress: CGFloat {
        let ratio = min(max(Double(count) / goal, 0), 1)
        return CGFloat(ratio)
    }
}

// 一覧ごとの削除状態を保持する。失敗時の対象は残し、整理警告では再削除させない。
@MainActor final class NailDeletionController: ObservableObject {
    @Published var confirming = false
    @Published var message: String?
    @Published private(set) var working = false
    @Published private(set) var completed = 0
    @Published private(set) var plan: RecordDeletionTransaction.Plan?
    private(set) var conflict = false
    private(set) var committed = false
    private var kind: RecordDeletionTransaction.Kind = .items
    private var ids: [NSManagedObjectID] = []
    private let hooks: RecordDeletionTransaction.Hooks
    init(hooks: RecordDeletionTransaction.Hooks? = nil) { self.hooks = hooks ?? .init() }
    func request(_ kind: RecordDeletionTransaction.Kind, ids: [NSManagedObjectID], in context: NSManagedObjectContext) {
        guard !working, !ids.isEmpty else { return }
        self.kind = kind; self.ids = ids; committed = false; message = nil
        reconfirm(in: context)
    }
    func reconfirm(in context: NSManagedObjectContext) {
        guard !working else { return }
        message = nil; confirming = false; plan = nil
        do { plan = try RecordDeletionTransaction.prepare(kind, ids: ids, in: context); confirming = true }
        catch { conflict = true; message = error.localizedDescription }
    }
    func cancel() { guard !working else { return }; confirming = false; message = nil; plan = nil }
    func execute(in context: NSManagedObjectContext) {
        guard !working, !committed, let plan else { return }
        confirming = false; message = nil; working = true
        Task { @MainActor in
            await Task.yield()
            defer { working = false }
            do {
                let warning = try RecordDeletionTransaction.delete(plan, in: context, hooks: hooks)
                committed = true; self.plan = nil; completed += 1
                message = warning
            } catch {
                conflict = (error as? RecordDeletionTransaction.Failure) == .conflict
                message = error.localizedDescription
            }
        }
    }
}

struct NailDeletionDialogs: ViewModifier {
    @ObservedObject var deletion: NailDeletionController
    let context: NSManagedObjectContext
    func body(content: Content) -> some View {
        content
            .disabled(deletion.working)
            .modifier(NailTabExitProtection(dirty: false, blocked: deletion.working, hidesTabBar: false))
            .background {
                Color.clear.alert(deletion.plan?.title ?? "削除を確認", isPresented: $deletion.confirming) {
                    Button("削除する", role: .destructive) { deletion.execute(in: context) }.accessibilityIdentifier("deletion.confirm")
                    Button("キャンセル", role: .cancel) { deletion.cancel() }
                } message: { Text(deletion.plan?.message ?? "") }
            }
            .background {
                Color.clear.alert(deletion.committed ? "削除は完了しました" : "削除できませんでした", isPresented: Binding(get: { deletion.message != nil }, set: { if !$0 { deletion.message = nil } })) {
                    if deletion.committed {
                        Button("閉じる") { deletion.cancel() }
                    } else {
                        if deletion.conflict {
                            Button("内容を確認し直す") { deletion.reconfirm(in: context) }
                        } else {
                            Button("再試行") { deletion.execute(in: context) }
                        }
                        Button("キャンセル", role: .cancel) { deletion.cancel() }
                    }
                } message: { Text(deletion.message ?? "") }
            }
    }
}
