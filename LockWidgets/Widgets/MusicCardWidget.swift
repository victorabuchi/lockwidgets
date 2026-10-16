import SwiftUI

/// The song in a glass card, like the iPhone's lock screen. It pops up when a song starts and goes away
/// when nothing is loaded in Music or Spotify.
struct MusicCardWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var music = NowPlayingStore.shared
    @Environment(\.isWidgetPreview) private var isPreview

    var body: some View {
        ZStack {
            if let track = music.track {
                card(track)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else if isPreview {
                glass {
                    WidgetPlaceholder(symbol: "music.note", message: "Appears here while a song plays in Music or Spotify.")
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: music.track?.id)
    }

    private func card(_ track: NowPlayingStore.Track) -> some View {
        let compact = instance.size == .medium
        return glass {
            VStack(spacing: compact ? 8 : 10) {
                HStack(spacing: 12) {
                    Artwork(image: music.artwork, size: compact ? 46 : 54, cornerRadius: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: compact ? 15 : 17, weight: .semibold))
                        Text(track.artist)
                            .font(.system(size: compact ? 13 : 15, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 4)
                    Waveform(color: Theme.tertiary, playing: music.isPlaying)
                        .frame(width: 18, height: 14)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let position = music.position(at: context.date)
                    HStack(spacing: 10) {
                        Text(position.playbackTime)
                        ProgressBar(fraction: track.duration > 0 ? position / track.duration : 0, color: .white.opacity(0.75), height: 5)
                        Text("-" + (track.duration - position).playbackTime)
                    }
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Theme.secondary)
                }
                HStack {
                    if !compact { symbol("star", 17) }
                    Spacer()
                    symbol("backward.fill", compact ? 18 : 22)
                    Spacer()
                    symbol(music.isPlaying ? "pause.fill" : "play.fill", compact ? 24 : 30)
                    Spacer()
                    symbol("forward.fill", compact ? 18 : 22)
                    Spacer()
                    if !compact { symbol("airplayaudio", 17) }
                }
            }
        }
    }

    private func symbol(_ name: String, _ size: CGFloat) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .frame(width: 30)
    }

    /// Lighter, clearer glass than the other cards, like the iPhone's lock screen player.
    private func glass<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        return content()
            .padding(16)
            .frame(width: instance.size.points.width, height: instance.size.points.height)
            .background {
                shape.fill(.frost(.ultraThinMaterial))
                    .overlay(shape.fill(Color.white.opacity(0.08)))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            }
            .clipShape(shape)
            .foregroundStyle(Theme.primary)
            .environment(\.colorScheme, .dark)
    }
}
