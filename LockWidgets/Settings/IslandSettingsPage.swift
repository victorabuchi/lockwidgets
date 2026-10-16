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
    @AppStorage(SettingsKey.islandLock) private var lock = true
    @AppStorage(SettingsKey.islandPrivacy) private var privacy = true
    @ObservedObject private var notificationStore = NotificationStore.shared

    var body: some View {
        Form {
            Section {
                PageHeader(title: "Dynamic Island", subtitle: "Live activity in your MacBook's notch, like the iPhone's Dynamic Island.")
                PreviewStage(height: 240) {
                    VStack(spacing: 14) {
                        IslandPreview()
                        Text("A song or your hotspot shows beside the notch, like the iPhone. Point at it to see more; click it to open the app.")
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
                    Text("macOS keeps notifications in a protected file. Turn on Notchlight in Full Disk Access, then reopen Notchlight.")
                }
            } header: {
                Text("Notifications")
            }

            Section("Activities") {
                Toggle(isOn: $music) {
                    Text("Now Playing")
                    Text("Artwork and waveform beside the notch; the song, lyric and controls when you open it.")
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
                Toggle(isOn: $lock) {
                    Text("Lock")
                    Text("A lock beside the camera while your Mac is locked. It opens as you unlock.")
                }
                Toggle(isOn: $privacy) {
                    Text("Microphone and camera")
                    Text("A dot beside the island while an app uses the microphone (orange) or camera (green), or records (red).")
                }
            }
            Section {
                Text("When two things are live, the second waits in its own circle on the right, like the iPhone. Calls come first, then timers, music and the hotspot.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// The open music card in miniature, for the settings page.
private struct IslandPreview: View {
    @AppStorage(SettingsKey.islandLyrics) private var showLyrics = true

    var body: some View {
        let model = IslandModel.shared
        let size = CGSize(width: model.cardWidth, height: model.notch.height + MusicExpanded.height(showsLyrics: showLyrics))
        ZStack(alignment: .top) {
            IslandShape(bottomRadius: 24).fill(Color.black)
            MusicExpanded(notch: model.notch)
        }
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, .dark)
        .scaleEffect(0.8)
        .frame(width: size.width * 0.8, height: size.height * 0.8)
    }
}
