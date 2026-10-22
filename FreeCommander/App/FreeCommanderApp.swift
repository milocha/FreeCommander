import SwiftUI

@main
struct FreeCommanderApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var bookmarks = BookmarkStore.shared
    @StateObject private var operations = OperationsEngine.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(bookmarks)
                .environmentObject(operations)
        }
    }
}
