import SwiftUI

struct IslandSettingsPage: View {
    @AppStorage(SettingsKey.islandEnabled) private var enabled = true
    @AppStorage(SettingsKey.islandMusic) private var music = true
    @AppStorage(SettingsKey.islandLyrics) private var lyrics = true
    @AppStorage(SettingsKey.islandMeetings) private var meetings = true
    @AppStorage(SettingsKey.islandTimers) private var timers = true
    @AppStorage(SettingsKey.islandHotspot) private var hotspot = true
    @AppStorage(SettingsKey.islandBattery) private var battery = true
    @AppStorage(SettingsKey.islandNotifications) private var notifications = true
    @AppStorage(SettingsKey.islandCalendar) private var calendar = true
    @AppStorage(SettingsKey.islandDevices) private var devices = true
    @AppStorage(SettingsKey.islandHUD) private var hud = true
    @AppStorage(SettingsKey.islandFocus) private var focus = true
    @ObservedObject private var notificationStore = NotificationStore.shared

    var body: some View {
        Form {
            Section {
                PageHeader(title: "Dynamic Island", subtitle: "Live activity around your MacBook's notch, like the iPhone. Tap the island to open the full card.")
                PreviewStage(height: 240) {
                    VStack(spacing: 14) {
                        IslandPreview()
                        Text("Closed, it is exactly your notch. Point at the notch to open it.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            Section {
                Toggle("Show the Dynamic Island", isOn: $enabled)
            }
            Section {
                Toggle(isOn: $notifications) {
                    Text("Notifications")
                    Text("Every app's notifications drop down from the island.")
                }
                LabeledContent {
                    switch notificationStore.status {
                    case .connected:
                        Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    case .needsAccess:
                        Button("Open Full Disk Access") { notificationStore.openFullDiskAccessSettings() }
                    case let .failed(message):
                        Text(message).foregroundStyle(.orange).textSelection(.enabled)
                    }
                } label: {
                    Text("Full Disk Access")
                    Text("macOS keeps notifications in a protected file. Turn on LockWidgets in Full Disk Access, then reopen LockWidgets.")
                }
            } header: {
                Text("Notifications")
            }

            Section("Activities") {
                Toggle(isOn: $music) {
                    Text("Now Playing")
                    Text("Artwork and a live waveform while a song plays; tap for controls.")
                }
                Toggle(isOn: $lyrics) {
                    Text("Lyrics in the full card")
                    Text("The current Apple Music lyric under the song title.")
                }
                .disabled(!music)
                Toggle(isOn: $meetings) {
                    Text("Calls and meetings")
                    Text("Zoom meetings, plus FaceTime, Teams, Meet and others while the mic or camera is on.")
                }
                Toggle(isOn: $timers) {
                    Text("Timers")
                    Text("The Pomodoro and Stopwatch while they run.")
                }
                Toggle(isOn: $hotspot) {
                    Text("Personal Hotspot")
                    Text("While your Mac is on your iPhone's hotspot.")
                }
                Toggle(isOn: $battery) {
                    Text("Charging and low battery")
                    Text("When you plug in or unplug, and at 20% and 10%.")
                }
                Toggle(isOn: $calendar) {
                    Text("Upcoming events")
                    Text("A heads-up five minutes before each event.")
                }
                Toggle(isOn: $devices) {
                    Text("AirPods and Bluetooth")
                    Text("When headphones, keyboards and other devices connect or disconnect.")
                }
                Toggle(isOn: $hud) {
                    Text("Volume and brightness")
                    Text("Levels in the island as you change them.")
                }
                Toggle(isOn: $focus) {
                    Text("Focus")
                    Text("When a Focus such as Do Not Disturb turns on or off. Needs Full Disk Access.")
                }
            }
            Section {
                Text("When two things are live, the other one waits as a small icon at the top of the open card. Tap it to switch.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// The open music card in miniature, for the settings page.
private struct IslandPreview: View {
    var body: some View {
        let notch = CGSize(width: 190, height: 32)
        ZStack(alignment: .top) {
            IslandShape(bottomRadius: 30).fill(Color.black)
            MusicExpanded(notch: notch)
        }
        .frame(width: 360, height: 210)
        .environment(\.colorScheme, .dark)
        .scaleEffect(0.75)
        .frame(width: 270, height: 158)
    }
}
