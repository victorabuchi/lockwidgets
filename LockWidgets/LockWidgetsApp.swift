import SwiftUI

@main
struct LockWidgetsApp: App {
    @StateObject private var overlay = OverlayManager()

    var body: some Scene {
        MenuBarExtra("LockWidgets", systemImage: "square.grid.2x2") {
            MenuContent(overlay: overlay)
        }

        Settings {
            SettingsView(overlay: overlay)
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var overlay: OverlayManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(overlay.isShowing ? "Hide Preview" : "Preview on Desktop") {
            overlay.toggle()
        }
        .keyboardShortcut("p")

        Button("Refresh Widgets") {
            overlay.refreshData()
        }
        .keyboardShortcut("r")

        Divider()

        Button("Settings…") {
            // Menu bar apps are never frontmost, so bring the app forward or the window opens behind others.
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Quit LockWidgets") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
