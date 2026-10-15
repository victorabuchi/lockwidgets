import Combine
import Foundation

/// Time-synced lyrics for the current track from LRCLIB (free, no API key).
final class LyricsStore: ObservableObject {
    static let shared = LyricsStore()

    struct Line: Identifiable, Equatable {
        let id: Int
        let time: Double
        let text: String
    }

    enum State: Equatable {
        case idle, loading, found, notFound, instrumental
    }

    @Published private(set) var lines: [Line] = []
    @Published private(set) var state = State.idle

    private var cache: [String: (State, [Line])] = [:]
    private var subscription: AnyCancellable?
    private var task: Task<Void, Never>?

    private init() {
        subscription = NowPlayingStore.shared.$track
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in self?.load(track) }
    }

    /// Index of the line being sung at `position`, nil before the first line.
    func currentIndex(at position: Double) -> Int? {
        // Show each line a moment early; it reads better than lagging behind the singer.
        let target = position + 0.3
        var low = 0
        var high = lines.count - 1
        var result: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= target {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return result
    }

    private func load(_ track: NowPlayingStore.Track?) {
        task?.cancel()
        guard let track else {
            lines = []
            state = .idle
            return
        }
        let key = "\(track.player.rawValue):\(track.id)"
        if let cached = cache[key] {
            (state, lines) = cached
            return
        }
        lines = []
        state = .loading
        task = Task { @MainActor [weak self] in
            let result = await Self.fetch(track)
            guard !Task.isCancelled, let self else { return }
            cache[key] = result
            (state, lines) = result
        }
    }

    // MARK: LRCLIB

    private struct Record: Decodable {
        let duration: Double?
        let instrumental: Bool?
        let syncedLyrics: String?
    }

    private static func fetch(_ track: NowPlayingStore.Track) async -> (State, [Line]) {
        let exact = await request("get", [
            "artist_name": track.artist,
            "track_name": track.title,
            "album_name": track.album,
            "duration": String(Int(track.duration.rounded())),
        ]).flatMap { try? JSONDecoder().decode(Record.self, from: $0) }

        if let exact, let result = parse(exact) { return result }

        // Fall back to a looser search: titles often differ by "(feat. …)" or "- Remastered".
        let records = await request("search", [
            "artist_name": track.artist,
            "track_name": simplified(track.title),
        ]).flatMap { try? JSONDecoder().decode([Record].self, from: $0) } ?? []

        let closest = records
            .filter { $0.syncedLyrics?.isEmpty == false || $0.instrumental == true }
            .filter { abs(($0.duration ?? track.duration) - track.duration) < 8 }
            .min { abs(($0.duration ?? 0) - track.duration) < abs(($1.duration ?? 0) - track.duration) }

        if let closest, let result = parse(closest) { return result }
        return (.notFound, [])
    }

    private static func parse(_ record: Record) -> (State, [Line])? {
        if record.instrumental == true { return (.instrumental, []) }
        guard let synced = record.syncedLyrics, !synced.isEmpty else { return nil }
        let lines = parseLRC(synced)
        return lines.isEmpty ? nil : (.found, lines)
    }

    private static func request(_ endpoint: String, _ query: [String: String]) async -> Data? {
        var components = URLComponents(string: "https://lrclib.net/api/\(endpoint)")!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        var request = URLRequest(url: components.url!)
        request.setValue("LockWidgets/1.0 (https://github.com/victorabuchi/lockwidgets)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }

    private static func simplified(_ title: String) -> String {
        var result = title
        for marker in [" (feat", " [feat", " (with", " - "] {
            if let range = result.range(of: marker, options: .caseInsensitive) {
                result = String(result[..<range.lowerBound])
            }
        }
        return result
    }

    /// Parses "[01:23.45] text" lines. A line may carry several timestamps.
    static func parseLRC(_ text: String) -> [Line] {
        let pattern = try! NSRegularExpression(pattern: #"\[(\d+):(\d+(?:\.\d+)?)\]"#)
        var entries: [(Double, String)] = []
        for raw in text.components(separatedBy: .newlines) {
            let range = NSRange(raw.startIndex..., in: raw)
            let matches = pattern.matches(in: raw, range: range)
            guard let last = matches.last, let textRange = Range(last.range, in: raw) else { continue }
            let lyric = raw[textRange.upperBound...].trimmingCharacters(in: .whitespaces)
            for match in matches {
                guard let minutes = Range(match.range(at: 1), in: raw).flatMap({ Double(raw[$0]) }),
                      let seconds = Range(match.range(at: 2), in: raw).flatMap({ Double(raw[$0]) })
                else { continue }
                entries.append((minutes * 60 + seconds, lyric))
            }
        }
        return entries
            .sorted { $0.0 < $1.0 }
            .enumerated()
            .map { Line(id: $0.offset, time: $0.element.0, text: $0.element.1) }
    }
}
