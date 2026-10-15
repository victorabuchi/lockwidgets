import SwiftUI

struct LyricsWidget: View {
    @ObservedObject private var music = NowPlayingStore.shared
    @ObservedObject private var lyrics = LyricsStore.shared
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true
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
        } else if !hideWhenIdle {
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
        let previous = index > 0 ? all[index - 1] : nil
        let upcoming = all.dropFirst(index + 1).prefix(upcomingLines)

        return VStack(alignment: .leading, spacing: 8) {
            if let previous {
                line(previous.text, style: .past)
            }
            if index >= 0 {
                line(all[index].text, style: .current)
                    .id(all[index].id)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
            ForEach(Array(upcoming)) { next in
                line(next.text, style: .upcoming)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: index)
    }

    private enum LineStyle { case past, current, upcoming }

    private func line(_ text: String, style: LineStyle) -> some View {
        Text(text.isEmpty ? "♪" : text)
            .font(.system(size: style == .current ? 20 : 15, weight: style == .current ? .bold : .semibold, design: .rounded))
            .foregroundStyle(style == .current ? Theme.primary : style == .past ? Theme.tertiary.opacity(0.7) : Theme.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
