import CoreLocation
import EventKit
import ServiceManagement
import SwiftUI

struct GeneralPage: View {
    @ObservedObject var overlay: OverlayManager
    @ObservedObject private var calendar = CalendarStore.shared
    @ObservedObject private var music = NowPlayingStore.shared

    @AppStorage(SettingsKey.showOnLockScreen) private var showOnLockScreen = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                PageHeader(title: "General", subtitle: "Turn LockWidgets on or off and manage permissions.")
            }

            Section("Lock Screen") {
                Toggle(isOn: $showOnLockScreen) {
                    Text("Show widgets on the Lock Screen")
                    Text("Pause every widget without changing your layout.")
                }
                LabeledContent {
                    Button(overlay.isShowing ? "Hide Preview" : "Preview on Desktop") { overlay.toggle() }
                } label: {
                    Text("Desktop preview")
                    Text("Shows the widgets over your desktop exactly as they appear when locked.")
                }
            }

            Section("Startup") {
                Toggle(isOn: $launchAtLogin) {
                    Text("Launch at login")
                    Text("Keep LockWidgets running so widgets appear whenever you lock your Mac.")
                }
                .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
            }

            Section {
                PermissionRow(
                    title: "Calendar",
                    detail: "For the Up Next widget.",
                    granted: calendar.hasAccess,
                    action: calendar.status == .notDetermined
                        ? ("Allow", { calendar.requestAccess() })
                        : ("Open Settings", { calendar.openPrivacySettings() })
                )
                PermissionRow(
                    title: "Location",
                    detail: "For local weather. Not needed if you set a city.",
                    granted: locationGranted,
                    action: CLLocationManager().authorizationStatus == .notDetermined
                        ? ("Allow", { WeatherStore.shared.refresh() })
                        : ("Open Settings", {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                        })
                )
                PermissionRow(
                    title: "Automation",
                    detail: "To read the song playing in Music or Spotify.",
                    granted: !music.needsPermission,
                    action: ("Open Settings", { music.openAutomationSettings() })
                )
            } header: {
                Text("Permissions")
            } footer: {
                Text("Automation access is requested the first time a song plays.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Widget data") {
                    Button("Refresh Now") { overlay.refreshData() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { calendar.reload() }
    }

    private var locationGranted: Bool {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined, .denied, .restricted: false
        default: true
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let action: (String, () -> Void)

    var body: some View {
        LabeledContent {
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(action.0, action: action.1)
            }
        } label: {
            Text(title)
            Text(detail)
        }
    }
}
