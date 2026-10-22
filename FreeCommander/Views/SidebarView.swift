import SwiftUI

/// Lewy panel w stylu nowoczesnych aplikacji: ulubione (systemowe + własne),
/// dyski z paskiem zajętości (GB i %) oraz stopka dysku aktywnego panelu.
struct SidebarView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject var activePane: PaneViewModel
    let navigate: (URL) -> Void

    @State private var volumeEntries: [FavoriteLocation] = []
    @State private var usageByPath: [String: VolumeUsage] = [:]

    var body: some View {
        List {
            Section(NSLocalizedString("sidebar.favorites", comment: "")) {
                ForEach(SystemLocations.favorites) { favorite in
                    favoriteRow(favorite, systemImage: systemIcon(for: favorite))
                }
                ForEach(favorites.favorites) { favorite in
                    favoriteRow(
                        FavoriteLocation(name: favorite.name, url: favorite.url),
                        systemImage: "star.fill")
                        .contextMenu {
                            Button(NSLocalizedString("fav.remove", comment: "")) {
                                favorites.remove(id: favorite.id)
                            }
                        }
                }
                if favorites.favorites.isEmpty {
                    Text("fav.hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section(NSLocalizedString("sidebar.volumes", comment: "")) {
                ForEach(volumeEntries) { volume in
                    volumeRow(volume)
                }
                if volumeEntries.isEmpty {
                    Text("…")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarDiskFooter(pane: activePane)
        }
        .onAppear {
            refreshVolumes()
        }
    }

    // MARK: - Wiersze

    private func favoriteRow(_ favorite: FavoriteLocation, systemImage: String) -> some View {
        Button {
            navigate(favorite.url)
        } label: {
            Label {
                Text(favorite.name)
                    .fontWeight(isActiveLocation(favorite.url) ? .semibold : .regular)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(isActiveLocation(favorite.url) ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func volumeRow(_ volume: FavoriteLocation) -> some View {
        Button {
            navigate(volume.url)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Label {
                    Text(volume.name)
                        .fontWeight(isActiveLocation(volume.url) ? .semibold : .regular)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(Color.secondary)
                }
                if let usage = usageByPath[volume.url.path] {
                    ProgressView(value: Double(usage.used), total: Double(max(usage.total, 1)))
                        .progressViewStyle(.linear)
                        .tint(barColor(for: usage.usedPercent))
                    Text(String(
                        format: NSLocalizedString("volume.usage", comment: ""),
                        Formatters.size(usage.used),
                        usage.usedPercent))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pomocnicze

    private var volumePaths: [String] {
        volumeEntries.map { $0.url.path }
    }

    private func isActiveLocation(_ url: URL) -> Bool {
        let panePath = activePane.directory.standardizedFileURL.path
        let locationPath = url.standardizedFileURL.path
        if panePath == locationPath { return true }
        return panePath.hasPrefix(locationPath.hasSuffix("/") ? locationPath : locationPath + "/")
    }

    private func systemIcon(for favorite: FavoriteLocation) -> String {
        let path = favorite.url.standardizedFileURL.path
        switch path {
        case "/": return "desktopcomputer"
        case "/Applications": return "square.grid.3x1.folder.badge.plus"
        case FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path: return "house"
        default: break
        }
        if favorite.name == NSLocalizedString("fav.desktop", comment: "") { return "menubar.dock.rectangle" }
        if favorite.name == NSLocalizedString("fav.documents", comment: "") { return "doc" }
        if favorite.name == NSLocalizedString("fav.downloads", comment: "") { return "arrow.down.circle" }
        return "folder"
    }

    private func barColor(for percent: Int) -> Color {
        if percent >= 90 { return .red }
        if percent >= 75 { return .orange }
        return .accentColor
    }

    private func refreshVolumes() {
        volumeEntries = SystemLocations.mountedVolumes()
        var result: [String: VolumeUsage] = [:]
        for volume in volumeEntries {
            if let usage = VolumeInfo.usage(for: volume.url) {
                result[volume.url.path] = usage
            }
        }
        usageByPath = result
    }
}

/// Stopka sidebaru: pasek zajętości dysku, na którym leży aktywny panel.
struct SidebarDiskFooter: View {
    @ObservedObject var pane: PaneViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let usage = pane.volumeUsage {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(pane.directory.firstPathComponentOfVolume ?? "—")
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text(String(
                        format: NSLocalizedString("disk.freeShort", comment: ""),
                        Formatters.size(usage.free)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                ProgressView(value: Double(usage.used), total: Double(max(usage.total, 1)))
                    .progressViewStyle(.linear)
                    .tint(usage.usedPercent >= 90 ? Color.red : (usage.usedPercent >= 75 ? Color.orange : Color.accentColor))
                Text(String(
                    format: NSLocalizedString("disk.usedOfFormat", comment: ""),
                    Formatters.size(usage.used),
                    Formatters.size(usage.total),
                    usage.usedPercent))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("disk.unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}

private extension URL {
    /// Nazwa woluminu dla ścieżki (do stopki sidebaru).
    var firstPathComponentOfVolume: String? {
        (try? resourceValues(forKeys: [.volumeNameKey]))?.volumeName
    }
}
