import SwiftUI

@main
struct LockWidgetsApp: App {
    @StateObject private var overlay = OverlayManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(overlay: overlay)
        } label: {
            MenuBarLabel()
        }

        Window("LockWidgets", id: "settings") {
            SettingsWindow(overlay: overlay)
        }
        .defaultSize(width: 920, height: 680)
        .defaultLaunchBehavior(.suppressed)
    }
}

/// The status item icon. It renders at launch, so it doubles as the hook for opening settings on first run.
private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasLaunched) private var hasLaunched = false

    var body: some View {
        Image(systemName: "square.grid.2x2")
            .onAppear {
                #if DEBUG
                if SettingsPage.launchPage != nil { openWindow(id: "settings") }
                #endif
                guard !hasLaunched else { return }
                hasLaunched = true
                openWindow(id: "settings")
            }
    }
}

private struct MenuContent: View {
    @ObservedObject var overlay: OverlayManager
    @Environment(\.openWindow) private var openWindow

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
            openWindow(id: "settings")
            NSApp.activate()
        }
        .keyboardShortcut(",")

        Button("Quit LockWidgets") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
