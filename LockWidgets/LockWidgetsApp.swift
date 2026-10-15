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
        .defaultSize(width: 1100, height: 740)
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

/// Four widget tiles with a keyhole cut through the middle, drawn as a template so it tints with the menu bar.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.black.setFill()
            for (x, y) in [(1.0, 1.0), (10.0, 1.0), (1.0, 10.0), (10.0, 10.0)] {
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 7, height: 7), xRadius: 2, yRadius: 2).fill()
            }
            // Clear a keyhole-shaped window through the tiles…
            context.setBlendMode(.clear)
            NSBezierPath(ovalIn: NSRect(x: 6, y: 4.6, width: 6, height: 6)).fill()
            let opening = NSBezierPath()
            opening.move(to: NSPoint(x: 7.6, y: 8))
            opening.line(to: NSPoint(x: 10.4, y: 8))
            opening.line(to: NSPoint(x: 11.2, y: 14.2))
            opening.line(to: NSPoint(x: 6.8, y: 14.2))
            opening.close()
            opening.fill()
            // …then draw the keyhole itself inside it.
            context.setBlendMode(.normal)
            NSBezierPath(ovalIn: NSRect(x: 7.4, y: 6, width: 3.2, height: 3.2)).fill()
            let stem = NSBezierPath()
            stem.move(to: NSPoint(x: 8.3, y: 8.4))
            stem.line(to: NSPoint(x: 9.7, y: 8.4))
            stem.line(to: NSPoint(x: 10.1, y: 12.6))
            stem.line(to: NSPoint(x: 7.9, y: 12.6))
            stem.close()
            stem.fill()
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
