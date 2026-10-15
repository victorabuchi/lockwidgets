import ServiceManagement
import SwiftUI

@main
struct LockWidgetsApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var overlay: OverlayManager

    init() {
        // Before anything reads a setting.
        PreferencesMigration.run()
        _overlay = StateObject(wrappedValue: OverlayManager())
        IslandController.shared.start()
    }

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

    /// Keeps App Nap from slowing LockWidgets down in the background, so the island reacts instantly.
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        activity =ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "Live widgets and the Dynamic Island"
        )
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { DockPolicy.bringWindowsForward() }
            }
            .onReceive(NotificationCenter.default.publisher(for: AppDelegate.openSettings)) { _ in
                openWindow(id: hasLaunched ? "settings" : "setup")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { DockPolicy.bringWindowsForward() }
            }
    }
}

/// A padlock with a widget-shaped window in its body, drawn as a template so it tints with the menu bar.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let shackle = NSBezierPath()
            shackle.move(to: NSPoint(x: 5, y: 8))
            shackle.line(to: NSPoint(x: 5, y: 5.5))
            shackle.appendArc(withCenter: NSPoint(x: 9, y: 5.5), radius: 4, startAngle: 180, endAngle: 0, clockwise: false)
            shackle.line(to: NSPoint(x: 13, y: 8))
            shackle.lineWidth = 1.7
            shackle.stroke()
            let body = NSBezierPath(roundedRect: NSRect(x: 2.5, y: 7.5, width: 13, height: 9.5), xRadius: 2.6, yRadius: 2.6)
            body.append(NSBezierPath(roundedRect: NSRect(x: 5.5, y: 10.2, width: 7, height: 4), xRadius: 1.2, yRadius: 1.2).reversed)
            body.fill()
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
    @AppStorage(SettingsKey.islandEnabled) private var islandEnabled = true

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
        Button(islandEnabled ? "Hide Dynamic Island" : "Show Dynamic Island") {
            islandEnabled.toggle()
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { DockPolicy.bringWindowsForward() }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { DockPolicy.bringWindowsForward() }
    }
}
