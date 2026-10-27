import SwiftUI
import CoreData
import UIKit

struct EntryListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \NailEntry.date, ascending: false)],
        animation: .default
    )
    private var entries: FetchedResults<NailEntry>

    @State private var showingAddSheet = false
    @AppStorage(GlassTheme.Keys.designCardPreset) private var controlPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var controlPalette: GlassTheme.DesignCardPalette {
        GlassTheme.designCardPalette(for: GlassTheme.DesignCardPreset(rawValue: controlPresetRaw) ?? .roseChampagne)
    }
    @AppStorage("EntryDesignFilter") private var designFilterRaw: String = "all"
    @AppStorage("EntryColorFilter") private var colorFilterRaw: String = "allColor"
    @AppStorage("EntrySortField") private var sortFieldRaw: String = EntrySortField.date.rawValue
    @AppStorage("EntrySortAscending") private var sortAscending: Bool = false
    @State private var keywordText: String = ""
    @State private var pendingDeletionEntries: [NailEntry] = []
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            GlassBackgroundView(refined: true) {
                VStack(spacing: 10) {
                    EntryAdPlaceholderRow()
                        .padding(.top, 12)
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        filterControlRow
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    entryList
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .bottomTrailing) {
                    FloatingAddButton(palette: controlPalette) {
                        showingAddSheet = true
                    }
                    .padding(.bottom, 24)
                        .padding(.trailing, 24)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEntryView()
                .environment(\.managedObjectContext, viewContext)
        }
        .alert("デザインを削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                deleteEntries(pendingDeletionEntries)
                pendingDeletionEntries = []
            }
            Button("キャンセル", role: .cancel) {
                pendingDeletionEntries = []
            }
        } message: {
            Text(NailNoteFeatureFlags.aiEvaluationEnabled
                 ? "選択したデザインと紐づくAIスコアがある場合は同時に削除されます。"
                 : "選択したデザインを削除します。この操作は取り消せません。")
        }
    }

    private func deleteEntries(_ entries: [NailEntry]) {
        for entry in entries {
            if let photoId = entry.photoId {
                EntryPhotoStore.delete(photoId: photoId)
            }
            if let aiScore = entry.aiScore {
                viewContext.delete(aiScore)
            }
            viewContext.delete(entry)
        }

        do {
            try viewContext.save()
        } catch {
            print("削除エラー: \(error)")
        }
    }

    private func promptEntryDeletion(offsets: IndexSet) {
        let targets = offsets.compactMap { index -> NailEntry? in
            let list = sortedEntries
            guard list.indices.contains(index) else { return nil }
            return list[index]
        }
        guard !targets.isEmpty else { return }
        pendingDeletionEntries = targets
        showingDeleteAlert = true
    }
}

private enum EntrySortField: String, CaseIterable, Identifiable {
    case aiScore
    case rating
    case date

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .aiScore: return "AIスコア"
        case .rating: return "自己評価"
        case .date: return "実施日付"
        }
    }
}

// MARK: - Row

