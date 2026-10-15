import SwiftUI

@main
struct LockWidgetsApp: App {
    @StateObject private var overlay = OverlayManager()

    var body: some Scene {
        MenuBarExtra("LockWidgets", systemImage: "square.grid.2x2") {
            Button("Preview for 5s") {
                overlay.show()
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { overlay.hide() }
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
