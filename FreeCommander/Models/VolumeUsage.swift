import Foundation

/// Zajętość woluminu: całkowita pojemność i wolne miejsce.
struct VolumeUsage: Equatable, Sendable {
    let total: Int64
    let free: Int64

    var used: Int64 { max(0, total - free) }

    var usedPercent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(used) / Double(total) * 100).rounded())
    }
}

enum VolumeInfo {
    static func usage(for url: URL) -> VolumeUsage? {
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
        ])
        guard let total = values?.volumeTotalCapacity,
              let free = values?.volumeAvailableCapacityForImportantUsage,
              total > 0 else { return nil }
        return VolumeUsage(total: Int64(total), free: free)
    }
}
