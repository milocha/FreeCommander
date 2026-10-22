import SwiftUI

struct InfoSheet: View {
    let item: FileItem

    @State private var directorySize: Int64?
    @State private var computingSize = false
    @State private var containedCount: Int?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    row(NSLocalizedString("info.name", comment: ""), item.name)
                    row(
                        NSLocalizedString("info.type", comment: ""),
                        item.isDirectory
                            ? NSLocalizedString("info.kindFolder", comment: "")
                            : NSLocalizedString("info.kindFile", comment: ""))
                    sizeRow
                    if item.isDirectory {
                        countRow
                    }
                }
                Section {
                    row(
                        NSLocalizedString("info.modified", comment: ""),
                        item.modificationDate.map(Formatters.date) ?? "—")
                    row(
                        NSLocalizedString("info.created", comment: ""),
                        item.creationDate.map(Formatters.date) ?? "—")
                }
                Section(NSLocalizedString("info.path", comment: "")) {
                    Text(item.url.path(percentEncoded: false))
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("common.close") {
                    NSApp.keyWindow?.performClose(nil)
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 420, height: 380)
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
            row(
                NSLocalizedString("info.size", comment: ""),
                computingSize
                    ? NSLocalizedString("info.dirSizeComputing", comment: "")
                    : Formatters.size(directorySize ?? 0))
        } else {
            row(
                NSLocalizedString("info.size", comment: ""),
                Formatters.size(item.size ?? 0))
        }
    }

    @ViewBuilder
    private var countRow: some View {
        if let count = containedCount {
            row(
                NSLocalizedString("info.contents", comment: ""),
                String(format: NSLocalizedString("info.itemsCount", comment: ""), count))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
