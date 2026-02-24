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
    @State private var shopFilterText: String = ""
    @State private var keywordFilterText: String = ""
    @AppStorage("FavoriteProductIDs") private var favoriteIDsRaw: String = ""
    @AppStorage("ProductsShowFavoritesOnly") private var showFavoritesOnly: Bool = false

    var body: some View {
        NavigationStack {
            GlassBackgroundView {
                VStack(spacing: 10) {
                    AdPlaceholderRow()
                        .padding(.top, 12)
                        .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        filterControls
                        CategoryTabBar(selected: $selectedCategory)
                    }
                    .padding(.horizontal, 16)

                    productList
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .bottomTrailing) {
                    FloatingAddButton {
                        showingAddSheet = true
                    }
                    .padding(.bottom, 24)
                    .padding(.trailing, 24)
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

private extension ProductListView {
    var productList: some View {
        List {
            if filteredProducts.isEmpty {
                ContentUnavailableView("該当する用品がありません", systemImage: "cube.box")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(Array(filteredProducts.enumerated()), id: \.element.objectID) { index, product in
                    Button {
                        editingProduct = product
                    } label: {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ProductRow(
                                product: product,
                                cardIndex: index,
                                isFavorite: isFavorite(product),
                                toggleFavorite: { toggleFavorite(product) }
                            )
                            Spacer(minLength: 0)
                        }
                    }
                    .buttonStyle(.plain)
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

private struct AdPlaceholderRow: View {
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("広告枠（将来用）")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("ここにバナーやキャンペーン情報を表示予定。現在はプレースホルダのみ。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "megaphone")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row

private struct ProductRow: View {
    let product: NailProduct
    let cardIndex: Int
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    @AppStorage(GlassTheme.Keys.itemCardPreset) private var itemCardPresetRaw: String = GlassTheme.ItemCardPreset.roseChampagne.rawValue
    private let textInset: CGFloat = 8
    private let mediaShiftLeft: CGFloat = 6
    private var palette: GlassTheme.ItemCardPalette {
        let preset = GlassTheme.ItemCardPreset(rawValue: itemCardPresetRaw) ?? .roseChampagne
        return GlassTheme.itemCardPalette(for: preset, variantIndex: cardIndex)
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
                            ProductThumbnail(photoId: product.photoId, size: 92)
                                .frame(width: 92, height: 92)

                            FavoriteButton(isFavorite: isFavorite, action: toggleFavorite)
                                .offset(x: 6, y: -6)
                        }
                        .offset(x: -mediaShiftLeft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var formattedPrice: String? {
        guard product.priceYenTaxIn > 0 else { return nil }
        let value = NSNumber(value: product.priceYenTaxIn)
        let formatted = Self.priceFormatter.string(from: value) ?? "\(product.priceYenTaxIn)"
        return "¥\(formatted)"
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
    @Binding var selected: NailProductCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
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

// MARK: - Filters & Floating Button

private extension ProductListView {
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
    }

    func matchesCategory(_ product: NailProduct) -> Bool {
        category(for: product) == selectedCategory
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

private struct FloatingAddButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 6)
                )
        }
        .accessibilityLabel("用品を追加")
    }
}

private struct StyledFilterField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(title, text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.none)
                .disableAutocorrection(true)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

private struct ShopFilterMenu: View {
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
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)
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
        .foregroundStyle(palette.outerStrokeEnd)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.74))
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
