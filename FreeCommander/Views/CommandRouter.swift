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

                switch event.keyCode {
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

/// Menu paska menu z tymi samymi akcjami. Skróty F5–F8/F2/Tab/Enter/Space obsługuje
/// KeyboardMonitor (AppKit nie wspiera klawiszy funkcyjnych jako skrótów pozycji menu),
/// więc w menu są one tylko opisane w tytułach.
struct CommanderCommands: Commands {
    var body: some Commands {
        CommandMenu(NSLocalizedString("menu.files", comment: "")) {
            Button(NSLocalizedString("menu.copy", comment: "")) { CommandRouter.shared.copy() }
            Button(NSLocalizedString("menu.move", comment: "")) { CommandRouter.shared.move() }
            Button(NSLocalizedString("menu.newFolder", comment: "")) { CommandRouter.shared.newFolder() }
            Button(NSLocalizedString("menu.rename", comment: "")) { CommandRouter.shared.rename() }
            Divider()
            Button(NSLocalizedString("menu.delete", comment: "")) { CommandRouter.shared.deleteSelection() }
            Button(NSLocalizedString("menu.preview", comment: "")) { CommandRouter.shared.preview() }
            Button(NSLocalizedString("menu.open", comment: "")) { CommandRouter.shared.openSelected() }
        }
        CommandMenu(NSLocalizedString("menu.go", comment: "")) {
            ForEach(SystemLocations.favorites) { favorite in
                Button(favorite.name) { CommandRouter.shared.navigateTo(favorite.url) }
            }
            Divider()
            ForEach(SystemLocations.mountedVolumes()) { volume in
                Button(volume.name) { CommandRouter.shared.navigateTo(volume.url) }
            }
        }
        CommandMenu(NSLocalizedString("menu.view", comment: "")) {
            Button(NSLocalizedString("menu.toggleHidden", comment: "")) { CommandRouter.shared.toggleHidden() }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            Button(NSLocalizedString("action.refresh", comment: "")) { CommandRouter.shared.refresh() }
        }
    }
}

