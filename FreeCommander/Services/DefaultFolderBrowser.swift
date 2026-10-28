import AppKit
import UniformTypeIdentifiers

/// Domyślna aplikacja systemowa do otwierania folderów (Launch Services).
/// Dzięki rejestracji CFBundleDocumentTypes (public.folder) FreeCommander
/// pojawia się w „Otwórz za pomocą”, a po ustawieniu jako domyślna przejmuje
/// otwieranie folderów z innych aplikacji (np. „Pokaż w folderze” przeglądarki).
/// Okien Findera i biurka zawsze obsługuje Finder — tego macOS nie pozwala zmienić.
@MainActor
final class DefaultFolderBrowser: ObservableObject {
    static let shared = DefaultFolderBrowser()

    @Published private(set) var isDefault: Bool

    private static let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")

    private init() {
        isDefault = Self.currentHandler() == Bundle.main.bundleURL.standardizedFileURL
    }

    func makeDefault() {
        set(Bundle.main.bundleURL)
    }

    func restoreFinder() {
        set(Self.finderURL)
    }

    /// Odświeża stan (np. gdy użytkownik zmienił obsługę w Get Info Findera).
    func refresh() {
        isDefault = Self.currentHandler() == Bundle.main.bundleURL.standardizedFileURL
    }

    private func set(_ appURL: URL) {
        do {
            for type in [UTType.folder, .directory] {
                try NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type)
            }
            isDefault = appURL.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private static func currentHandler() -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: .folder)?.standardizedFileURL
    }
}
