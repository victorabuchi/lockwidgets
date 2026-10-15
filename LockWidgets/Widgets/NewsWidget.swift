import SwiftUI

struct NewsWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var news = NewsStore.shared

    var body: some View {
        let limit = instance.size == .large ? 6 : instance.size == .wide ? 4 : 3
        let items = Array(news.headlines.prefix(limit))
        WidgetCard(size: instance.size, title: news.source.isEmpty ? "News" : news.source, symbol: "newspaper.fill") {
            if items.isEmpty {
                WidgetPlaceholder(symbol: "newspaper", message: news.problem ?? "Loading headlines…")
            } else if instance.size == .wide {
                let half = (items.count + 1) / 2
                HStack(alignment: .top, spacing: 18) {
                    column(Array(items.prefix(half)))
                    column(Array(items.dropFirst(half)))
                }
            } else {
                column(items)
            }
        }
    }

    private func column(_ items: [NewsStore.Headline]) -> some View {
        VStack(alignment: .leading, spacing: instance.size == .large ? 12 : 8) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(instance.size == .large ? 2 : 1)
                    if instance.size == .large, let date = item.date {
                        Text(date, format: .relative(presentation: .named))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
