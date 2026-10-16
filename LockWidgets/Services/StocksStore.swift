import Foundation

/// Watchlist quotes and intraday prices from Yahoo Finance's chart endpoint.
final class StocksStore: ObservableObject {
    static let shared = StocksStore()
    static let symbolsKey = "stockSymbols"
    static let defaultSymbols = "AAPL,MSFT,NVDA,TSLA,BTC-USD,EURUSD=X"

    struct Quote: Identifiable {
        var id: String { symbol }
        let symbol: String
        let name: String
        let price: Double
        let previousClose: Double
        let currency: String
        let closes: [Double]

        var change: Double { price - previousClose }
        var changePercent: Double { previousClose == 0 ? 0 : change / previousClose * 100 }

        var priceText: String {
            price.formatted(.number.precision(.fractionLength(price < 10 ? 4 : 2)))
        }

        var changeText: String {
            let arrow = change >= 0 ? "▲" : "▼"
            return "\(arrow) \(abs(changePercent).formatted(.number.precision(.fractionLength(2))))%"
        }
    }

    @Published private(set) var quotes: [Quote] = []
    private var timer: Timer?

    private init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    var symbols: [String] {
        (UserDefaults.standard.string(forKey: Self.symbolsKey) ?? Self.defaultSymbols)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty }
    }

    func refresh() {
        let symbols = symbols
        Task {
            var results: [Quote] = []
            for symbol in symbols.prefix(8) {
                if let quote = await Self.fetch(symbol) { results.append(quote) }
            }
            let quotes = results
            await MainActor.run { self.quotes = quotes }
        }
    }

    private struct Response: Decodable {
        struct Chart: Decodable { let result: [Result]? }
        struct Result: Decodable {
            struct Meta: Decodable {
                let symbol: String
                let shortName: String?
                let currency: String?
                let regularMarketPrice: Double?
                let chartPreviousClose: Double?
            }

            struct Indicators: Decodable {
                struct Quote: Decodable { let close: [Double?]? }
                let quote: [Quote]
            }

            let meta: Meta
            let indicators: Indicators
        }

        let chart: Chart
    }

    private static func fetch(_ symbol: String) async -> Quote? {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)?range=1d&interval=15m") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh) Notchlight", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let result = try? JSONDecoder().decode(Response.self, from: data).chart.result?.first,
              let price = result.meta.regularMarketPrice
        else { return nil }
        let closes = result.indicators.quote.first?.close?.compactMap { $0 } ?? []
        return Quote(
            symbol: result.meta.symbol,
            name: result.meta.shortName ?? result.meta.symbol,
            price: price,
            previousClose: result.meta.chartPreviousClose ?? closes.first ?? price,
            currency: result.meta.currency ?? "",
            closes: closes
        )
    }
}
