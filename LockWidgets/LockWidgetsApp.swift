import ServiceManagement
import SwiftUI

@main
struct LockWidgetsApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
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

        Window("Welcome to LockWidgets", id: "setup") {
            SetupGuide()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let openSettings = Notification.Name("LockWidgets.openSettings")

    /// True when macOS started the app at login, where opening a window would be unwelcome.
    private(set) static var launchedAtLogin = false

    func applicationWillFinishLaunching(_: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let loginItem = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        // Login items registered with SMAppService don't always carry that flag, so also treat a launch right after boot as one.
        Self.launchedAtLogin = loginItem || ProcessInfo.processInfo.systemUptime < 120
    }

    /// Opening the app again from Finder, Launchpad or the Dock shows its window.
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            NotificationCenter.default.post(name: Self.openSettings, object: nil)
        }
        return true
    }
}

/// The status item icon. It renders at launch, so it also opens the first window.
private struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.hasLaunched) private var hasLaunched = false

    var body: some View {
        Image(nsImage: MenuBarIcon.image)
            .onAppear {
                #if DEBUG
                if SettingsPage.launchPage != nil {
                    openWindow(id: "settings")
                    return
                }
                #endif
                if !hasLaunched {
                    openWindow(id: "setup")
                } else if !AppDelegate.launchedAtLogin {
                    openWindow(id: "settings")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppDelegate.openSettings)) { _ in
                openWindow(id: hasLaunched ? "settings" : "setup")
                NSApp.activate()
            }
    }
}

/// A lock screen with widgets on it, drawn as a template image so it tints with the menu bar.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: true) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let screen = NSBezierPath(roundedRect: NSRect(x: 1, y: 1.5, width: 18, height: 13), xRadius: 3, yRadius: 3)
            screen.lineWidth = 1.5
            screen.stroke()
            // System clock, top centre.
            NSBezierPath(roundedRect: NSRect(x: 8, y: 4, width: 4, height: 1.6), xRadius: 0.8, yRadius: 0.8).fill()
            // Widgets down the left and one on the right.
            NSBezierPath(roundedRect: NSRect(x: 3.5, y: 4, width: 3.5, height: 3), xRadius: 0.9, yRadius: 0.9).fill()
            NSBezierPath(roundedRect: NSRect(x: 3.5, y: 8.2, width: 3.5, height: 3.8), xRadius: 0.9, yRadius: 0.9).fill()
            NSBezierPath(roundedRect: NSRect(x: 13, y: 8.2, width: 3.5, height: 3.8), xRadius: 0.9, yRadius: 0.9).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

private struct MenuContent: View {
    @ObservedObject var overlay: OverlayManager
    @ObservedObject private var timers = TimerStore.shared
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.showOnLockScreen) private var showOnLockScreen = true

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        Text("LockWidgets \(version)")

        Divider()

        Button("Open Settings…") { open(.general) }
            .keyboardShortcut(",")
        Button("Open Layout Studio…") { open(.layoutStudio) }
        Button("Browse Layout Gallery…") { open(.gallery) }
        Button(showOnLockScreen ? "Hide Widgets on Lock Screen" : "Show Widgets on Lock Screen") {
            showOnLockScreen.toggle()
        }
        Button(overlay.isShowing ? "Hide Desktop Preview" : "Preview on Desktop") {
            overlay.toggle()
        }
        .keyboardShortcut("p")

        Divider()

        Menu("Pomodoro · \(timers.phase.title) \(timers.pomodoroRemaining().clockText)") {
            Button(timers.pomodoroRunning ? "Pause" : "Start") { timers.togglePomodoro() }
            Button("Skip to Next Session") { timers.skipPhase() }
            Button("Reset") { timers.resetPomodoro() }
        }
        Menu("Stopwatch · \(timers.stopwatchElapsed().clockText)") {
            Button(timers.stopwatchRunning ? "Stop" : "Start") { timers.toggleStopwatch() }
            Button("Reset") { timers.resetStopwatch() }
        }
        Button("Refresh Widgets") { overlay.refreshData() }
            .keyboardShortcut("r")

        Divider()

        Button("What's New…") { open(.whatsNew) }
        Menu("Help & Support") {
            Button("Setup Guide…") {
                openWindow(id: "setup")
                NSApp.activate()
            }
            Button("LockWidgets on GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/victorabuchi/lockwidgets")!)
            }
            Button("Report a Problem…") {
                NSWorkspace.shared.open(URL(string: "https://github.com/victorabuchi/lockwidgets/issues/new")!)
            }
        }
        Toggle("Launch at Login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            }
        ))

        Divider()

        Button("Quit LockWidgets") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func open(_ page: SettingsPage) {
        SettingsRouter.shared.page = page
        openWindow(id: "settings")
        NSApp.activate()
    }
}
