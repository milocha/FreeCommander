import Foundation
import SwiftUI

struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let modificationDate: Date?
    let creationDate: Date?

    var id: URL { url }

    var fileExtension: String { url.pathExtension.lowercased() }
    var isArchive: Bool { fileExtension == "zip" }
    var typeLabel: String { isDirectory ? "DIR" : (fileExtension.isEmpty ? "—" : fileExtension.uppercased()) }

    var systemImage: String {
        if isDirectory { return "folder.fill" }
        switch fileExtension {
        case "zip": return "doc.zipper"
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "heic", "gif", "webp", "tiff": return "photo"
        case "mp3", "m4a", "wav", "aac", "flac": return "music.note"
        case "mp4", "mov", "m4v", "avi", "mkv": return "film"
        case "txt", "md", "log", "csv": return "doc.plaintext"
        case "doc", "docx", "rtf", "pages": return "doc.text"
        case "xls", "xlsx", "numbers": return "tablecells"
        case "key", "ppt", "pptx": return "rectangle.on.rectangle"
        case "app", "bundle", "framework": return "app"
        default: return "doc"
        }
    }

    var iconColor: Color {
        if isDirectory { return .blue }
        switch fileExtension {
        case "zip": return .orange
        case "pdf", "doc", "docx", "rtf", "pages": return .red
        case "png", "jpg", "jpeg", "heic", "gif", "webp", "tiff": return .green
        case "mp3", "m4a", "wav", "aac", "flac": return .pink
        case "mp4", "mov", "m4v", "avi", "mkv": return .purple
        default: return .gray
        }
    }
}

enum SortField: String, CaseIterable, Identifiable {
    case name
    case modificationDate
    case size
    case type

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .name: return "sort.name"
        case .modificationDate: return "sort.date"
        case .size: return "sort.size"
        case .type: return "sort.type"
        }
    }
}

enum SortDirection {
    case ascending
    case descending

    var toggled: SortDirection { self == .ascending ? .descending : .ascending }
    var titleKey: LocalizedStringKey { self == .ascending ? "sort.ascending" : "sort.descending" }
    var systemImage: String { self == .ascending ? "arrow.up" : "arrow.down" }

    var storageKey: String { self == .ascending ? "asc" : "desc" }
    static func parse(_ key: String?) -> SortDirection { key == "desc" ? .descending : .ascending }
}

/// Miejsca, z których panel może czytać dane. Na iOS nie ma dostępu do całego
/// systemu plików — piaskownica aplikacji + katalogi udostępnione przez
/// aplikację Pliki (security-scoped bookmark).
enum PaneLocation: Equatable {
    case documents
    case temporary
    case bookmark(UUID)

    static var documentsURL: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documents = urls[0]
        if !FileManager.default.fileExists(atPath: documents.path) {
            try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        }
        return documents
    }

    static var temporaryURL: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    @MainActor
    var url: URL {
        switch self {
        case .documents: return PaneLocation.documentsURL
        case .temporary: return PaneLocation.temporaryURL
        case .bookmark(let id): return BookmarkStore.shared.resolve(id) ?? PaneLocation.documentsURL
        }
    }

    var storageKey: String {
        switch self {
        case .documents: return "documents"
        case .temporary: return "temporary"
        case .bookmark(let id): return "bookmark:\(id.uuidString)"
        }
    }

    static func parse(_ key: String?) -> PaneLocation {
        guard let key else { return .documents }
        if key == "temporary" { return .temporary }
        if key == "documents" || key.isEmpty { return .documents }
        if key.hasPrefix("bookmark:") {
            let raw = String(key.dropFirst("bookmark:".count))
            if let id = UUID(uuidString: raw) { return .bookmark(id) }
        }
        return .documents
    }
}
