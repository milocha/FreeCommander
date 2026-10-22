import SwiftUI

struct FilePaneView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var operations: OperationsEngine
    @EnvironmentObject private var favorites: FavoritesStore

    @ObservedObject var pane: PaneViewModel
    let isActive: Bool
    let onActivate: () -> Void

    @State private var pathText = ""
    @FocusState private var pathFocused: Bool
    @State private var renameText = ""

    var body: some View {
        VStack(spacing: 0) {
            pathBar
            if pane.showFilter {
                filterField
            }
            if let error = pane.errorMessage {
                errorBanner(error)
            }
            fileList
            statusBar
        }
        .background(isActive ? Color.accentColor.opacity(0.05) : Color.clear)
        .overlay(
            Rectangle()
                .strokeBorder(isActive ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: 1.5)
        )
        .onAppear {
            pathText = pane.directory.path(percentEncoded: false)
        }
        .onChange(of: pane.directory) { newValue in
            if !pathFocused {
                pathText = newValue.path(percentEncoded: false)
            }
        }
        .onChange(of: pane.renameItem) { item in
            if let item {
                renameText = item.name
            }
        }
        .sheet(item: infoBinding) { item in
            InfoSheet(item: item)
        }
        .sheet(item: previewBinding) { wrapper in
            QuickLookView(url: wrapper.url)
                .frame(width: 780, height: 540)
        }
        .alert("action.rename", isPresented: Binding(
            get: { pane.renameItem != nil },
            set: { if !$0 { pane.renameItem = nil } })) {
            TextField("prompt.newName", text: $renameText)
            Button("common.save") {
                if let target = pane.renameItem {
                    pane.rename(target, to: renameText)
                }
            }
            Button("common.cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "confirm.delete.single.title",
            isPresented: Binding(
                get: { pane.deleteRequest != nil },
                set: { if !$0 { pane.deleteRequest = nil } }),
            titleVisibility: .visible) {
            Button("action.trash") {
                if let target = pane.deleteRequest {
                    operations.delete([target], in: pane, mode: .trash)
                }
            }
            Button("action.deletePermanent", role: .destructive) {
                if let target = pane.deleteRequest {
                    operations.delete([target], in: pane, mode: .permanent)
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(String(
                format: NSLocalizedString("confirm.delete.single.message", comment: ""),
                pane.deleteRequest?.name ?? ""))
        }
    }

    private var infoBinding: Binding<FileItem?> {
        Binding(
            get: { pane.infoItem },
            set: { pane.infoItem = $0 })
    }

    private var previewBinding: Binding<PreviewItem?> {
        Binding(
            get: { pane.previewURL.map(PreviewItem.init) },
            set: { pane.previewURL = $0?.url })
    }

    // MARK: - Belka ścieżki

    private var pathBar: some View {
        HStack(spacing: 6) {
            Menu {
                Section(NSLocalizedString("roots.favorites", comment: "")) {
                    ForEach(SystemLocations.favorites) { favorite in
                        Button(favorite.name) {
                            pane.navigate(to: favorite.url)
                        }
                    }
                }
                Section(NSLocalizedString("roots.volumes", comment: "")) {
                    ForEach(SystemLocations.mountedVolumes()) { volume in
                        Button(volume.name) {
                            pane.navigate(to: volume.url)
                        }
                    }
                }
            } label: {
                Image(systemName: "internaldrive")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            TextField("path.placeholder", text: $pathText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))
                .focused($pathFocused)
                .onSubmit {
                    var isDirectory: ObjCBool = false
                    let expanded = (pathText as NSString).expandingTildeInPath
                    if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory) {
                        pane.navigate(to: URL(fileURLWithPath: expanded, isDirectory: isDirectory.boolValue))
                    } else {
                        pane.errorMessage = String(
                            format: NSLocalizedString("error.listing", comment: ""),
                            pathText, NSLocalizedString("error.noSuchPath", comment: ""))
                    }
                }
                .onTapGesture { onActivate() }

            Button {
                pane.goUp()
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!pane.canGoUp)
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
                favorites.add(url: pane.directory)
            } label: {
                Image(systemName: favorites.contains(url: pane.directory) ? "star.fill" : "star")
                    .foregroundStyle(favorites.contains(url: pane.directory) ? Color.yellow : Color.primary)
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("fav.addCurrent", comment: ""))

            Button {
                pane.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private var filterField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("action.filter", text: $pane.filterText)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .lineLimit(2)
            Spacer()
            Button {
                pane.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.12))
    }

    // MARK: - Lista

    private var fileList: some View {
        ZStack {
            FileListView(
                pane: pane,
                onActivate: onActivate,
                onOpen: { pane.open($0) })
            if !pane.isLoading && pane.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("empty.title")
                        .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
    }

    // MARK: - Pasek statusu

    private var statusBar: some View {
        HStack {
            Text(pane.isLoading ? "…" : pane.statusSummary)
            if let usage = pane.volumeUsage {
                Text(String(
                    format: NSLocalizedString("status.free", comment: ""),
                    Formatters.size(usage.free),
                    usage.usedPercent))
                    .help(String(
                        format: NSLocalizedString("disk.usedOfFormat", comment: ""),
                        Formatters.size(usage.used),
                        Formatters.size(usage.total),
                        usage.usedPercent))
            }
            Spacer()
            if !pane.selectedURLs.isEmpty {
                Text(pane.selectionSummary)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

struct PreviewItem: Identifiable {
    let url: URL
    var id: URL { url }
}
