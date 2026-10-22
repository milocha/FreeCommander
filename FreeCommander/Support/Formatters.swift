import Foundation

enum Formatters {
    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    static func size(_ bytes: Int64) -> String {
        byteCountFormatter.string(fromByteCount: bytes)
    }

    static func date(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}
