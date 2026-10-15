import SwiftUI

struct LyricsWidget: View {
    @ObservedObject private var music = NowPlayingStore.shared
    @ObservedObject private var lyrics = LyricsStore.shared
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true
    @Environment(\.isWidgetPreview) private var isPreview
    @AppStorage(SettingsKey.lyricsUpcomingLines) private var upcomingLines = 2

    var body: some View {
        if let track = music.track {
            WidgetCard(title: "Lyrics", symbol: "quote.bubble") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(track.title) · \(track.artist)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                    content
                }
            }
        } else if !hideWhenIdle || isPreview {
            WidgetCard(title: "Lyrics", symbol: "quote.bubble") {
                WidgetPlaceholder(symbol: "music.note", message: "Play a song in Music or Spotify.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch lyrics.state {
        case .found:
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                lines(current: lyrics.currentIndex(at: music.position(at: context.date)))
            }
        case .loading, .idle:
            WidgetPlaceholder(symbol: "ellipsis", message: "Finding lyrics…")
        case .instrumental:
            WidgetPlaceholder(symbol: "music.note", message: "Instrumental")
        case .notFound:
            WidgetPlaceholder(symbol: "text.badge.xmark", message: "No synced lyrics for this song.")
        }
    }

    private func lines(current: Int?) -> some View {
        let all = lyrics.lines
        let index = current ?? -1
        // One line of context above the current one, then the upcoming lines.
        let window = all[max(index - 1, 0) ..< min(index + 1 + upcomingLines, all.count)]

        // Keyed by line, so a change slides each line up instead of swapping text in place.
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(window) { item in
                line(item.text, style: item.id < index ? .past : item.id == index ? .current : .upcoming)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: index)
    }

    private enum LineStyle { case past, current, upcoming }

    private func line(_ text: String, style: LineStyle) -> some View {
        // Same font for every line so nothing re-wraps mid-animation; only brightness changes.
        Text(text.isEmpty ? "♪" : text)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(style == .current ? 1 : style == .past ? 0.25 : 0.4))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
