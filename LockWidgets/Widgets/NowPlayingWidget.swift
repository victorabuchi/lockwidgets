import SwiftUI

struct NowPlayingWidget: View {
    @ObservedObject private var music = NowPlayingStore.shared
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true

    var body: some View {
        if let track = music.track {
            WidgetCard(title: track.player.name, symbol: music.isPlaying ? "waveform" : "pause.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Artwork(image: music.artwork, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title)
                                .font(.system(size: 15, weight: .semibold))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                                .lineLimit(1)
                        }
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let position = music.position(at: context.date)
                        VStack(spacing: 5) {
                            ProgressBar(fraction: track.duration > 0 ? position / track.duration : 0)
                            HStack {
                                Text(position.playbackTime)
                                Spacer()
                                Text("-" + (track.duration - position).playbackTime)
                            }
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Theme.tertiary)
                        }
                    }
                }
            }
        } else if music.needsPermission {
            WidgetCard(title: "Now Playing", symbol: "music.note") {
                WidgetPlaceholder(symbol: "lock", message: "Allow LockWidgets under Privacy & Security → Automation.")
            }
        } else if !hideWhenIdle {
            WidgetCard(title: "Now Playing", symbol: "music.note") {
                WidgetPlaceholder(symbol: "music.note", message: "Nothing playing in Music or Spotify.")
            }
        }
    }
}

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.4))
                        .foregroundStyle(Theme.tertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
    }
}

struct ProgressBar: View {
    let fraction: Double
    var color: Color = .white

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 5)
    }
}