struct EntryRowView: View {
    @ObservedObject var entry: NailEntry
    let cardIndex: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
        let preset = GlassTheme.DesignCardPreset(rawValue: designCardPresetRaw) ?? .roseChampagne
        return GlassTheme.designCardPalette(for: preset, variantIndex: cardIndex)
    }

    var body: some View {
        Group {
            if dynamicTypeSize >= .xxLarge {
                stackedPhotoAndInformation
            } else {
                photoAndInformation(photoSize: 108)
            }
        }
        .padding(12)
        .frame(maxWidth: GlassTheme.listCardWidth, alignment: .leading)
        .frame(minHeight: 148, alignment: .leading)
        .background(EntryPremiumCardMaterial(palette: palette))
        .overlay(alignment: .trailing) {
            if dynamicTypeSize < .xxLarge {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.titleIcon)
                    .padding(.trailing, 10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.09), radius: 1.5, x: 0.5, y: 1)
        .shadow(color: Color.black.opacity(0.10), radius: 16, x: 2, y: 8)
    }

    private var displayTitle: String {
        let t = (entry.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "（タイトルなし）" : t
    }

    private var titleRow: some View {
        Text(displayTitle)
            .font(.headline.weight(.semibold))
            .foregroundStyle(palette.titleText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func photoAndInformation(photoSize: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 14) {
            photo(size: photoSize)
            infoRow
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stackedPhotoAndInformation: some View {
        VStack(alignment: .leading, spacing: 14) {
            photo(size: 108)
                .frame(maxWidth: .infinity, alignment: .center)
            infoRow
        }
    }

    private func photo(size: CGFloat) -> some View {
        EntryThumbnailView(photoId: entry.photoId, aiScore: entry.aiScoreBridge?.totalScore, rowPalette: palette, size: size, framePadding: 3)
    }

    private var infoRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            titleRow
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "calendar")
                    .accessibilityHidden(true)
                Text(formattedDate(entry.date))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .foregroundStyle(palette.tagText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("実施日、\(formattedDate(entry.date))")
            EntryCardRatingView(rating: entry.rating, palette: palette)
            badgeRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badgeRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                designBadge
                colorToneBadge
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
                designBadge
                colorToneBadge
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formattedDate(_ date: Date?) -> String {
        let d = date ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: d)
    }
}

private struct EntryCardRatingView: View {
    let rating: Double
    let palette: GlassTheme.DesignCardPalette
    @ScaledMetric(relativeTo: .caption) private var starSize: CGFloat = 13

    // 行の明暗に対し、最も読み取りやすい落ち着いたゴールドを選ぶ。
    private var gold: Color {
        let candidates = [
            Color(red: 0.46, green: 0.34, blue: 0.16),
            Color(red: 0.88, green: 0.77, blue: 0.51)
        ]
        let surfaces = [palette.glowFillTop, palette.glowFillMid, palette.glowFillBottom].map(luminance)
        let preferred = candidates.max { minimumContrast($0, surfaces: surfaces) < minimumContrast($1, surfaces: surfaces) } ?? candidates[0]
        if minimumContrast(preferred, surfaces: surfaces) >= 4.5 {
            return preferred
        }
        let alternatives = [
            Color(red: 0.26, green: 0.18, blue: 0.06),
            Color(red: 0.98, green: 0.89, blue: 0.66)
        ]
        return alternatives.max { minimumContrast($0, surfaces: surfaces) < minimumContrast($1, surfaces: surfaces) } ?? preferred
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                stars
                score
            }
            .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
                stars
                score
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("自己評価 \(String(format: "%.1f", rating))、5点満点")
    }

    private var stars: some View {
        let tint = gold
        return HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: rating >= Double(index) ? "star.fill" : rating >= Double(index) - 0.5 ? "star.leadinghalf.filled" : "star")
                    .font(.system(size: starSize, weight: .medium))
                    .foregroundStyle(tint)
            }
        }
    }

    private var score: some View {
        Text(String(format: "%.1f", rating))
            .font(.subheadline.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(palette.titleText)
    }

    private func minimumContrast(_ color: Color, surfaces: [Double]) -> Double {
        let foreground = luminance(color)
        return surfaces.map { (max(foreground, $0) + 0.05) / (min(foreground, $0) + 0.05) }.min() ?? 1
    }

    private func luminance(_ color: Color) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ value: CGFloat) -> Double {
            let value = Double(value)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

// MARK: - Thumbnail

struct EntryThumbnailView: View {
    let photoId: UUID?
    let aiScore: Int16?
    var rowPalette: GlassTheme.DesignCardPalette? = nil
    var size: CGFloat = 88
    var framePadding: CGFloat = 0
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
        if let rowPalette { return rowPalette }
        let preset = GlassTheme.DesignCardPreset(rawValue: designCardPresetRaw) ?? .roseChampagne
        return GlassTheme.designCardPalette(for: preset)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let photoId,
                   let uiImage = EntryPhotoStore.loadThumbnail(photoId: photoId) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.gray.opacity(0.15))
                        Image(systemName: "photo")
                            .foregroundStyle(palette.tagText.opacity(0.65))
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: framePadding > 0 ? 15 : 20))
            .overlay(
                RoundedRectangle(cornerRadius: framePadding > 0 ? 15 : 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                palette.thumbnailStrokeStart,
                                palette.thumbnailStrokeEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.7
                    )
            )
            .padding(framePadding)
            .background {
                if framePadding > 0 {
                    EntryPremiumPhotoFrame(palette: palette)
                }
            }
            .shadow(color: Color.black.opacity(framePadding > 0 ? 0.10 : 0.08), radius: framePadding > 0 ? 1.5 : 8, x: framePadding > 0 ? 0.5 : 0, y: framePadding > 0 ? 1 : 4)
            .shadow(color: Color.black.opacity(framePadding > 0 ? 0.08 : 0), radius: 8, x: 1, y: 4)

            if NailNoteFeatureFlags.aiEvaluationEnabled, let aiScore {
                EntryPhotoAIScoreBadge(score: Int(aiScore))
                    .offset(x: -6, y: -6)
            }
        }
    }
}

