import SwiftUI

struct NowPlayingWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var music = NowPlayingStore.shared
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true
    @Environment(\.isWidgetPreview) private var isPreview

    var body: some View {
        if let track = music.track {
            if instance.style == "artwork" {
                artwork(track)
            } else {
                player(track)
            }
        } else if music.needsPermission {
            WidgetCard(size: instance.size, title: "Now Playing", symbol: "music.note") {
                WidgetPlaceholder(symbol: "lock", message: "Allow Notchlight under Privacy & Security → Automation.")
            }
        } else if !hideWhenIdle || isPreview {
            WidgetCard(size: instance.size, title: "Now Playing", symbol: "music.note") {
                WidgetPlaceholder(symbol: "music.note", message: "Nothing playing in Music or Spotify.")
            }
        }
    }

    private func player(_ track: NowPlayingStore.Track) -> some View {
        let wide = instance.size == .wide
        return WidgetCard(size: instance.size, title: wide ? nil : track.player.name, symbol: music.isPlaying ? "waveform" : "pause.fill") {
            HStack(spacing: 14) {
                if wide {
                    Artwork(image: music.artwork, size: 132)
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        if !wide {
                            Artwork(image: music.artwork, size: 52)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            if wide {
                                Caption(track.player.name)
                            }
                            Text(track.title)
                                .font(.system(size: wide ? 20 : 15, weight: .semibold))
                                .lineLimit(1)
                            Text(wide ? "\(track.artist) · \(track.album)" : track.artist)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    progress(track)
                }
            }
        }
    }

    private func artwork(_ track: NowPlayingStore.Track) -> some View {
        WidgetCard(size: instance.size, padding: 0) {
            ZStack(alignment: .bottomLeading) {
                Artwork(image: music.artwork, size: instance.size.points.width, cornerRadius: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: instance.size == .large ? 20 : 13, weight: .bold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: instance.size == .large ? 14 : 11, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                    if instance.size == .large {
                        progress(track).padding(.top, 8)
                    }
                }
                .padding(instance.size == .large ? 18 : 12)
            }
        }
    }

    private func progress(_ track: NowPlayingStore.Track) -> some View {
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

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    var cornerRadius: CGFloat?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [Color.pink.opacity(0.6), Color.purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.35))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius ?? size * 0.16, style: .continuous))
    }
}
