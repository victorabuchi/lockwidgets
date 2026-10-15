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
                .frame(width: artwork * 0.75, height: artwork * 0.58)
        }
    }
}

/// The full card. Like the iPhone's, the artwork and waveform sit in the top corners beside the camera,
/// with the song, progress and controls beneath them.
struct MusicExpanded: View {
    let notch: CGSize
    @ObservedObject private var music = NowPlayingStore.shared
    @ObservedObject private var lyrics = LyricsStore.shared
    @AppStorage(SettingsKey.islandLyrics) private var showLyrics = true

    private var tint: Color { Color(nsColor: music.artworkColor ?? .systemPink) }

    var body: some View {
        if let track = music.track {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Artwork(image: music.artwork, size: 46, cornerRadius: 10)
                    Spacer()
                    Waveform(color: tint, playing: music.isPlaying)
                        .frame(width: 22, height: 16)
                        .padding(.top, 6)
                }
                .frame(height: 46)

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                    if showLyrics {
                        lyricLine
                    }
                }
                .padding(.top, 8)

                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let position = music.position(at: context.date)
                    HStack(spacing: 10) {
                        Text(position.playbackTime)
                        ProgressBar(fraction: track.duration > 0 ? position / track.duration : 0, height: 4)
                        Text("-" + (track.duration - position).playbackTime)
                    }
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 8)

                HStack {
                    Spacer()
                    control("backward.fill", 18) { music.send(.previous) }
                    Spacer()
                    control(music.isPlaying ? "pause.fill" : "play.fill", 24) { music.send(.playPause) }
                    Spacer()
                    control("forward.fill", 18) { music.send(.next) }
                    Spacer()
                }
                .padding(.top, 4)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private var lyricLine: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            if lyrics.state == .found, let index = lyrics.currentIndex(at: music.position(at: context.date)) {
                Text(lyrics.lines[index].text)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .id(index)
                    .transition(.push(from: .bottom))
                    .animation(.easeInOut(duration: 0.3), value: index)
            }
        }
        .frame(height: 18, alignment: .leading)
        .clipped()
        .padding(.top, 3)
    }

    private func control(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .frame(width: 46, height: 34)
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
