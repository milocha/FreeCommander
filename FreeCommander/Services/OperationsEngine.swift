import Foundation

/// Wykonuje operacje wsadowe (kopiowanie / przenoszenie / usuwanie / ZIP)
/// z postępem item-po-itemie. Ciężka praca działa poza wątkiem głównym.
@MainActor
final class OperationsEngine: ObservableObject {
    static let shared = OperationsEngine()

    @Published private(set) var isRunning = false
    @Published private(set) var progressText: String?
    @Published var alertMessage: String?

    private init() {}

    func copySelection(from source: PaneViewModel, to target: PaneViewModel) {
        let items = source.selectedItems()
        let destination = target.directory
        runOperation(items, verbKey: "op.copying", sourcePane: source, targetPane: target) { url in
            _ = try FileSystemService.copySync(from: url, toDirectory: destination)
        }
    }

    func moveSelection(from source: PaneViewModel, to target: PaneViewModel) {
        let items = source.selectedItems()
        let destination = target.directory
        runOperation(items, verbKey: "op.moving", sourcePane: source, targetPane: target) { url in
            _ = try FileSystemService.moveSync(from: url, toDirectory: destination)
        }
    }

    func deleteSelection(in pane: PaneViewModel, mode: FileSystemService.DeleteMode) {
        delete(pane.selectedItems(), in: pane, mode: mode)
    }

    func delete(_ items: [FileItem], in pane: PaneViewModel, mode: FileSystemService.DeleteMode) {
        let mode = mode
        runOperation(items, verbKey: mode == .trash ? "op.trashing" : "op.deleting", sourcePane: pane, targetPane: pane) { url in
            try FileSystemService.deleteSync([url], mode: mode)
        }
    }

    func zipSelection(in pane: PaneViewModel) {
        let items = pane.selectedItems()
        guard !items.isEmpty else { return }
        let baseName = items.count == 1
            ? (items[0].name as NSString).deletingPathExtension
            : NSLocalizedString("archive.defaultName", comment: "")
        let directory = pane.directory
        isRunning = true
        Task {
            do {
                progressText = NSLocalizedString("op.zipping", comment: "")
                let target = try await FileSystemService.zip(urls: items.map(\.url), baseName: baseName, in: directory)
                pane.clearSelection()
                pane.reload()
                alertMessage = String(format: NSLocalizedString("op.zipDone", comment: ""), target.lastPathComponent)
            } catch {
                alertMessage = error.localizedDescription
            }
            progressText = nil
            isRunning = false
        }
    }

    func unzip(_ item: FileItem, in pane: PaneViewModel) {
        let directory = pane.directory
        let sourceURL = item.url
        isRunning = true
        Task {
            do {
                progressText = NSLocalizedString("op.unzipping", comment: "")
                let target = try await FileSystemService.unzip(url: sourceURL, in: directory)
                pane.reload()
                alertMessage = String(format: NSLocalizedString("op.unzipDone", comment: ""), target.lastPathComponent)
            } catch {
                alertMessage = error.localizedDescription
            }
            progressText = nil
            isRunning = false
        }
    }

    /// ⌘V — wklej pliki ze schowka (własnego lub Findera) do aktywnego panelu.
    func pasteFromClipboard(into pane: PaneViewModel) {
        let destination = pane.directory
        let clipboard = FileClipboard.shared
        if clipboard.isCut, !clipboard.urls.isEmpty {
            let items = clipboard.urls.compactMap { Self.item(for: $0) }
            clipboard.clear()
            runOperation(items, verbKey: "op.moving", sourcePane: nil, targetPane: pane) { url in
                _ = try FileSystemService.moveSync(from: url, toDirectory: destination)
            }
        } else {
            let urls = clipboard.urlsForPaste()
            guard !urls.isEmpty else {
                alertMessage = NSLocalizedString("clipboard.empty", comment: "")
                return
            }
            let items = urls.compactMap { Self.item(for: $0) }
            runOperation(items, verbKey: "op.copying", sourcePane: nil, targetPane: pane) { url in
                _ = try FileSystemService.copySync(from: url, toDirectory: destination)
            }
        }
    }

    static func item(for url: URL) -> FileItem? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return nil }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        return FileItem(
            url: url,
            name: url.lastPathComponent,
            isDirectory: isDirectory.boolValue,
            size: isDirectory.boolValue ? nil : Int64(values?.fileSize ?? 0),
            modificationDate: values?.contentModificationDate,
            creationDate: nil)
    }

    private func runOperation(
        _ items: [FileItem],
        verbKey: String,
        sourcePane: PaneViewModel?,
        targetPane: PaneViewModel?,
        operation: @escaping @Sendable (URL) async throws -> Void
    ) {
        guard !items.isEmpty, !isRunning else { return }
        isRunning = true
        let total = items.count
        let verb = NSLocalizedString(verbKey, comment: "")
        Task {
            var failures: [String] = []
            for (index, item) in items.enumerated() {
                progressText = "\(verb) \(index + 1)/\(total): \(item.name)"
                do {
                    try await operation(item.url)
                } catch {
                    failures.append("\(item.name) — \(error.localizedDescription)")
                }
            }
            sourcePane?.clearSelection()
            sourcePane?.reload()
            targetPane?.reload()
            if !failures.isEmpty {
                alertMessage = failures.joined(separator: "\n")
            }
            progressText = nil
            isRunning = false
        }
    }
}
