import SwiftUI

struct IslandSettingsPage: View {
    @AppStorage(SettingsKey.islandEnabled) private var enabled = true
    @AppStorage(SettingsKey.islandMusic) private var music = true
    @AppStorage(SettingsKey.islandLyrics) private var lyrics = true

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
            }
        }
        .formStyle(.grouped)
    }
}

/// A static drawing of the compact island for the settings page.
private struct IslandPreview: View {
    @ObservedObject private var music = NowPlayingStore.shared

    var body: some View {
        let notch = CGSize(width: 190, height: 32)
        ZStack {
            IslandShape(bottomRadius: 14)
                .fill(Color.black)
                .frame(width: notch.width + IslandModel.compactSide * 2, height: notch.height)
            MusicCompact(notch: notch)
        }
    }
}
