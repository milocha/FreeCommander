import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var bookmarks: BookmarkStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.listSection") {
                    Toggle("settings.showHidden", isOn: $settings.showHidden)
                    Toggle("settings.directoriesFirst", isOn: $settings.directoriesFirst)
                }
                Section("roots.bookmarks") {
                    ForEach(bookmarks.bookmarks) { bookmark in
                        Label(bookmark.name, systemImage: "folder")
                    }
                    if bookmarks.bookmarks.isEmpty {
                        Text("roots.noBookmarks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("settings.about") {
                    LabeledRow(
                        labelKey: "info.version",
                        value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    Text("settings.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
        }
    }
}

private struct LabeledRow: View {
    let labelKey: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(labelKey)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
