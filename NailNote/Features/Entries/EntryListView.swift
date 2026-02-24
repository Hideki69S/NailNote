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
    @AppStorage("EntryDesignFilter") private var designFilterRaw: String = "all"
    @AppStorage("EntryColorFilter") private var colorFilterRaw: String = "allColor"
    @AppStorage("EntrySortField") private var sortFieldRaw: String = EntrySortField.date.rawValue
    @AppStorage("EntrySortAscending") private var sortAscending: Bool = false
    @State private var keywordText: String = ""
    @State private var pendingDeletionEntries: [NailEntry] = []
    @State private var showingDeleteAlert = false

    var body: some View {
        NavigationStack {
            GlassBackgroundView {
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
                    FloatingAddButton {
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
            Text("選択したデザインと紐づくAIスコアがある場合は同時に削除されます。")
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
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
        let preset = GlassTheme.DesignCardPreset(rawValue: designCardPresetRaw) ?? .roseChampagne
        return GlassTheme.designCardPalette(for: preset, variantIndex: cardIndex)
    }

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
                EntryCardGlowLayer(palette: palette)
                HStack(spacing: 18) {
                    EntryThumbnailView(photoId: entry.photoId, aiScore: entry.aiScoreBridge?.totalScore)
                        .offset(x: 5)

                    VStack(alignment: .leading, spacing: 10) {
                        titleRow
                        infoRow
                        badgeRow

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minHeight: 140, alignment: .leading)
    }

    private var displayTitle: String {
        let t = (entry.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "（タイトルなし）" : t
    }

    private var titleRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.titleIcon)

            Text(displayTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.titleText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)

            Spacer()
        }
    }

    private var infoRow: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                EntryInfoTag(title: "[実施日付]", systemImage: "calendar")
                Text(formattedDate(entry.date))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if entry.rating > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    EntryInfoTag(title: "[自己評価]", systemImage: "hand.thumbsup")
                    StarRatingView(rating: entry.rating, size: 14)
                }
                .padding(.trailing, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badgeRow: some View {
        HStack(spacing: 8) {
            designBadge
            colorToneBadge
            Spacer(minLength: 0)
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

// MARK: - Thumbnail

struct EntryThumbnailView: View {
    let photoId: UUID?
    let aiScore: Int16?
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                palette.thumbnailStrokeStart,
                                palette.thumbnailStrokeEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.6
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)

            if let aiScore {
                EntryPhotoAIScoreBadge(score: Int(aiScore))
                    .offset(x: -6, y: -6)
            }
        }
    }
}

private struct EntryAdPlaceholderRow: View {
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("広告枠（将来用）")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("ここにキャンペーンやお知らせが入る予定。現在はプレースホルダです。")
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
        EntrySortField(rawValue: sortFieldRaw) ?? .date
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
            .background(Color.white)
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(Capsule())
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
            .background(Color.white)
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .accessibilityLabel("カラー絞り込み")
    }

    var keywordField: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("キーワード", text: $keywordText)
                .textFieldStyle(.plain)
        }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Color.white)
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
            .submitLabel(.search)
    }

    var sortFieldMenu: some View {
        Menu {
            ForEach(EntrySortField.allCases) { field in
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
            .background(Color.white)
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .accessibilityLabel("ソート項目")
    }

    var sortOrderButton: some View {
        Button {
            sortAscending.toggle()
        } label: {
            Image(systemName: sortAscending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.white)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .clipShape(Circle())
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
        guard let raw = entry.designCategory else { return nil }
        return NailDesignCategory(rawValue: raw)?.displayName
    }

    @ViewBuilder
    var designBadge: some View {
        if let designName = designDisplayName {
            Text(designName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
                .fixedSize()
        }
    }

    @ViewBuilder
    var colorToneBadge: some View {
        if let tone = colorTone {
            let toneColor = baseColor(for: tone)
            let gradient = gradientFill(for: tone)
            HStack(spacing: 6) {
                Circle()
                    .fill(gradient)
                    .frame(width: 10, height: 10)
                Text(tone.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(gradient)
                    .opacity(0.25)
            )
            .overlay(
                Capsule()
                    .stroke(toneColor.opacity(0.5), lineWidth: 1)
            )
        }
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

private struct EntryCardGlowLayer: View {
    let palette: GlassTheme.DesignCardPalette

    var body: some View {
        RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius - 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.glowFillTop,
                        palette.glowFillMid,
                        palette.glowFillBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.cardCornerRadius - 4, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                palette.glowStrokeStart,
                                palette.glowStrokeEnd
                            ],
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

private struct EntryInfoTag: View {
    let title: String
    let systemImage: String
    @AppStorage(GlassTheme.Keys.designCardPreset) private var designCardPresetRaw: String = GlassTheme.DesignCardPreset.roseChampagne.rawValue
    private var palette: GlassTheme.DesignCardPalette {
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
                .fill(Color.white.opacity(0.74))
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
        aiScore = typedObject
        return EntryAIScoreBridge(object: typedObject)
    }
}

struct EntryAIScoreBridge {
    let object: NSManagedObject

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
