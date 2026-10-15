import SwiftUI

/// While closed, the song sits either side of the camera: artwork on the left, waveform on the right.
struct MusicCompact: View {
    let notch: CGSize
    @ObservedObject private var music = NowPlayingStore.shared

    var body: some View {
        let artwork = (notch.height * 0.63).rounded()
        CompactRow(notch: notch) {
            Artwork(image: music.artwork, size: artwork, cornerRadius: artwork / 4)
        } trailing: {
            Waveform(color: Color(nsColor: music.artworkColor ?? .systemPink), playing: music.isPlaying)
                .frame(width: artwork * 0.67, height: artwork * 0.55)
        }
    }
}

/// The open card. The artwork sits beside the camera on the left and the waveform on the right; the song,
/// its Apple Music lyric, progress and controls run full width below the notch.
struct MusicExpanded: View {
    let notch: CGSize
    @ObservedObject private var music = NowPlayingStore.shared
    @ObservedObject private var lyrics = LyricsStore.shared
    @AppStorage(SettingsKey.islandLyrics) private var showLyrics = true

    /// Height of the card below the notch, the same as a notification's. The rows in `body` add up to it.
    static func height(showsLyrics: Bool) -> CGFloat { showsLyrics ? 60 : 42 }

    private var tint: Color { Color(nsColor: music.artworkColor ?? .systemPink) }

    var body: some View {
        if let track = music.track {
            CardLayout(notch: notch) {
                Artwork(image: music.artwork, size: 30, cornerRadius: 7)
            } right: {
                Waveform(color: tint, playing: music.isPlaying)
                    .frame(width: 18, height: 14)
            } below: {
                HStack(spacing: 2) {
                    (Text(track.title)
                        .font(.system(size: 13, weight: .bold))
                        + Text("  " + track.artist)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55)))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    control("backward.fill", 11) { music.send(.previous) }
                    control(music.isPlaying ? "pause.fill" : "play.fill", 14) { music.send(.playPause) }
                    control("forward.fill", 11) { music.send(.next) }
                }
                .frame(height: 22)
                .padding(.top, 3)

                if showLyrics {
                    lyricLine
                        .padding(.top, 2)
                }

                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let position = music.position(at: context.date)
                    HStack(spacing: 8) {
                        Text(position.playbackTime)
                        ProgressBar(fraction: track.duration > 0 ? position / track.duration : 0, height: 3)
                        Text("-" + (track.duration - position).playbackTime)
                    }
                    .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                }
                .frame(height: 10)
                .padding(.top, 5)
            }
        }
    }

    /// The line Apple Music is on.
    private var lyricLine: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            if lyrics.state == .found, let index = lyrics.currentIndex(at: music.position(at: context.date)) {
                Text(lyrics.lines[index].text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(index)
                    .transition(.push(from: .bottom))
                    .animation(.easeInOut(duration: 0.3), value: index)
            }
        }
        .frame(height: 16, alignment: .leading)
        .clipped()
    }

    private func control(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .frame(width: 30, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(IslandButtonStyle())
    }
}

struct IslandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

/// Music bars that bounce while playing and settle when paused.
struct Waveform: View {
    let color: Color
    let playing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: !playing)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0 ..< 4, id: \.self) { bar in
                    let speed = [5.3, 7.1, 6.2, 8.4][bar]
                    let height = playing ? 0.3 + 0.7 * abs(sin(time * speed + Double(bar) * 1.3)) : 0.2
                    Capsule()
                        .fill(color)
                        .frame(maxHeight: .infinity)
                        .scaleEffect(y: height, anchor: .center)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: time)
        }
    }
}
