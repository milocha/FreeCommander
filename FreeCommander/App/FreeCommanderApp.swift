import AppKit
import SwiftUI

@main
struct FreeCommanderApp: App {
    /// Tryb samoweryfikacji: `--fc-snapshot <ścieżka>` renderuje okno do PNG i kończy działanie.
    private let snapshotPath: String?

    init() {
        // Inicjalizacja store'ów POZA graphem widoku — leniwe `static let shared`
        // tworzone w środku budowania sceny potrafią opóźnić pokazanie okna.
        _ = SettingsStore.shared
        _ = OperationsEngine.shared
        _ = FavoritesStore.shared
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--fc-snapshot"), arguments.count > index + 1 {
            snapshotPath = arguments[index + 1]
            // Watch-dog poza wątkiem głównym: proces nie może wisieć w tle.
            DispatchQueue.global().asyncAfter(deadline: .now() + 180) {
                FileHandle.standardError.write("fc-snapshot: timeout\n".data(using: .utf8)!)
                exit(4)
            }
            // Poller na głównym wątku, niezależny od cyklu życia widoków SwiftUI.
            let target = arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Self.pollAndSnapshot(to: target, attempt: 0)
            }
        } else {
            snapshotPath = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SettingsStore.shared)
                .environmentObject(OperationsEngine.shared)
                .environmentObject(FavoritesStore.shared)
                .frame(minWidth: 980, minHeight: 560)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1150, height: 700)
        .commands {
            CommanderCommands()
        }
    }

    /// Zrzut własnego okna przez CGWindowListCreateImage — self-capture nie wymaga
    /// uprawnień Screen Recording, renderuje też materiały/vibrancy (sidebar),
    /// w przeciwieństwie do `cacheDisplay`.
    private static func pollAndSnapshot(to path: String, attempt: Int) {
        if attempt % 20 == 0 {
            FileHandle.standardError.write(String(
                format: "fc-snapshot: próba %d, okna=%d\n",
                attempt, NSApplication.shared.windows.count).data(using: .utf8)!)
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.isVisible }),
           let cgImage = CGWindowListCreateImage(
               .null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.bestResolution]) {
            let rep = NSBitmapImageRep(cgImage: cgImage)
            if let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
                exit(0)
            }
            FileHandle.standardError.write("fc-snapshot: brak PNG\n".data(using: .utf8)!)
            exit(2)
        }
        if attempt >= 300 {
            FileHandle.standardError.write("fc-snapshot: brak widocznego okna po 150 s\n".data(using: .utf8)!)
            exit(3)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pollAndSnapshot(to: path, attempt: attempt + 1)
        }
    }
}
