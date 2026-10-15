import Foundation

/// Headlines from an RSS or Atom feed.
final class NewsStore: ObservableObject {
    static let shared = NewsStore()
    static let feedKey = "newsFeed"

    static let sources: [(name: String, url: String)] = [
        ("BBC News · World", "https://feeds.bbci.co.uk/news/world/rss.xml"),
        ("BBC News · Technology", "https://feeds.bbci.co.uk/news/technology/rss.xml"),
        ("The New York Times · World", "https://rss.nytimes.com/services/xml/rss/nyt/World.xml"),
        ("The Verge", "https://www.theverge.com/rss/index.xml"),
        ("Hacker News", "https://hnrss.org/frontpage"),
    ]

    struct Headline: Identifiable {
        let id = UUID()
        let title: String
        let date: Date?
    }

    @Published private(set) var headlines: [Headline] = []
    @Published private(set) var source = ""
    @Published private(set) var problem: String?

    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        let feed = UserDefaults.standard.string(forKey: Self.feedKey) ?? Self.sources[0].url
        guard let url = URL(string: feed) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let parser = FeedParser()
            let items = data.map(parser.parse) ?? []
            DispatchQueue.main.async {
                guard let self else { return }
                if items.isEmpty {
                    self.problem = "Couldn't load headlines from this feed."
                } else {
                    self.headlines = items
                    self.source = Self.sources.first { $0.url == feed }?.name ?? parser.channelTitle ?? "News"
                    self.problem = nil
                }
            }
        }.resume()
    }
}

/// Minimal RSS 2.0 / Atom reader: titles and dates of items, plus the feed's own title.
private final class FeedParser: NSObject, XMLParserDelegate {
    private var items: [NewsStore.Headline] = []
    private var inItem = false
    private var element = ""
    private var title = ""
    private var date = ""
    private(set) var channelTitle: String?

    func parse(_ data: Data) -> [NewsStore.Headline] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_: XMLParser, didStartElement name: String, namespaceURI _: String?, qualifiedName _: String?, attributes _: [String: String] = [:]) {
        element = name
        if name == "item" || name == "entry" {
            inItem = true
            title = ""
            date = ""
        }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        append(string)
    }

    func parser(_: XMLParser, foundCDATA block: Data) {
        append(String(decoding: block, as: UTF8.self))
    }

    private func append(_ text: String) {
        switch element {
        case "title":
            if inItem { title += text } else if channelTitle == nil, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                channelTitle = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case "pubDate", "updated", "published", "dc:date":
            if inItem { date += text }
        default:
            break
        }
    }

    func parser(_: XMLParser, didEndElement name: String, namespaceURI _: String?, qualifiedName _: String?) {
        if name == "item" || name == "entry" {
            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                items.append(.init(title: clean, date: Self.date(date.trimmingCharacters(in: .whitespacesAndNewlines))))
            }
            inItem = false
        }
        element = ""
    }

    private static func date(_ text: String) -> Date? {
        let rfc822 = DateFormatter()
        rfc822.locale = Locale(identifier: "en_US_POSIX")
        rfc822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return rfc822.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
