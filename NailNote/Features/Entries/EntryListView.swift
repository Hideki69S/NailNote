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

    var body: some View {
        GlassBackgroundView {
            NavigationStack {
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
            .sheet(isPresented: $showingAddSheet) {
                AddEntryView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        let targets = filteredEntries
        for index in offsets {
            let entry = targets[index]
            if let photoId = entry.photoId {
                EntryPhotoStore.delete(photoId: photoId)
            }
            viewContext.delete(entry)
        }

        do {
            try viewContext.save()
        } catch {
            print("削除エラー: \(error)")
        }
    }
}

// MARK: - Row

struct EntryRowView: View {
    @ObservedObject var entry: NailEntry

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                EntryThumbnailView(photoId: entry.photoId)

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(alignment: .center, spacing: 8) {
                        Text(formattedDate(entry.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer()
                        if entry.rating > 0 {
                            StarRatingView(rating: entry.rating, size: 12)
                                .padding(.trailing, -2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        designBadge
                        colorToneBadge
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }
        }
    }

    private var displayTitle: String {
        let t = (entry.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "（タイトルなし）" : t
    }

    private func formattedDate(_ date: Date?) -> String {
        let d = date ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: d)
    }
}

// MARK: - Thumbnail

struct EntryThumbnailView: View {
    let photoId: UUID?

    var body: some View {
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
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(GlassTheme.cardStroke, lineWidth: 1)
        )
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
            if filteredEntries.isEmpty {
                ContentUnavailableView("記録がありません", systemImage: "note.text")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(filteredEntries, id: \.objectID) { entry in
                        NavigationLink {
                            EditEntryView(entry: entry)
                        } label: {
                            EntryRowView(entry: entry)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: deleteEntries)
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
            matchesDesign(entry) && matchesColor(entry)
        }
    }

    var selectedDesignCategory: NailDesignCategory? {
        guard designFilterRaw != "all" else { return nil }
        return NailDesignCategory(rawValue: designFilterRaw)
    }

    var selectedColorTone: NailColorTone? {
        guard colorFilterRaw != "allColor" else { return nil }
        return NailColorTone(rawValue: colorFilterRaw)
    }

    var filterTitle: String {
        selectedDesignCategory?.displayName ?? "デザイン"
    }

    var colorFilterTitle: String {
        selectedColorTone?.displayName ?? "カラー"
    }

    var filterControlRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("フィルタ")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                designFilterMenu
                colorFilterMenu
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
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.body.weight(.semibold))
                Text(filterTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
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
                Image(systemName: "drop.fill")
                    .font(.body.weight(.semibold))
                Text(colorFilterTitle)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .accessibilityLabel("カラー絞り込み")
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
