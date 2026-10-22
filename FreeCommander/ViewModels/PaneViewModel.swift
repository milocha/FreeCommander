import AppKit
import Foundation

/// Stan jednego panelu (w stylu Total Commandera): bieżący katalog, zawartość,
/// zaznaczenie, sortowanie i filtr. Na macOS (bez sandboxa) panel może wskazywać
/// dowolny katalog na dysku.
@MainActor
final class PaneViewModel: ObservableObject, Identifiable {
    let paneIndex: Int
    nonisolated var id: Int { paneIndex }

    @Published private(set) var directory: URL
    @Published private(set) var items: [FileItem] = []
    @Published var selectedURLs: Set<URL> = []
    @Published private(set) var isLoading = false
    @Published private(set) var volumeUsage: VolumeUsage?
    @Published var errorMessage: String?
    @Published var filterText = ""
    @Published var showFilter = false
    /// Żądania dialogów ustawiane też z zewnątrz (klawiatura, menu kontekstowe).
    @Published var previewURL: URL?
    @Published var infoItem: FileItem?
    @Published var renameItem: FileItem?
    @Published var deleteRequest: FileItem?
    @Published var sortField: SortField {
        didSet { persistSort() }
    }
    @Published var sortDirection: SortDirection {
        didSet { persistSort() }
    }

    private var generation = 0

    init(paneIndex: Int) {
        self.paneIndex = paneIndex
        let stored = UserDefaults.standard.string(forKey: "pane\(paneIndex).sort") ?? "name|asc"
        let parts = stored.split(separator: "|").map(String.init)
        self.sortField = SortField(rawValue: parts.first ?? "name") ?? .name
        self.sortDirection = SortDirection.parse(parts.last)
        if let path = UserDefaults.standard.string(forKey: "pane\(paneIndex).path"),
           FileManager.default.fileExists(atPath: path) {
            self.directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            self.directory = FileManager.default.homeDirectoryForCurrentUser
        }
        reload()
    }

    // MARK: - Nawigacja

    var canGoUp: Bool {
        directory.standardizedFileURL.path != "/"
    }

    func navigate(to url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            errorMessage = String(
                format: NSLocalizedString("error.notDirectory", comment: ""),
                url.path)
            return
        }
        let newURL = url.standardizedFileURL
        if newURL == directory.standardizedFileURL {
            reload()
            return
        }
        directory = newURL
        selectedURLs = []
        filterText = ""
        errorMessage = nil
        UserDefaults.standard.set(newURL.path, forKey: "pane\(paneIndex).path")
        reload()
    }

    func goUp() {
        guard canGoUp else { return }
        navigate(to: directory.deletingLastPathComponent())
    }

    func open(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func requestPreview(_ item: FileItem) {
        guard !item.isDirectory else { return }
        previewURL = item.url
    }

    // MARK: - Zawartość i zaznaczenie

    var visibleItems: [FileItem] {
        let base = filterText.isEmpty
            ? items
            : items.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
        return FileSystemService.sort(
            base,
            field: sortField,
            direction: sortDirection,
            directoriesFirst: SettingsStore.shared.directoriesFirst)
    }

    func selectedItems() -> [FileItem] {
        items.filter { selectedURLs.contains($0.url) }
    }

    var selectionSize: Int64 {
        selectedItems().reduce(0) { $0 + ($1.size ?? 0) }
    }

    func toggleSelection(_ item: FileItem) {
        if selectedURLs.contains(item.url) {
            selectedURLs.remove(item.url)
        } else {
            selectedURLs.insert(item.url)
        }
    }

    func selectAllVisible() {
        selectedURLs = Set(visibleItems.map(\.url))
    }

    func clearSelection() {
        selectedURLs = []
    }

    var fileCount: Int { items.filter { !$0.isDirectory }.count }
    var directoryCount: Int { items.filter { $0.isDirectory }.count }

    var statusSummary: String {
        String(
            format: NSLocalizedString("status.itemsMac", comment: ""),
            fileCount, directoryCount)
    }

    var selectionSummary: String {
        String(
            format: NSLocalizedString("status.selected", comment: ""),
            selectedURLs.count,
            Formatters.size(selectionSize))
    }

    // MARK: - Szybkie operacje

    func createFolder(named rawName: String) {
        guard let name = validName(rawName) else { return }
        let target = FileSystemService.uniqueURL(for: name, in: directory)
        do {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTextFile(named rawName: String) {
        guard let name = validName(rawName) else { return }
        let finalName = name.hasSuffix(".txt") ? name : "\(name).txt"
        let target = FileSystemService.uniqueURL(for: finalName, in: directory)
        do {
            try Data().write(to: target)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(_ item: FileItem, to rawName: String) {
        guard let name = validName(rawName) else { return }
        do {
            _ = try FileSystemService.renameSync(item.url, to: name)
            selectedURLs.remove(item.url)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func duplicate(_ item: FileItem) {
        do {
            _ = try FileSystemService.copySync(from: item.url, toDirectory: directory)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Wewnętrzne

    func reload() {
        generation += 1
        let gen = generation
        let dir = directory
        let hidden = SettingsStore.shared.showHidden
        isLoading = true
        Task {
            do {
                let loaded = try await FileSystemService.list(at: dir, showHidden: hidden)
                guard gen == self.generation else { return }
                items = loaded
                selectedURLs = selectedURLs.intersection(Set(loaded.map(\.url)))
                volumeUsage = VolumeInfo.usage(for: dir)
                isLoading = false
            } catch {
                guard gen == self.generation else { return }
                items = []
                isLoading = false
                errorMessage = String(
                    format: NSLocalizedString("error.listing", comment: ""),
                    dir.lastPathComponent,
                    error.localizedDescription)
            }
        }
    }

    private func validName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else {
            errorMessage = NSLocalizedString("error.nameInvalid", comment: "")
            return nil
        }
        return name
    }

    private func persistSort() {
        UserDefaults.standard.set("\(sortField.rawValue)|\(sortDirection.storageKey)", forKey: "pane\(paneIndex).sort")
    }
}
