import Foundation
import ZIPFoundation

enum FileSystemService {
    static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isPackageKey, .fileSizeKey,
        .contentModificationDateKey, .creationDateKey,
    ]

    static func list(at url: URL, showHidden: Bool) async throws -> [FileItem] {
        try await Task.detached(priority: .userInitiated) {
            try listDirectorySync(at: url, showHidden: showHidden)
        }.value
    }

    static func listDirectorySync(at url: URL, showHidden: Bool) throws -> [FileItem] {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHidden { options.insert(.skipsHiddenFiles) }
        let contents = try FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: Array(resourceKeys), options: options)
        var items: [FileItem] = []
        items.reserveCapacity(contents.count)
        for itemURL in contents {
            let values = try? itemURL.resourceValues(forKeys: resourceKeys)
            let isPackage = values?.isPackage ?? false
            let isDirectory = (values?.isDirectory ?? false) && !isPackage
            let size: Int64? = isDirectory ? nil : Int64(values?.fileSize ?? 0)
            items.append(FileItem(
                url: itemURL,
                name: itemURL.lastPathComponent,
                isDirectory: isDirectory,
                size: size,
                modificationDate: values?.contentModificationDate,
                creationDate: values?.creationDate))
        }
        return items
    }

    static func sort(_ items: [FileItem], field: SortField, direction: SortDirection, directoriesFirst: Bool) -> [FileItem] {
        items.sorted { lhs, rhs in
            if directoriesFirst && lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            let cmp: ComparisonResult
            switch field {
            case .name:
                cmp = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            case .size:
                let l = lhs.size ?? -1
                let r = rhs.size ?? -1
                cmp = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
            case .modificationDate:
                let l = lhs.modificationDate ?? .distantPast
                let r = rhs.modificationDate ?? .distantPast
                cmp = l == r ? .orderedSame : (l < r ? .orderedAscending : .orderedDescending)
            case .type:
                cmp = lhs.typeLabel.localizedCaseInsensitiveCompare(rhs.typeLabel)
            }
            if cmp == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return direction == .ascending ? cmp == .orderedAscending : cmp == .orderedDescending
        }
    }

    // MARK: - Operacje na plikach

    static func copySync(from source: URL, toDirectory destination: URL) throws -> URL {
        try guardNotIntoSelf(source: source, destination: destination)
        let target = uniqueURL(for: source.lastPathComponent, in: destination)
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    static func moveSync(from source: URL, toDirectory destination: URL) throws -> URL {
        try guardNotIntoSelf(source: source, destination: destination)
        let target = uniqueURL(for: source.lastPathComponent, in: destination)
        do {
            try FileManager.default.moveItem(at: source, to: target)
            return target
        } catch {
            // Różne piaskownice/wolumeny: przenieś przez kopię.
            try FileManager.default.copyItem(at: source, to: target)
            try? FileManager.default.removeItem(at: source)
            return target
        }
    }

    static func renameSync(_ source: URL, to newName: String) throws -> URL {
        let target = source.deletingLastPathComponent().appendingPathComponent(newName)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw CocoaError(.fileWriteFileExists, userInfo: [NSFilePathErrorKey: target.path])
        }
        try FileManager.default.moveItem(at: source, to: target)
        return target
    }

    static func uniqueURL(for name: String, in directory: URL) -> URL {
        var candidate = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var counter = 2
        repeat {
            let newName = ext.isEmpty ? "\(base) (\(counter))" : "\(base) (\(counter)).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)
        return candidate
    }

    static func zip(urls: [URL], baseName: String, in directory: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let target = uniqueURL(for: "\(baseName).zip", in: directory)
            if urls.count == 1 {
                try FileManager.default.zipItem(at: urls[0], to: target)
            } else {
                let stagingRoot = FileManager.default.temporaryDirectory
                    .appendingPathComponent("fc-zip-\(UUID().uuidString)", isDirectory: true)
                let staging = stagingRoot.appendingPathComponent(baseName, isDirectory: true)
                try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: stagingRoot) }
                for url in urls {
                    let itemTarget = staging.appendingPathComponent(url.lastPathComponent)
                    do {
                        try FileManager.default.linkItem(at: url, to: itemTarget)
                    } catch {
                        try FileManager.default.copyItem(at: url, to: itemTarget)
                    }
                }
                try FileManager.default.zipItem(at: staging, to: target)
            }
            return target
        }.value
    }

    static func unzip(url: URL, in directory: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let base = (url.lastPathComponent as NSString).deletingPathExtension
            let target = uniqueURL(for: base, in: directory)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try FileManager.default.unzipItem(at: url, to: target)
            return target
        }.value
    }

    static func sizeOfDirectory(at url: URL) async -> Int64 {
        await Task.detached(priority: .utility) {
            computeDirectorySize(url)
        }.value
    }

    private static func computeDirectorySize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsPackageDescendants]) else { return 0 }
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true {
                total += Int64(values?.fileSize ?? 0)
            }
        }
        return total
    }

    private static func guardNotIntoSelf(source: URL, destination: URL) throws {
        let values = try? source.resourceValues(forKeys: [.isDirectoryKey])
        guard values?.isDirectory == true else { return }
        let srcPath = source.standardizedFileURL.path + "/"
        let dstPath = destination.standardizedFileURL.path + "/"
        if dstPath.hasPrefix(srcPath) {
            throw CocoaError(.fileWriteVolumeReadOnly, userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString("error.intoSelf", comment: ""),
            ])
        }
    }
}
