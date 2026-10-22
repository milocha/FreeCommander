import Foundation

struct SavedBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var data: Data
    var addedAt: Date
}

/// Zapamiętane katalogi z aplikacji Pliki (security-scoped bookmarks).
/// Bez tego iOS odbiera dostęp do katalogu po zakończeniu sesji.
@MainActor
final class BookmarkStore: ObservableObject {
    static let shared = BookmarkStore()

    @Published private(set) var bookmarks: [SavedBookmark] = []
    private let defaultsKey = "savedBookmarks.v1"

    private init() { load() }

    func add(url: URL) throws -> SavedBookmark {
        let data = try url.bookmarkData()
        let bookmark = SavedBookmark(id: UUID(), name: url.lastPathComponent, data: data, addedAt: Date())
        bookmarks.append(bookmark)
        persist()
        return bookmark
    }

    func remove(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persist()
    }

    func resolve(_ id: UUID) -> URL? {
        guard let bookmark = bookmarks.first(where: { $0.id == id }) else { return nil }
        var stale = false
        return try? URL(
            resolvingBookmarkData: bookmark.data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([SavedBookmark].self, from: data) else { return }
        bookmarks = decoded
    }
}
