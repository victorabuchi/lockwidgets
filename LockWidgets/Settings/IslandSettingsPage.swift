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
    @ObservedObject private var notificationStore = NotificationStore.shared

    var body: some View {
        Form {
            Section {
                PageHeader(title: "Dynamic Island", subtitle: "Live activity around your MacBook's notch, like the iPhone. Tap the island to open the full card.")
                PreviewStage(height: 200) {
                    VStack(spacing: 14) {
                        IslandPreview()
                        Text("Hover to nudge it, tap to expand. It hides while your Mac is locked.")
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
            }
            Section {
                Text("When two things are live, the second sits in a bubble beside the island. Tap the bubble to swap.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// A static drawing of the compact island for the settings page.
private struct IslandPreview: View {
    @ObservedObject private var music = NowPlayingStore.shared
    @Namespace private var namespace

    var body: some View {
        let notch = CGSize(width: 190, height: 32)
        ZStack {
            IslandShape(bottomRadius: 14)
                .fill(Color.black)
                .frame(width: notch.width + IslandActivity.music.compactSide * 2, height: notch.height)
            MusicCompact(notch: notch, namespace: namespace)
        }
    }
}
