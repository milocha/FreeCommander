import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var showHidden: Bool {
        didSet { UserDefaults.standard.set(showHidden, forKey: "settings.showHidden") }
    }
    @Published var directoriesFirst: Bool {
        didSet { UserDefaults.standard.set(directoriesFirst, forKey: "settings.directoriesFirst") }
    }

    private init() {
        showHidden = UserDefaults.standard.bool(forKey: "settings.showHidden")
        directoriesFirst = UserDefaults.standard.object(forKey: "settings.directoriesFirst") as? Bool ?? true
    }
}
