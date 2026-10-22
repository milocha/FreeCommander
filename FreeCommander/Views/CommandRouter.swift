import AppKit
import SwiftUI

/// Mostek między zdarzeniami klawiatury / menu a stanem ContentView.
/// ContentView podpina zamknięcia na każdą zmianę aktywnego panelu.
@MainActor
final class CommandRouter {
    static let shared = CommandRouter()

    var copy: () -> Void = {}
    var move: () -> Void = {}
    var newFolder: () -> Void = {}
    var deleteSelection: () -> Void = {}
    var rename: () -> Void = {}
    var preview: () -> Void = {}
    var openSelected: () -> Void = {}
    var switchPane: () -> Void = {}
    var goUp: () -> Void = {}
    var selectAll: () -> Void = {}
    var newFile: () -> Void = {}
    var info: () -> Void = {}
    var toggleHidden: () -> Void = {}
    var refresh: () -> Void = {}
    var navigateTo: (URL) -> Void = { _ in }
    var otherPaneProvider: (PaneViewModel) -> PaneViewModel = { $0 }

    // Skróty w standardzie macOS (Finder)
    var clipboardCopy: () -> Void = {}
    var clipboardCut: () -> Void = {}
    var clipboardPaste: () -> Void = {}
    var trashSelection: () -> Void = {}
    var toggleFilter: () -> Void = {}
    var setPane: (Int) -> Void = { _ in }

    private init() {}
}

/// Przechwytuje klawisze w stylu Total Commandera (gdy nie edytujemy pola tekstowego):
/// Tab — zmiana panelu, Enter — otwórz, Backspace — poziom wyżej,
/// F5 kopiuj, F6 przenieś, F7 nowy folder, F8 usuń, F2 zmień nazwę, Space — podgląd.
struct KeyboardMonitor: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.install()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.remove()
    }

    @MainActor
    final class Coordinator {
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: Self.handle)
        }

        func remove() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        nonisolated private static func handle(_ event: NSEvent) -> NSEvent? {
            MainActor.assumeIsolated {
                guard let window = event.window else { return event }
                // Nie przeszkadzaj w edycji pól tekstowych (ścieżka, filtr).
                if window.firstResponder is NSTextView { return event }

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let router = CommandRouter.shared
                let plain = flags.isEmpty || flags == .function
                let command = flags.contains(.command)
                let commandShift = flags == [.command, .shift] || flags == [.command, .shift, .function]

                // Najpierw kombinacje z Shift, potem czysty Cmd, na końcu klawisze TC.
                switch event.keyCode {
                case 45 where commandShift:  // Cmd+Shift+N — nowy folder (Finder)
                    router.newFolder(); return nil
                case 7 where command:        // Cmd+X — wytnij pliki
                    router.clipboardCut(); return nil
                case 8 where command:        // Cmd+C — kopiuje pliki
                    router.clipboardCopy(); return nil
                case 9 where command:        // Cmd+V — wklej pliki
                    router.clipboardPaste(); return nil
                case 34 where command:       // Cmd+I — informacje (Finder)
                    router.info(); return nil
                case 51 where command:       // Cmd+Delete — do Kosza (Finder)
                    router.trashSelection(); return nil
                case 31 where command:       // Cmd+O — otwórz
                    router.openSelected(); return nil
                case 125 where command:      // Cmd+Down — otwórz (Finder)
                    router.openSelected(); return nil
                case 126 where command:      // Cmd+Up — poziom wyżej (Finder)
                    router.goUp(); return nil
                case 18 where command:       // Cmd+1 — panel 1
                    router.setPane(0); return nil
                case 19 where command:       // Cmd+2 — panel 2
                    router.setPane(1); return nil
                case 3 where command:        // Cmd+F — filtr
                    router.toggleFilter(); return nil
                case 15 where command:       // Cmd+R — odśwież
                    router.refresh(); return nil
                case 48 where plain:  // Tab
                    router.switchPane(); return nil
                case 36 where plain:  // Enter
                    router.openSelected(); return nil
                case 49 where plain:  // Space
                    router.preview(); return nil
                case 51 where plain:  // Backspace
                    router.goUp(); return nil
                case 96 where plain:  // F5
                    router.copy(); return nil
                case 97 where plain:  // F6
                    router.move(); return nil
                case 99 where plain:  // F7
                    router.newFolder(); return nil
                case 100 where plain: // F8
                    router.deleteSelection(); return nil
                case 145 where plain: // F2
                    router.rename(); return nil
                case 0 where flags == .command: // Cmd+A
                    router.selectAll(); return nil
                default:
                    return event
                }
            }
        }
    }
}

