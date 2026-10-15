import Combine
import Foundation

/// Apple Music's synced lyrics for the current track, timed against the playback position.
final class LyricsStore: ObservableObject {
    static let shared = LyricsStore()

    struct Line: Identifiable, Equatable {
        let id: Int
        let begin: Double
        let end: Double
        let text: String
    }

    enum State: Equatable {
        case idle
        case loading
        case found
        /// Music has no lyrics for this song.
        case unavailable
        /// Lyrics only come from Apple Music.
        case otherPlayer
    }

    @Published private(set) var lines: [Line] = []
    @Published private(set) var state = State.idle

    private var subscription: AnyCancellable?
    private var retry: Timer?
    private var cache: [String: [Line]] = [:]
    private let queue = DispatchQueue(label: "LockWidgets.Lyrics")

    private init() {
        subscription = NowPlayingStore.shared.$track
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in self?.load(track) }
    }

    /// Index of the line being sung at `position`; nil before the first line and during instrumental breaks.
    func currentIndex(at position: Double) -> Int? {
        guard let index = lines.lastIndex(where: { $0.begin <= position + 0.15 }) else { return nil }
        let line = lines[index]
        let nextBegin = index + 1 < lines.count ? lines[index + 1].begin : .infinity
        // A long gap after a line has ended is a break, as Music shows it.
        if position > line.end + 0.6, nextBegin - line.end > 4 { return nil }
        return index
    }

    private func load(_ track: NowPlayingStore.Track?) {
        retry?.invalidate()
        guard let track else {
            lines = []
            state = .idle
            return
        }
        guard track.player == .music else {
            lines = []
            state = .otherPlayer
            return
        }
        let key = track.id
        if let cached = cache[key] {
            lines = cached
            state = .found
            return
        }
        lines = []
        state = .loading
        attempt(track, key: key, remaining: 10)
    }

    /// Music fetches lyrics a moment after a song starts, so look a few times before giving up.
    private func attempt(_ track: NowPlayingStore.Track, key: String, remaining: Int) {
        queue.async { [weak self] in
            let found = AppleMusicLyrics.lyrics(title: track.title, artist: track.artist, duration: track.duration)
            DispatchQueue.main.async {
                guard let self, NowPlayingStore.shared.track?.id == key else { return }
                if let found {
                    let lines = found.enumerated().map { Line(id: $0.offset, begin: $0.element.begin, end: $0.element.end, text: $0.element.text) }
                    self.cache[key] = lines
                    self.lines = lines
                    self.state = .found
                } else if remaining > 0 {
                    self.retry = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                        self.attempt(track, key: key, remaining: remaining - 1)
                    }
                } else {
                    self.state = .unavailable
                }
            }
        }
    }
}