private struct EntryAdPlaceholderRow: View {
    @AppStorage(GlassTheme.Keys.backgroundPreset) private var presetRaw = GlassTheme.BackgroundPreset.smokySageChampagne.rawValue

    var body: some View {
        let preset = GlassTheme.BackgroundPreset(rawValue: presetRaw) ?? .smokySageChampagne
        let palette = preset.refinedSurfacePalette
        GlassCard(
            strokeGradient: LinearGradient(colors: [palette.outerStrokeStart.opacity(0.40), palette.glowFillTop.opacity(0.65), palette.outerStrokeEnd.opacity(0.32)], startPoint: .topLeading, endPoint: .bottomTrailing),
            backgroundGradient: LinearGradient(colors: [palette.glowFillTop, palette.glowFillMid, palette.glowFillBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("広告枠（将来用）")
                        .font(.headline)
                        .foregroundStyle(palette.titleText)
                    Text("ここにキャンペーンやお知らせが入る予定。現在はプレースホルダです。")
                        .font(.caption)
                        .foregroundStyle(palette.titleText)
                }
                Spacer()
                Image(systemName: "megaphone")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.titleText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Helpers

private extension EntryListView {
    var entryList: some View {
        List {
            if sortedEntries.isEmpty {
                ContentUnavailableView("記録がありません", systemImage: "note.text")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(Array(sortedEntries.enumerated()), id: \.element.objectID) { index, entry in
                        ZStack {
                            HStack(spacing: 0) {
                                Spacer(minLength: 0)
                                EntryRowView(entry: entry, cardIndex: index)
                                Spacer(minLength: 0)
                            }
                            NavigationLink {
                                EditEntryView(entry: entry)
                            } label: {
                                EmptyView()
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .opacity(0.001)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: promptEntryDeletion)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.horizontal, 0)
    }

    var filteredEntries: [NailEntry] {
        entries.filter { entry in
            matchesDesign(entry) && matchesColor(entry) && matchesKeyword(entry)
        }
    }

    var sortedEntries: [NailEntry] {
        filteredEntries.sorted(by: compareEntries)
    }

    var selectedDesignCategory: NailDesignCategory? {
        guard designFilterRaw != "all" else { return nil }
        return NailDesignCategory(rawValue: designFilterRaw)
    }

    var selectedColorTone: NailColorTone? {
        guard colorFilterRaw != "allColor" else { return nil }
        return NailColorTone(rawValue: colorFilterRaw)
    }

    var selectedSortField: EntrySortField {
        let storedField = EntrySortField(rawValue: sortFieldRaw) ?? .date
        // 保存値は保持し、休止中だけ日付順として扱う。
        return !NailNoteFeatureFlags.aiEvaluationEnabled && storedField == .aiScore ? .date : storedField
    }

    var filterTitle: String {
        selectedDesignCategory?.displayName ?? "デザイン"
    }

    var colorFilterTitle: String {
        selectedColorTone?.displayName ?? "カラー"
    }

    var filterControlRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("フィルタ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            HStack(spacing: 12) {
                designFilterMenu
                colorFilterMenu
            }
            HStack(spacing: 10) {
                keywordField
                sortFieldMenu
                sortOrderButton
            }
        }
        .padding(.vertical, 4)
    }

    var designFilterMenu: some View {
        Menu {
            Button {
                designFilterRaw = "all"
            } label: {
                labelRow(title: "すべて", isSelected: selectedDesignCategory == nil)
            }

            ForEach(NailDesignCategory.allCases) { category in
                Button {
                    designFilterRaw = category.rawValue
                } label: {
                    labelRow(title: category.displayName, isSelected: selectedDesignCategory == category)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("💅")
                    .font(.body)
                Text(filterTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .modifier(EntryHybridControlStyle(palette: controlPalette))
        }
        .accessibilityLabel("デザイン絞り込み")
    }

    var colorFilterMenu: some View {
        Menu {
            Button {
                colorFilterRaw = "allColor"
            } label: {
                labelRow(title: "すべて", isSelected: selectedColorTone == nil)
            }

            ForEach(NailColorTone.allCases) { tone in
                Button {
                    colorFilterRaw = tone.rawValue
                } label: {
                    labelRow(title: tone.displayName, isSelected: selectedColorTone == tone)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text("🎨")
                    .font(.body)
                Text(colorFilterTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .modifier(EntryHybridControlStyle(palette: controlPalette))
        }
        .accessibilityLabel("カラー絞り込み")
    }

    var keywordField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(controlPalette.tagText)
            TextField("キーワード", text: $keywordText, prompt: Text("キーワード").foregroundColor(controlPalette.tagText))
                .textFieldStyle(.plain)
        }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .modifier(EntryHybridControlStyle(palette: controlPalette))
            .frame(maxWidth: .infinity, alignment: .leading)
            .submitLabel(.search)
    }

    var sortFieldMenu: some View {
        Menu {
            ForEach(EntrySortField.allCases.filter {
                NailNoteFeatureFlags.aiEvaluationEnabled || $0 != .aiScore
            }) { field in
                Button {
                    sortFieldRaw = field.rawValue
                } label: {
                    labelRow(title: field.displayName, isSelected: selectedSortField == field)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.subheadline.weight(.semibold))
                Text(selectedSortField.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .modifier(EntryHybridControlStyle(palette: controlPalette))
        }
        .accessibilityLabel("ソート項目")
    }

    var sortOrderButton: some View {
        Button {
            sortAscending.toggle()
        } label: {
            Image(systemName: sortAscending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundStyle(controlPalette.titleText)
                .frame(width: 34, height: 34)
                .modifier(EntryHybridControlStyle(palette: controlPalette))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(sortAscending ? "昇順" : "降順")
    }

    func labelRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }

    func matchesDesign(_ entry: NailEntry) -> Bool {
        guard let selectedDesign = selectedDesignCategory else { return true }
        return entry.designCategory == selectedDesign.rawValue
    }

    func matchesColor(_ entry: NailEntry) -> Bool {
        guard let selectedTone = selectedColorTone else { return true }
        return entry.colorCategory == selectedTone.rawValue
    }

    func matchesKeyword(_ entry: NailEntry) -> Bool {
        let query = keywordText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        let lower = query.lowercased()
        let title = (entry.title ?? "").lowercased()
        let note = (entry.note ?? "").lowercased()
        return title.contains(lower) || note.contains(lower)
    }

    func compareEntries(_ lhs: NailEntry, _ rhs: NailEntry) -> Bool {
        switch selectedSortField {
        case .aiScore:
            let leftScore = lhs.aiScoreBridge?.totalScore
            let rightScore = rhs.aiScoreBridge?.totalScore
            if leftScore != rightScore {
                if sortAscending {
                    return (leftScore ?? Int16.max) < (rightScore ?? Int16.max)
                } else {
                    return (leftScore ?? Int16.min) > (rightScore ?? Int16.min)
                }
            }
        case .rating:
            if lhs.rating != rhs.rating {
                if sortAscending {
                    return lhs.rating < rhs.rating
                } else {
                    return lhs.rating > rhs.rating
                }
            }
        case .date:
            break
        }

        let leftDate = lhs.date ?? .distantPast
        let rightDate = rhs.date ?? .distantPast
        if sortAscending {
            return leftDate < rightDate
        } else {
            return leftDate > rightDate
        }
    }

}

private extension EntryRowView {
    var designDisplayName: String? {
        let raw = (entry.designCategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        return NailDesignCategory(rawValue: raw)?.displayName ?? raw
    }

    @ViewBuilder
    var designBadge: some View {
        Text(designDisplayName ?? "デザイン未設定")
            .font(.caption2.weight(.medium))
            .foregroundStyle(palette.titleText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(EntryPremiumTagMaterial(palette: palette))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.06), radius: 2.5, x: 0.5, y: 1.5)
            .accessibilityLabel("デザイン、\(designDisplayName ?? "未設定")")
    }

    @ViewBuilder
    var colorToneBadge: some View {
        HStack(spacing: 6) {
            if let tone = colorTone {
                Circle()
                    .fill(gradientFill(for: tone))
                    .frame(width: 10, height: 10)
            }
            Text(colorDisplayName)
                .font(.caption2.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(palette.titleText)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(EntryPremiumTagMaterial(palette: palette))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.06), radius: 2.5, x: 0.5, y: 1.5)
        .accessibilityLabel("カラー系統、\(colorDisplayName)")
    }

    var colorDisplayName: String {
        let raw = (entry.colorCategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return colorTone?.displayName ?? (raw.isEmpty ? "カラー未設定" : raw)
    }

    var colorTone: NailColorTone? {
        guard let raw = entry.colorCategory else { return nil }
        return NailColorTone(rawValue: raw)
    }

    func baseColor(for tone: NailColorTone) -> Color {
        switch tone {
        case .pink:       return Color(red: 1.0, green: 0.72, blue: 0.86)
        case .red:        return Color(red: 1.0, green: 0.38, blue: 0.40)
        case .orange:     return Color(red: 1.0, green: 0.63, blue: 0.30)
        case .yellow:     return Color(red: 0.99, green: 0.85, blue: 0.32)
        case .green:      return Color(red: 0.42, green: 0.75, blue: 0.55)
        case .blue:       return Color(red: 0.38, green: 0.63, blue: 0.94)
        case .purple:     return Color(red: 0.66, green: 0.49, blue: 0.96)
        case .brown:      return Color(red: 0.63, green: 0.42, blue: 0.28)
        case .beige:      return Color(red: 0.96, green: 0.86, blue: 0.76)
        case .white:      return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .gray:       return Color(red: 0.70, green: 0.72, blue: 0.76)
        case .black:      return Color(red: 0.20, green: 0.20, blue: 0.20)
        case .clear:      return Color(red: 0.78, green: 0.94, blue: 0.95)
        case .multicolor: return Color(red: 0.72, green: 0.52, blue: 0.96)
        case .other:      return Color(red: 0.80, green: 0.80, blue: 0.80)
        }
    }

    func gradientFill(for tone: NailColorTone) -> LinearGradient {
        if tone == .multicolor {
            return LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.63, blue: 0.78),
                    Color(red: 0.76, green: 0.66, blue: 1.0),
                    Color(red: 0.57, green: 0.80, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            let base = baseColor(for: tone)
            return LinearGradient(
                colors: [base.opacity(0.9), base.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct EntryMetalTone {
    let highlight: Color
    let light: Color
    let middle: Color
    let dark: Color
    let isDark: Bool

    init(palette: GlassTheme.DesignCardPalette) {
        highlight = Self.mix(palette.outerStrokeStart, with: .white, amount: 0.82)
        light = Self.mix(palette.outerStrokeStart, with: palette.glowFillTop, amount: 0.5)
        middle = Self.mix(palette.outerStrokeStart, with: palette.outerStrokeEnd, amount: 0.4)
        dark = Self.mix(palette.outerStrokeEnd, with: .black, amount: 0.32)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(palette.glowFillMid).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        isDark = 0.2126 * red + 0.7152 * green + 0.0722 * blue < 0.5
    }

    var reflection: AngularGradient {
        AngularGradient(stops: [
            .init(color: highlight, location: 0),
            .init(color: light, location: 0.08),
            .init(color: middle, location: 0.17),
            .init(color: dark, location: 0.28),
            .init(color: light, location: 0.44),
            .init(color: middle, location: 0.58),
            .init(color: dark, location: 0.72),
            .init(color: light, location: 0.88),
            .init(color: highlight, location: 1)
        ], center: .center, startAngle: .degrees(-135), endAngle: .degrees(225))
    }

    private static func mix(_ color: Color, with other: Color, amount: CGFloat) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(color).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double(r1 + (r2 - r1) * amount),
                     green: Double(g1 + (g2 - g1) * amount),
                     blue: Double(b1 + (b2 - b1) * amount))
    }
}

private struct EntryPremiumCardMaterial: View {
    let palette: GlassTheme.DesignCardPalette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let tone = EntryMetalTone(palette: palette)
        let outer = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: 17, style: .continuous)
        ZStack {
            // 金属の帯は中央を抜き、ガラスの背面に実背景を残す。
            outer.fill(tone.reflection)
                .mask(outer.strokeBorder(lineWidth: 3))

            inner.fill(.regularMaterial)
                .environment(\.colorScheme, tone.isDark ? .dark : .light)
                .overlay {
                    inner.fill(LinearGradient(colors: [
                        palette.glowFillTop.opacity(reduceTransparency ? 1 : (tone.isDark ? 0.96 : 0.88)),
                        palette.glowFillMid.opacity(reduceTransparency ? 1 : (tone.isDark ? 0.94 : 0.76)),
                        palette.glowFillBottom.opacity(reduceTransparency ? 1 : (tone.isDark ? 0.96 : 0.88))
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay {
                    RefinedSatinLayer(isDark: tone.isDark, strength: 1.12, surface: .glass)
                        .clipShape(inner)
                }
                .overlay {
                    inner.strokeBorder(LinearGradient(colors: [Color.white.opacity(tone.isDark ? 0.20 : 0.42), .clear, Color.black.opacity(tone.isDark ? 0.24 : 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                }
                .padding(3)

            outer.strokeBorder(LinearGradient(colors: [tone.highlight, tone.light, tone.dark], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: contrast == .increased ? 0.9 : 0.55)
            outer.inset(by: 0.65)
                .strokeBorder(LinearGradient(colors: [tone.highlight.opacity(0.85), tone.dark.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
            outer.inset(by: 2.5)
                .strokeBorder(LinearGradient(colors: [tone.dark.opacity(0.5), tone.highlight.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.65)
        }
        .clipShape(outer)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct EntryPremiumPhotoFrame: View {
    let palette: GlassTheme.DesignCardPalette

    var body: some View {
        let tone = EntryMetalTone(palette: palette)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        shape.fill(tone.reflection)
            .mask(shape.strokeBorder(lineWidth: 3))
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [tone.highlight, tone.dark.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.5)
            }
            .overlay {
                shape.inset(by: 2.4).strokeBorder(LinearGradient(colors: [tone.dark.opacity(0.55), tone.highlight], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.6)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct EntryPremiumTagMaterial: View {
    let palette: GlassTheme.DesignCardPalette

    var body: some View {
        let tone = EntryMetalTone(palette: palette)
        Capsule()
            .fill(LinearGradient(colors: [palette.glowFillTop, palette.glowFillMid, palette.glowFillBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                Capsule().fill(RadialGradient(colors: [Color.white.opacity(tone.isDark ? 0.06 : 0.18), .clear], center: .topLeading, startRadius: 0, endRadius: 80))
            }
            .overlay {
                Capsule().strokeBorder(LinearGradient(colors: [tone.highlight.opacity(0.7), palette.tagStroke, tone.dark.opacity(0.28)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.65)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct EntryCardGlowLayer: View {
    let palette: GlassTheme.DesignCardPalette
    var cornerRadius: CGFloat = 20
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var sheenOpacity: Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(palette.glowFillMid).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        // 濃色の面は明度を保ち、光を輪郭へ集中させる。
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue < 0.5 ? 0.06 : 0.22
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(
                LinearGradient(
                    colors: [
                        palette.glowFillTop.opacity(reduceTransparency ? 1 : 0.96),
                        palette.glowFillMid.opacity(reduceTransparency ? 1 : 0.94),
                        palette.glowFillBottom.opacity(reduceTransparency ? 1 : 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(.regularMaterial, in: shape)
            .overlay(
                shape
                    .fill(
                        LinearGradient(stops: [
                            .init(color: Color.white.opacity(sheenOpacity), location: 0),
                            .init(color: Color.white.opacity(0), location: 0.32),
                            .init(color: palette.glowFillTop.opacity(0.12), location: 0.72),
                            .init(color: Color.white.opacity(sheenOpacity * 0.7), location: 1)
                        ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                palette.outerStrokeStart.opacity(0.75),
                                palette.outerStrokeEnd.opacity(0.65),
                                Color.white.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                shape.inset(by: 2)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.04), palette.glowStrokeEnd.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.65
                    )
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct EntryHybridControlStyle: ViewModifier {
    let palette: GlassTheme.DesignCardPalette

    func body(content: Content) -> some View {
        content
            .foregroundStyle(palette.titleText)
            .background(EntryCardGlowLayer(palette: palette, cornerRadius: 100))
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.09), radius: 5, x: 0, y: 3)
    }
}

private struct EntryInfoTag: View {
    let title: String
    let systemImage: String
    var rowPalette: GlassTheme.DesignCardPalette? = nil
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
        if let rowPalette { return rowPalette }
        let preset = GlassTheme.DesignCardPreset(rawValue: designCardPresetRaw) ?? .roseChampagne
        return GlassTheme.designCardPalette(for: preset)
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
        .foregroundStyle(palette.tagText)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [palette.glowFillTop, palette.glowFillMid],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(palette.tagStroke, lineWidth: 0.7)
                )
        )
        .fixedSize(horizontal: true, vertical: true)
    }
}

private struct EntryPhotoAIScoreBadge: View {
    let score: Int
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
        let preset = GlassTheme.DesignCardPreset(rawValue: designCardPresetRaw) ?? .roseChampagne
        return GlassTheme.designCardPalette(for: preset)
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 10, weight: .bold))
            Text("\(score)")
                .font(.caption2.weight(.heavy))
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            palette.badgeStart,
                            palette.badgeEnd
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.45), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Floating Button

private struct FloatingAddButton: View {
    let palette: GlassTheme.DesignCardPalette
    var action: () -> Void

    private var symbolColor: Color {
        let luminances = [palette.outerStrokeStart, palette.outerStrokeEnd].map { color -> Double in
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ component: CGFloat) -> Double {
                let value = Double(component)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let whiteContrast = 1.05 / ((luminances.max() ?? 0) + 0.05)
        let blackContrast = ((luminances.min() ?? 1) + 0.05) / 0.05
        return whiteContrast >= blackContrast ? .white : .black
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.medium))
                .foregroundStyle(symbolColor)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(LinearGradient(colors: [palette.outerStrokeStart, palette.outerStrokeEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Circle().strokeBorder(LinearGradient(colors: [Color.white.opacity(0.8), palette.outerStrokeEnd], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
                        .overlay(Circle().inset(by: 2).strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.18), radius: 9, x: 0, y: 5)
                )
        }
        .accessibilityLabel("新規記録を追加")
    }
}

// MARK: - AI スコア橋渡し

extension NailEntry {
    var aiScoreBridge: EntryAIScoreBridge? {
        guard let object = aiScore else { return nil }
        return EntryAIScoreBridge(object: object)
    }

    func ensureAIScoreBridge(in context: NSManagedObjectContext) -> EntryAIScoreBridge {
        if let existing = aiScoreBridge {
            return existing
        }
        let object = NSEntityDescription.insertNewObject(forEntityName: "EntryAIScore", into: context)
        guard let typedObject = object as? EntryAIScore else {
            fatalError("EntryAIScore entity must be backed by EntryAIScore class")
        }
        typedObject.setValue(UUID(), forKey: "id")
        aiScore = typedObject
        return EntryAIScoreBridge(object: typedObject)
    }
}

struct EntryAIScoreBridge {
    let object: NSManagedObject

    var entryDesignCategoryName: String {
        guard let entry = object.value(forKey: "entry") as? NailEntry else { return "未設定" }
        let raw = (entry.designCategory ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let category = NailDesignCategory(rawValue: raw) {
            return category.displayName
        }
        return raw.isEmpty ? "未設定" : raw
    }

    var totalScore: Int16 {
        get { object.value(forKey: "totalScore") as? Int16 ?? 0 }
        set { object.setValue(newValue, forKey: "totalScore") }
    }

    var finishQuality: Int16 {
        get { object.value(forKey: "finishQuality") as? Int16 ?? 0 }
        set { object.setValue(newValue, forKey: "finishQuality") }
    }

    var edgeAndCuticle: Int16 {
        get { object.value(forKey: "edgeAndCuticle") as? Int16 ?? 0 }
        set { object.setValue(newValue, forKey: "edgeAndCuticle") }
    }

    var thicknessBalance: Int16 {
        get { object.value(forKey: "thicknessBalance") as? Int16 ?? 0 }
        set { object.setValue(newValue, forKey: "thicknessBalance") }
    }

    var designBalance: Int16 {
        get { object.value(forKey: "designBalance") as? Int16 ?? 0 }
        set { object.setValue(newValue, forKey: "designBalance") }
    }

    var durabilityPrediction: Int16 {
        get { object.value(forKey: "durabilityPrediction") as? Int16 ?? 0 }
        set { object.setValue(newValue, forKey: "durabilityPrediction") }
    }

    var caution: String? {
        get { object.value(forKey: "caution") as? String }
        set { object.setValue(newValue, forKey: "caution") }
    }

    var confidence: Double {
        get { object.value(forKey: "confidence") as? Double ?? 0 }
        set { object.setValue(newValue, forKey: "confidence") }
    }

    var evaluatedAt: Date? {
        get { object.value(forKey: "evaluatedAt") as? Date }
        set { object.setValue(newValue, forKey: "evaluatedAt") }
    }

    var photoHash: String? {
        get { object.value(forKey: "photoHash") as? String }
        set { object.setValue(newValue, forKey: "photoHash") }
    }

    var highlightsArray: [String] {
        get { decodeArray(forKey: "highlights") }
        set { object.setValue(encodeArray(newValue), forKey: "highlights") }
    }

    var improvementsArray: [String] {
        get { decodeArray(forKey: "improvements") }
        set { object.setValue(encodeArray(newValue), forKey: "improvements") }
    }

    var nextStepsArray: [String] {
        get { decodeArray(forKey: "nextSteps") }
        set { object.setValue(encodeArray(newValue), forKey: "nextSteps") }
    }

    var assumptionsArray: [String] {
        get { decodeArray(forKey: "assumptions") }
        set { object.setValue(encodeArray(newValue), forKey: "assumptions") }
    }

    private func decodeArray(forKey key: String) -> [String] {
        guard let text = object.value(forKey: key) as? String,
              let data = text.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    private func encodeArray(_ values: [String]) -> String? {
        guard !values.isEmpty else { return nil }
        let data = try? JSONEncoder().encode(values)
        return data.flatMap { String(data: $0, encoding: .utf8) }
    }
}
