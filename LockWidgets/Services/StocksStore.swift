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
        #if DEBUG
        if WidgetGallery.isRendering { return } // Sample data only.
        #endif
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

#if DEBUG
extension StocksStore {
    func loadSample() {
        func series(from start: Double, to end: Double, wobble: Double) -> [Double] {
            (0 ..< 40).map { index in start + (end - start) * Double(index) / 39 + wobble * sin(Double(index) * 0.9) }
        }
        quotes = [
            Quote(symbol: "AAPL", name: "Apple", price: 231.42, previousClose: 228.90, currency: "USD", closes: series(from: 228.9, to: 231.4, wobble: 0.8)),
            Quote(symbol: "MSFT", name: "Microsoft", price: 418.06, previousClose: 421.30, currency: "USD", closes: series(from: 421.3, to: 418.1, wobble: 1.2)),
            Quote(symbol: "BTC-USD", name: "Bitcoin", price: 82_285, previousClose: 81_680, currency: "USD", closes: series(from: 81_680, to: 82_285, wobble: 300)),
            Quote(symbol: "^GSPC", name: "S&P 500", price: 6412.30, previousClose: 6430.30, currency: "USD", closes: series(from: 6430, to: 6412, wobble: 8)),
        ]
    }
}
#endif
