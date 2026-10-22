import SwiftUI

struct InfoSheet: View {
    let item: FileItem

    @State private var directorySize: Int64?
    @State private var computingSize = false
    @State private var containedCount: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledRow(label: NSLocalizedString("info.name", comment: ""), value: item.name)
                    LabeledRow(
                        label: NSLocalizedString("info.type", comment: ""),
                        value: item.isDirectory
                            ? NSLocalizedString("info.kindFolder", comment: "")
                            : NSLocalizedString("info.kindFile", comment: ""))
                    sizeRow
                    if item.isDirectory {
                        countRow
                    }
                }
                Section {
                    LabeledRow(
                        label: NSLocalizedString("info.modified", comment: ""),
                        value: item.modificationDate.map(Formatters.date) ?? "—")
                    LabeledRow(
                        label: NSLocalizedString("info.created", comment: ""),
                        value: item.creationDate.map(Formatters.date) ?? "—")
                }
                Section("info.path") {
                    Text(item.url.path(percentEncoded: false))
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("info.title")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard item.isDirectory else { return }
            computingSize = true
            let url = item.url
            let size = await FileSystemService.sizeOfDirectory(at: url)
            directorySize = size
            computingSize = false
            let values = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            containedCount = values?.count
        }
    }

    @ViewBuilder
    private var sizeRow: some View {
        if item.isDirectory {
            LabeledRow(
                label: NSLocalizedString("info.size", comment: ""),
                value: computingSize
                    ? NSLocalizedString("info.dirSizeComputing", comment: "")
                    : Formatters.size(directorySize ?? 0))
        } else {
            LabeledRow(
                label: NSLocalizedString("info.size", comment: ""),
                value: Formatters.size(item.size ?? 0))
        }
    }

    @ViewBuilder
    private var countRow: some View {
        if let count = containedCount {
            LabeledRow(
                label: NSLocalizedString("info.contents", comment: ""),
                value: String(format: NSLocalizedString("info.itemsCount", comment: ""), count))
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
