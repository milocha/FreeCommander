import SwiftUI

struct FileRowView: View {
    let item: FileItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .foregroundStyle(item.iconColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts: [String] = [item.typeLabel]
        if let size = item.size {
            parts.append(Formatters.size(size))
        }
        if let date = item.modificationDate {
            parts.append(Formatters.date(date))
        }
        return parts.joined(separator: " · ")
    }
}
