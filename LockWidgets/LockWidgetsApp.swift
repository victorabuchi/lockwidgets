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

        Window("Notchlight", id: "settings") {
            SettingsWindow(overlay: overlay)
        }
        .defaultSize(width: 1100, height: 740)
        .defaultLaunchBehavior(.suppressed)

        Window("Welcome to Notchlight", id: "setup") {
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
        Updater.shared.start()
        activity = ProcessInfo.processInfo.beginActivity(
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

/// The island playing a song: a capsule with the artwork and waveform cut out of it, in one shape, drawn
/// as a template so it tints with the menu bar.
enum MenuBarIcon {
    static let image: NSImage = {
        // As wide as the battery icon beside it, so it holds its own in the menu bar.
        let image = NSImage(size: NSSize(width: 26, height: 18), flipped: true) { _ in
            NSColor.black.setFill()
            let island = NSBezierPath(roundedRect: NSRect(x: 1, y: 4, width: 24, height: 10), xRadius: 5, yRadius: 5)
            island.append(NSBezierPath(roundedRect: NSRect(x: 3.5, y: 6.25, width: 5.5, height: 5.5), xRadius: 1.5, yRadius: 1.5).reversed)
            for (i, height) in [3.4, 6.0, 4.4, 5.2].enumerated() {
                let bar = NSRect(x: 13.05 + CGFloat(i) * 2.8, y: 9 - height / 2, width: 1.5, height: height)
                island.append(NSBezierPath(roundedRect: bar, xRadius: 0.75, yRadius: 0.75).reversed)
            }
            island.fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

private struct MenuContent: View {
    @ObservedObject var overlay: OverlayManager
    @ObservedObject private var timers = TimerStore.shared
    @ObservedObject private var updater = Updater.shared
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.showOnLockScreen) private var showOnLockScreen = true
    @AppStorage(SettingsKey.islandEnabled) private var islandEnabled = true

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    var body: some View {
        Text("Notchlight \(version)")
        if let available = updater.availableVersion {
            Button("Update to Notchlight \(available)…") { updater.checkForUpdates() }
        }

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
        Button("Check for Updates…") { updater.checkForUpdates() }
        Menu("Help & Support") {
            Button("Setup Guide…") {
                openWindow(id: "setup")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { DockPolicy.bringWindowsForward() }
            }
            Button("Notchlight on GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/victorabuchi/notchlight")!)
            }
            Button("Report a Problem…") {
                NSWorkspace.shared.open(URL(string: "https://github.com/victorabuchi/notchlight/issues/new")!)
            }
        }
        Toggle("Launch at Login", isOn: Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { enabled in
                try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            }
        ))

        Divider()

        Button("Quit Notchlight") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func open(_ page: SettingsPage) {
        SettingsRouter.shared.page = page
        openWindow(id: "settings")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { DockPolicy.bringWindowsForward() }
    }
}
