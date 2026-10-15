import SwiftUI

struct StocksWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var stocks = StocksStore.shared

    var body: some View {
        if stocks.quotes.isEmpty {
            WidgetCard(size: instance.size, title: "Stocks", symbol: "chart.line.uptrend.xyaxis") {
                WidgetPlaceholder(symbol: "chart.line.uptrend.xyaxis", message: "Loading quotes…")
            }
        } else if instance.style == "spotlight" {
            spotlight(stocks.quotes[0])
        } else {
            watchlist
        }
    }

    private var watchlist: some View {
        let limit = instance.size == .large ? 7 : 3
        return WidgetCard(size: instance.size, title: "Watchlist", symbol: "chart.line.uptrend.xyaxis") {
            VStack(spacing: instance.size == .large ? 10 : 7) {
                ForEach(stocks.quotes.prefix(limit)) { quote in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(quote.symbol)
                                .font(.system(size: 13, weight: .bold))
                            if instance.size != .medium {
                                Text(quote.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Theme.tertiary)
                            }
                        }
                        .lineLimit(1)
                        .frame(width: instance.size == .medium ? 72 : 120, alignment: .leading)
                        if instance.size != .medium {
                            PriceChart(values: quote.closes, baseline: quote.previousClose, color: color(quote), filled: false)
                                .frame(height: 22)
                        } else {
                            Spacer()
                        }
                        Text(quote.priceText)
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        Text(quote.changeText)
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(color(quote))
                            .frame(width: 66, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func spotlight(_ quote: StocksStore.Quote) -> some View {
        WidgetCard(size: instance.size, padding: 0) {
            ZStack(alignment: .topLeading) {
                PriceChart(values: quote.closes, baseline: quote.previousClose, color: color(quote), filled: true)
                    .padding(.top, 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text(quote.symbol)
                        .font(.system(size: 13, weight: .bold))
                    Text(quote.priceText)
                        .font(.system(size: instance.size == .small ? 24 : 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(quote.changeText)
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(color(quote))
                }
                .padding(16)
            }
        }
    }

    private func color(_ quote: StocksStore.Quote) -> Color {
        quote.change >= 0 ? Color(red: 0.3, green: 0.85, blue: 0.45) : Color(red: 1, green: 0.38, blue: 0.35)
    }
}

/// Intraday line with an optional fill, and a dashed line at yesterday's close.
struct PriceChart: View {
    let values: [Double]
    let baseline: Double
    let color: Color
    let filled: Bool

    var body: some View {
        GeometryReader { proxy in
            let low = min(values.min() ?? baseline, baseline)
            let high = max(values.max() ?? baseline, baseline)
            let span = max(high - low, 0.0001)
            let y = { (value: Double) in proxy.size.height * (1 - CGFloat((value - low) / span)) }
            let line = Path { path in
                guard values.count > 1 else { return }
                for (index, value) in values.enumerated() {
                    let point = CGPoint(x: proxy.size.width * CGFloat(index) / CGFloat(values.count - 1), y: y(value))
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
            }
            ZStack {
                if filled {
                    line
                        .addingLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                        .addingLine(to: CGPoint(x: 0, y: proxy.size.height))
                        .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                }
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y(baseline)))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y(baseline)))
                }
                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                line.stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private extension Path {
    func addingLine(to point: CGPoint) -> Path {
        var copy = self
        copy.addLine(to: point)
        return copy
    }
}
