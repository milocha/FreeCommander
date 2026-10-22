import AppKit

/// Schowek na pliki między panelami i z Findera: ⌘C kopiuje, ⌘X wycina (przenosi),
/// ⌘V wkleja do aktywnego panelu. URL-e trafiają też do NSPasteboard, więc można
/// wklejać pliki skopiowane w Finderze.
@MainActor
final class FileClipboard {
    static let shared = FileClipboard()

    private(set) var urls: [URL] = []
    private(set) var isCut = false

    private init() {}

    func store(_ urls: [URL], cut: Bool) {
        self.urls = urls
        isCut = cut
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
    }

    /// URL-e do wklejenia: najpierw własny schowek, potem pliki skopiowane w Finderze.
    func urlsForPaste() -> [URL] {
        if !urls.isEmpty { return urls }
        return (NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }

    func clear() {
        urls = []
        isCut = false
    }
}
