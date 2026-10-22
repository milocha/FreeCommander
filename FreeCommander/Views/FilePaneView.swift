import QuickLook
import SwiftUI

struct FilePaneView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var operations: OperationsEngine

    @ObservedObject var pane: PaneViewModel
    let isActive: Bool
    let onActivate: () -> Void
    let onOpenRoots: () -> Void
    let onRename: (FileItem) -> Void

    @State private var deleteTarget: FileItem?
    @State private var infoItem: FileItem?
    @State private var shareItem: ShareItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            if pane.showFilter {
                filterField
            }
            if let error = pane.errorMessage {
                errorBanner(error)
            }
            content
            statusBar
        }
        .background(isActive ? Color.accentColor.opacity(0.04) : Color.clear)
        .overlay(
            Rectangle()
                .strokeBorder(isActive ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .quickLookPreview($pane.previewURL)
        .sheet(item: $infoItem) { item in
            InfoSheet(item: item)
        }
        .sheet(item: $shareItem) { wrapper in
            ShareSheet(items: [wrapper.url])
        }
        .confirmationDialog(
            "confirm.delete.single.title",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible) {
            if let target = deleteTarget {
                Button("action.delete", role: .destructive) {
                    operations.delete([target], in: pane)
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(String(
                format: NSLocalizedString("confirm.delete.single.message", comment: ""),
                deleteTarget?.name ?? ""))
        }
    }

    // MARK: - Nagłówek panelu

    private var header: some View {
        HStack(spacing: 10) {
            Text(String(format: NSLocalizedString("pane.title", comment: ""), pane.paneIndex + 1))
                .font(.caption.weight(.bold))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)

            Button(action: onOpenRoots) {
                HStack(spacing: 4) {
                    Image(systemName: locationIcon)
                    Text(pane.directory.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .font(.subheadline)
            }
            .buttonStyle(.borderless)

            Spacer(minLength: 4)

            Button {
                pane.goUp()
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!pane.canGoUp)
            .buttonStyle(.borderless)

            Menu {
                Picker("sort.title", selection: $pane.sortField) {
                    ForEach(SortField.allCases) { field in
                        Text(field.titleKey).tag(field)
                    }
                }
                Button {
                    pane.sortDirection = pane.sortDirection.toggled
                } label: {
                    Label(pane.sortDirection.titleKey, systemImage: pane.sortDirection.systemImage)
                }
                Divider()
                Button {
                    pane.selectAllVisible()
                } label: {
                    Label("action.selectAll", systemImage: "checkmark.circle")
                }
                Button {
                    pane.clearSelection()
                } label: {
                    Label("action.deselectAll", systemImage: "circle")
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .buttonStyle(.borderless)

            Button {
                pane.showFilter.toggle()
                if !pane.showFilter { pane.filterText = "" }
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(pane.filterText.isEmpty ? Color.primary : Color.accentColor)
            }
            .buttonStyle(.borderless)

            Button {
                pane.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var locationIcon: String {
        switch pane.location {
        case .documents: return "internaldrive"
        case .temporary: return "clock"
        case .bookmark: return "folder"
        }
    }

    private var filterField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("action.filter", text: $pane.filterText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            Button {
                pane.filterText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .opacity(pane.filterText.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .lineLimit(3)
            Spacer()
            Button {
                pane.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.12))
    }

    // MARK: - Lista

    @ViewBuilder
    private var content: some View {
        if pane.items.isEmpty && !pane.isLoading {
            ContentUnavailableView {
                Label("empty.title", systemImage: "folder")
            } description: {
                Text("empty.hint")
            }
        } else if pane.visibleItems.isEmpty && !pane.filterText.isEmpty {
            ContentUnavailableView {
                Label("empty.filter", systemImage: "magnifyingglass")
            } description: {
                Text("empty.filterHint")
            }
        } else {
            List {
                ForEach(pane.visibleItems) { item in
                    row(for: item)
                }
            }
            .listStyle(.plain)
            .overlay {
                if pane.isLoading && pane.items.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private func row(for item: FileItem) -> some View {
        let isSelected = pane.selectedURLs.contains(item.url)
        return FileRowView(item: item, isSelected: isSelected)
            .contentShape(Rectangle())
            .onTapGesture {
                onActivate()
                if pane.selectedURLs.isEmpty {
                    pane.open(item)
                } else {
                    pane.toggleSelection(item)
                }
            }
            .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .listRowSeparator(.hidden)
            .contextMenu {
                if item.isDirectory {
                    Button {
                        pane.open(item)
                    } label: {
                        Label("action.openFolder", systemImage: "folder")
                    }
                } else {
                    Button {
                        pane.previewURL = item.url
                    } label: {
                        Label("action.preview", systemImage: "eye")
                    }
                }
                Button {
                    pane.toggleSelection(item)
                } label: {
                    Label("action.select", systemImage: isSelected ? "circle" : "checkmark.circle")
                }
                Button {
                    pane.duplicate(item)
                } label: {
                    Label("action.duplicate", systemImage: "plus.square.on.square")
                }
                Button {
                    onRename(item)
                } label: {
                    Label("action.rename", systemImage: "pencil")
                }
                Button {
                    operations.zipSelection(in: pane)
                } label: {
                    Label("action.zip", systemImage: "doc.zipper")
                }
                .disabled(pane.selectedURLs.isEmpty)
                Button {
                    pane.selectedURLs.insert(item.url)
                    operations.zipSelection(in: pane)
                } label: {
                    Label("action.zipSingle", systemImage: "doc.zipper")
                }
                if item.isArchive {
                    Button {
                        operations.unzip(item, in: pane)
                    } label: {
                        Label("action.unzip", systemImage: "arrow.down.doc")
                    }
                }
                Button {
                    infoItem = item
                } label: {
                    Label("action.info", systemImage: "info.circle")
                }
                Button {
                    shareItem = ShareItem(url: item.url)
                } label: {
                    Label("action.share", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) {
                    deleteTarget = item
                } label: {
                    Label("action.delete", systemImage: "trash")
                }
            }
    }

    private var statusBar: some View {
        HStack {
            Text(pane.statusSummary)
            Spacer()
            if !pane.selectedURLs.isEmpty {
                Text(pane.selectionSummary)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(.secondarySystemBackground))
    }
}

struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}
