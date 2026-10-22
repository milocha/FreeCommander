import SwiftUI

/// Lista lokalizacji dla aktywnego panelu: piaskownica aplikacji
/// + zapamiętane katalogi z aplikacji Pliki (security-scoped bookmarks).
struct RootsSheet: View {
    @EnvironmentObject private var bookmarks: BookmarkStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var pane: PaneViewModel
    @State private var addLocationPresented = false
    @State private var unavailableAlert: String?

    var body: some View {
        NavigationStack {
            List {
                Section("roots.builtin") {
                    row(titleKey: "roots.documents", icon: "internaldrive", color: .blue) {
                        pane.navigate(to: PaneLocation.documentsURL, location: .documents)
                        dismiss()
                    }
                    row(titleKey: "roots.temporary", icon: "clock", color: .gray) {
                        pane.navigate(to: PaneLocation.temporaryURL, location: .temporary)
                        dismiss()
                    }
                }
                Section {
                    ForEach(bookmarks.bookmarks) { bookmark in
                        row(title: bookmark.name, icon: "folder", color: .orange) {
                            guard let url = bookmarks.resolve(bookmark.id) else {
                                unavailableAlert = String(
                                    format: NSLocalizedString("roots.unavailable", comment: ""),
                                    bookmark.name)
                                return
                            }
                            pane.navigate(to: url, location: .bookmark(bookmark.id))
                            dismiss()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                bookmarks.remove(id: bookmark.id)
                            } label: {
                                Label("action.delete", systemImage: "trash")
                            }
                        }
                    }
                    if bookmarks.bookmarks.isEmpty {
                        Text("roots.noBookmarks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("roots.bookmarks")
                }
                Section {
                    Button {
                        addLocationPresented = true
                    } label: {
                        Label("roots.add", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("roots.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close") { dismiss() }
                }
            }
            .alert("error.title", isPresented: Binding(
                get: { unavailableAlert != nil },
                set: { if !$0 { unavailableAlert = nil } })) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(unavailableAlert ?? "")
            }
            .sheet(isPresented: $addLocationPresented) {
                FolderPicker { url in
                    addLocationPresented = false
                    add(url: url)
                } onCancel: {
                    addLocationPresented = false
                }
            }
        }
    }

    private func add(url: URL) {
        do {
            let bookmark = try bookmarks.add(url: url)
            pane.navigate(to: url, location: .bookmark(bookmark.id))
            dismiss()
        } catch {
            unavailableAlert = error.localizedDescription
        }
    }

    private func row(
        titleKey: LocalizedStringKey,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        rowContent(Text(titleKey), icon: icon, color: color, action: action)
    }

    private func row(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        rowContent(Text(verbatim: title), icon: icon, color: color, action: action)
    }

    private func rowContent(
        _ label: Text,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                label
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }
        }
        .buttonStyle(.borderless)
    }
}
