import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var operations: OperationsEngine

    @StateObject private var leftPane = PaneViewModel(paneIndex: 0)
    @StateObject private var rightPane = PaneViewModel(paneIndex: 1)

    @State private var activePaneIndex = UserDefaults.standard.object(forKey: "activePane") as? Int ?? 0
    @State private var deleteConfirmPresented = false
    @State private var newFolderPresented = false
    @State private var newFilePresented = false
    @State private var newName = ""

    private var activePane: PaneViewModel { activePaneIndex == 0 ? leftPane : rightPane }
    private var otherPane: PaneViewModel { activePaneIndex == 0 ? rightPane : leftPane }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            if operations.isRunning {
                progressLine
            }
            HStack(spacing: 1) {
                paneView(leftPane, index: 0)
                Rectangle().fill(Color.primary.opacity(0.2)).frame(width: 1)
                paneView(rightPane, index: 1)
            }
            BottomActionBar(
                activePane: activePane,
                onNewFolder: { newName = ""; newFolderPresented = true },
                onNewFile: { newName = ""; newFilePresented = true },
                onDelete: { deleteConfirmPresented = true })
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .modifier(WindowDialogsModifier(
            operations: operations,
            deleteConfirmPresented: $deleteConfirmPresented,
            newFolderPresented: $newFolderPresented,
            newFilePresented: $newFilePresented,
            newName: $newName,
            activePane: activePane))
        .onChange(of: activePaneIndex) { newValue in
            UserDefaults.standard.set(newValue, forKey: "activePane")
            bindRouter()
        }
        .onAppear { bindRouter() }
    }

    private func paneView(_ pane: PaneViewModel, index: Int) -> some View {
        FilePaneView(
            pane: pane,
            isActive: pane.paneIndex == activePaneIndex,
            onActivate: { activePaneIndex = index })
    }

    /// Podpina zamknięcia routera (klawiatura TC, menu) do aktualnych paneli.
    private func bindRouter() {
        let router = CommandRouter.shared
        router.copy = { operations.copySelection(from: activePane, to: otherPane) }
        router.move = { operations.moveSelection(from: activePane, to: otherPane) }
        router.newFolder = { newName = ""; newFolderPresented = true }
        router.newFile = { newName = ""; newFilePresented = true }
        router.deleteSelection = { deleteConfirmPresented = true }
        router.rename = {
            guard let first = activePane.selectedItems().first else { return }
            activePane.renameItem = first
        }
        router.preview = {
            guard let first = activePane.selectedItems().first else { return }
            activePane.requestPreview(first)
        }
        router.openSelected = {
            if let first = activePane.selectedItems().first {
                activePane.open(first)
            }
        }
        router.switchPane = { activePaneIndex = activePaneIndex == 0 ? 1 : 0 }
        router.goUp = { activePane.goUp() }
        router.selectAll = { activePane.selectAllVisible() }
        router.info = {
            guard let first = activePane.selectedItems().first else { return }
            activePane.infoItem = first
        }
        router.toggleHidden = {
            settings.showHidden.toggle()
            leftPane.reload()
            rightPane.reload()
        }
        router.refresh = {
            leftPane.reload()
            rightPane.reload()
        }
        router.navigateTo = { url in activePane.navigate(to: url) }
        router.otherPaneProvider = { pane in
            pane.paneIndex == leftPane.paneIndex ? rightPane : leftPane
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.split.2x1")
                .foregroundStyle(Color.accentColor)
            Text("app.title")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Text(String(
                format: NSLocalizedString("pane.activeHint", comment: ""),
                activePaneIndex + 1))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var progressLine: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(operations.progressText ?? "")
                .font(.caption)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(Color.accentColor.opacity(0.08))
    }
}

/// Dialogi poziomu okna (błąd operacji, nowy folder/plik,
/// potwierdzenie usuwania zaznaczenia). Zmiana nazwy i podgląd żyją w panelu.
private struct WindowDialogsModifier: ViewModifier {
    @ObservedObject var operations: OperationsEngine
    @Binding var deleteConfirmPresented: Bool
    @Binding var newFolderPresented: Bool
    @Binding var newFilePresented: Bool
    @Binding var newName: String
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
                Button("action.trash") {
                    operations.deleteSelection(in: activePane, mode: .trash)
                }
                Button("action.deletePermanent", role: .destructive) {
                    operations.deleteSelection(in: activePane, mode: .permanent)
                }
                Button("common.cancel", role: .cancel) {}
            } message: {
                Text(String(
                    format: NSLocalizedString("confirm.delete.message", comment: ""),
                    activePane.selectedURLs.count))
            }
    }
}
