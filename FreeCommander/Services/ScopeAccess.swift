import Foundation

/// Licznikowe zarządzanie `startAccessingSecurityScopedResource` — adresy URL
/// z aplikacji Pliki wymagają jawnego rozpoczęcia i zakończenia dostępu.
final class ScopeAccess: @unchecked Sendable {
    static let shared = ScopeAccess()

    private var counts: [URL: Int] = [:]
    private let lock = NSLock()

    func acquire(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        let current = counts[url] ?? 0
        if current == 0 {
            guard url.startAccessingSecurityScopedResource() else { return }
        }
        counts[url] = current + 1
    }

    func release(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        guard let current = counts[url], current > 0 else { return }
        if current == 1 {
            url.stopAccessingSecurityScopedResource()
            counts.removeValue(forKey: url)
        } else {
            counts[url] = current - 1
        }
    }
}
