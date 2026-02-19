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

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView("記録がありません", systemImage: "note.text")
                } else {
                    ForEach(entries, id: \.objectID) { entry in
                        NavigationLink {
                            EditEntryView(entry: entry)
                        } label: {
                            EntryRowView(entry: entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
            .navigationTitle("記録")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEntryView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func deleteEntries(offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
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
    let entry: NailEntry

    var body: some View {
        HStack(spacing: 12) {
            EntryThumbnailView(photoId: entry.photoId)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(formattedDate(entry.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
