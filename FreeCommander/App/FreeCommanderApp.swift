import AppKit
import SwiftUI

@main
struct FreeCommanderApp: App {
    /// Tryb samoweryfikacji: `--fc-snapshot <ścieżka>` renderuje okno do PNG i kończy działanie.
    private let snapshotPath: String?

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--fc-snapshot"), arguments.count > index + 1 {
            snapshotPath = arguments[index + 1]
        } else {
            snapshotPath = nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SettingsStore.shared)
                .environmentObject(OperationsEngine.shared)
                .frame(minWidth: 880, minHeight: 520)
                .task {
                    if let snapshotPath {
                        Self.takeSnapshot(to: snapshotPath)
                    }
                }
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1150, height: 700)
        .commands {
            CommanderCommands()
        }
    }

    /// Zrzut własnego okna (bez uprawnień Screen Recording — self-capture jest dozwolona).
    private static func takeSnapshot(to path: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let window = NSApplication.shared.windows.first(where: { $0.isVisible }),
                  let contentView = window.contentView else {
                FileHandle.standardError.write("fc-snapshot: brak okna\n".data(using: .utf8)!)
                exit(2)
            }
            let bounds = contentView.bounds
            guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
                FileHandle.standardError.write("fc-snapshot: brak reprezentacji bitmapy\n".data(using: .utf8)!)
                exit(2)
            }
            contentView.cacheDisplay(in: bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write("fc-snapshot: brak PNG\n".data(using: .utf8)!)
                exit(2)
            }
            try? png.write(to: URL(fileURLWithPath: path))
            exit(0)
        }
    }
}