/// Menu paska menu. Skróty Cmd są natywnie obsługiwane przez pozycje menu;
/// klawisze TC (F5–F8/F2/Tab/Enter/Space) przechwytuje KeyboardMonitor
/// (AppKit nie wspiera klawiszy funkcyjnych jako skrótów pozycji menu).
struct CommanderCommands: Commands {
    var body: some Commands {
        CommandMenu(NSLocalizedString("menu.files", comment: "")) {
            Button(NSLocalizedString("menu.clipboardCopy", comment: "")) { CommandRouter.shared.clipboardCopy() }
                .keyboardShortcut("c", modifiers: .command)
            Button(NSLocalizedString("menu.clipboardCut", comment: "")) { CommandRouter.shared.clipboardCut() }
                .keyboardShortcut("x", modifiers: .command)
            Button(NSLocalizedString("menu.clipboardPaste", comment: "")) { CommandRouter.shared.clipboardPaste() }
                .keyboardShortcut("v", modifiers: .command)
            Divider()
            Button(NSLocalizedString("menu.copy", comment: "")) { CommandRouter.shared.copy() }
            Button(NSLocalizedString("menu.move", comment: "")) { CommandRouter.shared.move() }
            Divider()
            Button(NSLocalizedString("menu.newFolder", comment: "")) { CommandRouter.shared.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button(NSLocalizedString("menu.rename", comment: "")) { CommandRouter.shared.rename() }
            Button(NSLocalizedString("menu.info", comment: "")) { CommandRouter.shared.info() }
                .keyboardShortcut("i", modifiers: .command)
            Divider()
            Button(NSLocalizedString("menu.trash", comment: "")) { CommandRouter.shared.trashSelection() }
                .keyboardShortcut(.delete, modifiers: [.command])
            Button(NSLocalizedString("menu.delete", comment: "")) { CommandRouter.shared.deleteSelection() }
            Button(NSLocalizedString("menu.preview", comment: "")) { CommandRouter.shared.preview() }
            Button(NSLocalizedString("menu.open", comment: "")) { CommandRouter.shared.openSelected() }
                .keyboardShortcut("o", modifiers: .command)
        }
        CommandMenu(NSLocalizedString("menu.go", comment: "")) {
            let userFavorites = FavoritesStore.shared.favorites
            if !userFavorites.isEmpty {
                ForEach(userFavorites) { favorite in
                    Button(favorite.name) { CommandRouter.shared.navigateTo(favorite.url) }
                }
                Divider()
            }
            ForEach(SystemLocations.favorites) { favorite in
                Button(favorite.name) { CommandRouter.shared.navigateTo(favorite.url) }
            }
            Divider()
            ForEach(SystemLocations.mountedVolumes()) { volume in
                Button(volume.name) { CommandRouter.shared.navigateTo(volume.url) }
            }
        }
        CommandMenu(NSLocalizedString("menu.view", comment: "")) {
            Button(String(format: NSLocalizedString("pane.title", comment: ""), 1)) { CommandRouter.shared.setPane(0) }
                .keyboardShortcut("1", modifiers: .command)
            Button(String(format: NSLocalizedString("pane.title", comment: ""), 2)) { CommandRouter.shared.setPane(1) }
                .keyboardShortcut("2", modifiers: .command)
            Divider()
            Button(NSLocalizedString("action.filter", comment: "")) { CommandRouter.shared.toggleFilter() }
                .keyboardShortcut("f", modifiers: .command)
            Button(NSLocalizedString("menu.toggleHidden", comment: "")) { CommandRouter.shared.toggleHidden() }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            Button(NSLocalizedString("action.refresh", comment: "")) { CommandRouter.shared.refresh() }
                .keyboardShortcut("r", modifiers: .command)
        }
    }
}

