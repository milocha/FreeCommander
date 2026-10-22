import Foundation

struct UserFavorite: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var path: String

    var url: URL { URL(fileURLWithPath: path) }
}

/// Ulubione foldery dodane przez użytkownika (gwiazdka w belce ścieżki).
@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var favorites: [UserFavorite] = []
    private let defaults: UserDefaults
    private let key = "userFavorites.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(url: URL) {
        let path = url.standardizedFileURL.path
        guard !favorites.contains(where: { $0.path == path }) else { return }
        let name = path == "/" ? "/" : url.lastPathComponent
        favorites.append(UserFavorite(id: UUID(), name: name, path: path))
        persist()
    }

    func remove(id: UUID) {
        favorites.removeAll { $0.id == id }
        persist()
    }

    func contains(url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return favorites.contains { $0.path == path }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([UserFavorite].self, from: data) else { return }
        favorites = decoded
    }
}
