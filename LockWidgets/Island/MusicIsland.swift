import SwiftUI

struct MusicCompact: View {
    let notch: CGSize
    @ObservedObject private var music = NowPlayingStore.shared

    var body: some View {
        CompactSlots(notch: notch) {
            Artwork(image: music.artwork, size: notch.height - 12, cornerRadius: 6)
        } trailing: {
            Waveform(color: Color(nsColor: music.artworkColor ?? .systemPink), playing: music.isPlaying)
                .frame(width: 22, height: 14)
        }
    }
}

struct MusicExpanded: View {
    let notch: CGSize
    @ObservedObject private var music = NowPlayingStore.shared
    @ObservedObject private var lyrics = LyricsStore.shared
    @AppStorage(SettingsKey.islandLyrics) private var showLyrics = true

    var body: some View {
        if let track = music.track {
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    Artwork(image: music.artwork, size: 64, cornerRadius: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        if showLyrics {
                            lyricLine
                        }
                    }
                    Spacer(minLength: 0)
                    Waveform(color: Color(nsColor: music.artworkColor ?? .systemPink), playing: music.isPlaying)
                        .frame(width: 26, height: 18)
                }
                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let position = music.position(at: context.date)
                    HStack(spacing: 8) {
                        Text(position.playbackTime)
                        ProgressBar(fraction: track.duration > 0 ? position / track.duration : 0, height: 5)
                        Text("-" + (track.duration - position).playbackTime)
                    }
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                }
                HStack(spacing: 44) {
                    control("backward.fill", 18) { music.send(.previous) }
                    control(music.isPlaying ? "pause.fill" : "play.fill", 26) { music.send(.playPause) }
                    control("forward.fill", 18) { music.send(.next) }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 26)
            .padding(.top, notch.height + 8)
        }
    }

    @ViewBuilder
    private var lyricLine: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            if lyrics.state == .found, let index = lyrics.currentIndex(at: music.position(at: context.date)) {
                Text(lyrics.lines[index].text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(nsColor: music.artworkColor ?? .white))
                    .lineLimit(1)
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
                .font(.system(size: size, weight: .semibold))
                .frame(width: 40, height: 32)
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
