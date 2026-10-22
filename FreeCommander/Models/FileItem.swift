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
}

enum SortField: String, CaseIterable, Identifiable {
    case name
    case modificationDate
    case size

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .name: return "sort.name"
        case .modificationDate: return "sort.date"
        case .size: return "sort.size"
        }
    }

    /// Klucz kolumny/NSSortDescriptor.
    var sortKey: String {
        switch self {
        case .name: return "name"
        case .modificationDate: return "date"
        case .size: return "size"
        }
    }

    static func fromSortKey(_ key: String) -> SortField? {
        allCases.first { $0.sortKey == key }
    }
}

enum SortDirection {
    case ascending
    case descending

    var toggled: SortDirection { self == .ascending ? .descending : .ascending }
    var titleKey: LocalizedStringKey { self == .ascending ? "sort.ascending" : "sort.descending" }

    var storageKey: String { self == .ascending ? "asc" : "desc" }
    static func parse(_ key: String?) -> SortDirection { key == "desc" ? .descending : .ascending }
}

/// Ulubione i woluminy dla menu lokalizacji panelu.
struct FavoriteLocation: Identifiable {
    let name: String
    let url: URL
    var id: String { name }
}

enum SystemLocations {
    static var favorites: [FavoriteLocation] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fm = FileManager.default
        var list: [FavoriteLocation] = [
            FavoriteLocation(name: NSLocalizedString("fav.home", comment: ""), url: home),
            FavoriteLocation(name: NSLocalizedString("fav.root", comment: ""), url: URL(fileURLWithPath: "/")),
            FavoriteLocation(name: NSLocalizedString("fav.applications", comment: ""), url: URL(fileURLWithPath: "/Applications")),
        ]
        for (key, nameKey) in [
            (FileManager.SearchPathDirectory.desktopDirectory, "fav.desktop"),
            (FileManager.SearchPathDirectory.documentDirectory, "fav.documents"),
            (FileManager.SearchPathDirectory.downloadsDirectory, "fav.downloads"),
        ] {
            if let url = fm.urls(for: key, in: .userDomainMask).first {
                list.append(FavoriteLocation(name: NSLocalizedString(nameKey, comment: ""), url: url))
            }
        }
        return list
    }

    static func mountedVolumes() -> [FavoriteLocation] {
        guard let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [.volumeIsBrowsableKey]) else {
            return []
        }
        return volumes.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.volumeIsBrowsableKey, .volumeNameKey])
            guard values?.volumeIsBrowsable == true else { return nil }
            let name = values?.volumeName ?? url.lastPathComponent
            return FavoriteLocation(name: name, url: url)
        }
    }
}
