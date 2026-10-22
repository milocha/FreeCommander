import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var bookmarks: BookmarkStore
    @EnvironmentObject private var operations: OperationsEngine
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var leftPane = PaneViewModel(
        paneIndex: 0,
        location: PaneLocation.parse(UserDefaults.standard.string(forKey: "pane0.location")))
    @StateObject private var rightPane = PaneViewModel(
        paneIndex: 1,
        location: PaneLocation.parse(UserDefaults.standard.string(forKey: "pane1.location")))

    @State private var activePaneIndex = min(UserDefaults.standard.integer(forKey: "activePane"), 1)
    @State private var rootsSheetPane: PaneViewModel?
    @State private var settingsPresented = false

    @State private var deleteConfirmPresented = false
    @State private var newFolderPresented = false
    @State private var newFilePresented = false
    @State private var newName = ""
    @State private var renameTarget: RenamedItem?

    private var activePane: PaneViewModel { activePaneIndex == 0 ? leftPane : rightPane }
    private var otherPane: PaneViewModel { activePaneIndex == 0 ? rightPane : leftPane }
    private var isDualPane: Bool { horizontalSizeClass == .regular }

    var body: some View {
        mainStack
            .sheet(item: $rootsSheetPane) { pane in
                RootsSheet(pane: pane)
            }
            .sheet(isPresented: $settingsPresented) {
                SettingsSheet()
            }
            .modifier(DialogsModifier(
                operations: operations,
                deleteConfirmPresented: $deleteConfirmPresented,
                newFolderPresented: $newFolderPresented,
                newFilePresented: $newFilePresented,
                newName: $newName,
                renameTarget: $renameTarget,
                activePane: activePane))
            .onChange(of: activePaneIndex) { newValue in
                UserDefaults.standard.set(newValue, forKey: "activePane")
            }
            .onChange(of: settings.showHidden) { _ in
                leftPane.reload()
                rightPane.reload()
            }
            .onChange(of: settings.directoriesFirst) { _ in
                leftPane.reload()
                rightPane.reload()
            }
    }

    private var mainStack: some View {
        VStack(spacing: 0) {
            headerBar
            if operations.isRunning {
                progressLine
            }
            if isDualPane {
                HStack(spacing: 1) {
                    paneView(leftPane)
                    Rectangle().fill(Color.primary.opacity(0.15)).frame(width: 1)
                    paneView(rightPane)
                }
            } else {
                paneView(activePane)
            }
            BottomActionBar(
                activePane: activePane,
                otherPane: otherPane,
                isDualPane: isDualPane,
                onNewFolder: { newName = ""; newFolderPresented = true },
                onNewFile: { newName = ""; newFilePresented = true },
                onDelete: { deleteConfirmPresented = true })
        }
        .background(Color(.systemBackground))
    }

    private func paneView(_ pane: PaneViewModel) -> some View {
        FilePaneView(
            pane: pane,
            isActive: isDualPane ? pane.paneIndex == activePaneIndex : true,
            onActivate: { activePaneIndex = pane.paneIndex },
            onOpenRoots: { rootsSheetPane = pane },
            onRename: { item in
                newName = item.name
                renameTarget = RenamedItem(item: item, pane: pane)
            })
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.split.2x1")
                .foregroundStyle(Color.accentColor)
            Text("app.title")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
            if !isDualPane {
                Picker("pane.switcher", selection: $activePaneIndex) {
                    Text(String(format: NSLocalizedString("pane.title", comment: ""), 1)).tag(0)
                    Text(String(format: NSLocalizedString("pane.title", comment: ""), 2)).tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .labelsHidden()
            }
            Button {
                rootsSheetPane = activePane
            } label: {
                Image(systemName: "bookmark")
            }
            Button {
                settingsPresented = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var progressLine: some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(operations.progressText ?? "")
                .font(.caption)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.08))
    }
}

/// Wrapper do alertu zmiany nazwy — łączy element z panelem, w którym leży.
struct RenamedItem: Identifiable {
    let item: FileItem
    let pane: PaneViewModel
    var id: URL { item.url }
}

/// Wszystkie dialogi poziomu okna (błąd operacji, zmiana nazwy,
/// nowy folder/plik, potwierdzenie usuwania zaznaczenia).
private struct DialogsModifier: ViewModifier {
    @ObservedObject var operations: OperationsEngine
    @Binding var deleteConfirmPresented: Bool
    @Binding var newFolderPresented: Bool
    @Binding var newFilePresented: Bool
    @Binding var newName: String
    @Binding var renameTarget: RenamedItem?
    let activePane: PaneViewModel

    func body(content: Content) -> some View {
        content
            .alert("error.title", isPresented: Binding(
                get: { operations.alertMessage != nil },
                set: { if !$0 { operations.alertMessage = nil } })) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(operations.alertMessage ?? "")
            }
            .alert("action.rename", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }),
                presenting: renameTarget) { target in
                TextField("prompt.newName", text: $newName)
                Button("common.save") {
                    target.pane.rename(target.item, to: newName)
                }
                Button("common.cancel", role: .cancel) {}
            }
            .alert("action.newFolder", isPresented: $newFolderPresented) {
                TextField("prompt.folderName", text: $newName)
                Button("action.create") { activePane.createFolder(named: newName) }
                Button("common.cancel", role: .cancel) {}
            }
            .alert("action.newFile", isPresented: $newFilePresented) {
                TextField("prompt.fileName", text: $newName)
                Button("action.create") { activePane.createTextFile(named: newName) }
                Button("common.cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "confirm.delete.title",
                isPresented: $deleteConfirmPresented,
                titleVisibility: .visible) {
                Button("action.delete", role: .destructive) {
                    operations.deleteSelection(in: activePane)
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text(String(
                    format: NSLocalizedString("confirm.delete.message", comment: ""),
                    activePane.selectedURLs.count))
            }
    }
}
