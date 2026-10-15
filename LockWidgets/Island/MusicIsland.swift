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

/// The full card, exactly as wide as the notch: the song, its current Apple Music lyric, progress and
/// controls hang below the camera, and the card folds back up into the notch when it closes.
struct MusicExpanded: View {
    let notch: CGSize
    @ObservedObject private var music = NowPlayingStore.shared
    @ObservedObject private var lyrics = LyricsStore.shared
    @ObservedObject private var island = IslandModel.shared
    @AppStorage(SettingsKey.islandLyrics) private var showLyrics = true

    /// Height of the card below the notch. The rows in `body` add up to it.
    static func height(showsLyrics: Bool) -> CGFloat { showsLyrics ? 138 : 104 }

    private var tint: Color { Color(nsColor: music.artworkColor ?? .systemPink) }

    var body: some View {
        if let track = music.track {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Artwork(image: music.artwork, size: 36, cornerRadius: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .bold))
                        Text(track.artist)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .lineLimit(1)
                    .padding(.leading, 9)
                    Spacer(minLength: 6)
                    HStack(spacing: 7) {
                        Waveform(color: tint, playing: music.isPlaying)
                            .frame(width: 14, height: 14)
                        // The other live activity, such as the hotspot, waits on the right as on the iPhone.
                        if let other = island.secondary {
                            Bubble(activity: other)
                        }
                    }
                }
                .frame(height: 36)

                if showLyrics {
                    lyricLine
                        .padding(.top, 6)
                }

                TimelineView(.periodic(from: .now, by: 0.5)) { context in
                    let position = music.position(at: context.date)
                    HStack(spacing: 8) {
                        Text(position.playbackTime)
                        ProgressBar(fraction: track.duration > 0 ? position / track.duration : 0, height: 3)
                        Text("-" + (track.duration - position).playbackTime)
                    }
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
                }
                .frame(height: 12)
                .padding(.top, 8)

                HStack {
                    Spacer()
                    control("backward.fill", 15) { music.send(.previous) }
                    Spacer()
                    control(music.isPlaying ? "pause.fill" : "play.fill", 20) { music.send(.playPause) }
                    Spacer()
                    control("forward.fill", 15) { music.send(.next) }
                    Spacer()
                }
                .frame(height: 30)
                .padding(.top, 2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.top, notch.height + 8)
            .padding(.bottom, 8)
        }
    }

    /// The line Apple Music is on, wrapping onto a second line rather than being cut off.
    private var lyricLine: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            if lyrics.state == .found, let index = lyrics.currentIndex(at: music.position(at: context.date)) {
                Text(lyrics.lines[index].text)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(index)
                    .transition(.push(from: .bottom))
                    .animation(.easeInOut(duration: 0.3), value: index)
            }
        }
        .frame(height: 28, alignment: .leading)
        .clipped()
    }

    private func control(_ symbol: String, _ size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .frame(width: 44, height: 30)
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
