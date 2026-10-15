import SwiftUI

struct WeatherWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var weather = WeatherStore.shared

    var body: some View {
        if let report = weather.report {
            switch instance.style {
            case "hourly": hourly(report)
            case "daily": daily(report)
            default: current(report)
            }
        } else {
            WidgetCard(size: instance.size, title: "Weather", symbol: "cloud.sun") {
                WidgetPlaceholder(symbol: "cloud", message: weather.problem ?? "Loading weather…")
            }
        }
    }

    // MARK: Styles

    private func current(_ report: WeatherStore.Report) -> some View {
        WidgetCard(size: instance.size, title: report.place, symbol: "location.fill") {
            if instance.size == .small {
                VStack(alignment: .leading, spacing: 2) {
                    icon(report.code, report.isDay, 30)
                    Spacer(minLength: 0)
                    Text(degrees(report.temperature))
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                    Text(WeatherCode.description(report.code))
                        .font(.system(size: 13, weight: .semibold))
                    highLow(report)
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(degrees(report.temperature))
                            .font(.system(size: 60, weight: .semibold, design: .rounded))
                        Text(WeatherCode.description(report.code))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        icon(report.code, report.isDay, 50)
                        highLow(report)
                    }
                }
            }
        }
    }

    private func hourly(_ report: WeatherStore.Report) -> some View {
        let count = instance.size == .medium ? 6 : 8
        return WidgetCard(size: instance.size, title: report.place, symbol: "location.fill") {
            HStack(alignment: .center, spacing: 16) {
                if instance.size != .medium {
                    summary(report)
                        .frame(width: 150, alignment: .leading)
                    Divider().overlay(Color.white.opacity(0.2))
                }
                VStack(alignment: .leading, spacing: 10) {
                    if instance.size == .medium {
                        HStack(spacing: 10) {
                            icon(report.code, report.isDay, 26)
                            Text(degrees(report.temperature))
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(WeatherCode.description(report.code))
                                    .font(.system(size: 13, weight: .semibold))
                                highLow(report)
                            }
                        }
                    }
                    HStack(spacing: 0) {
                        ForEach(Array(report.hours.prefix(count).enumerated()), id: \.element.id) { index, hour in
                            VStack(spacing: 5) {
                                Text(index == 0 ? "Now" : label(hour.id, report.timeZone))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.secondary)
                                icon(hour.code, hour.isDay, 16)
                                    .frame(height: 20)
                                Text(degrees(hour.temperature))
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func daily(_ report: WeatherStore.Report) -> some View {
        let days = Array(report.days.prefix(instance.size == .large ? 6 : 5))
        let low = days.map(\.low).min() ?? 0
        let high = days.map(\.high).max() ?? 1
        return WidgetCard(size: instance.size, title: report.place, symbol: "location.fill") {
            if instance.size == .large {
                VStack(alignment: .leading, spacing: 10) {
                    summary(report)
                    Divider().overlay(Color.white.opacity(0.2))
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        HStack(spacing: 10) {
                            Text(index == 0 ? "Today" : weekday(day.id, report.timeZone))
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 52, alignment: .leading)
                            icon(day.code, true, 16)
                                .frame(width: 24)
                            Text(degrees(day.low))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                                .frame(width: 34, alignment: .trailing)
                            RangeBar(low: day.low, high: day.high, min: low, max: high)
                            Text(degrees(day.high))
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 34, alignment: .leading)
                        }
                    }
                }
            } else {
                HStack(spacing: 16) {
                    summary(report)
                        .frame(width: 140, alignment: .leading)
                    Divider().overlay(Color.white.opacity(0.2))
                    HStack(spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                            VStack(spacing: 6) {
                                Text(index == 0 ? "Today" : weekday(day.id, report.timeZone))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.secondary)
                                icon(day.code, true, 18)
                                    .frame(height: 22)
                                Text(degrees(day.high))
                                    .font(.system(size: 13, weight: .semibold))
                                Text(degrees(day.low))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Theme.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private func summary(_ report: WeatherStore.Report) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(degrees(report.temperature))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                icon(report.code, report.isDay, 28)
            }
            Text(WeatherCode.description(report.code))
                .font(.system(size: 13, weight: .semibold))
            highLow(report)
        }
    }

    private func icon(_ code: Int, _ isDay: Bool, _ size: CGFloat) -> some View {
        Image(systemName: WeatherCode.symbol(code, isDay: isDay))
            .symbolRenderingMode(.multicolor)
            .font(.system(size: size))
    }

    private func highLow(_ report: WeatherStore.Report) -> some View {
        Text("H:\(degrees(report.high))  L:\(degrees(report.low))")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.secondary)
    }

    private func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    private func label(_ date: Date, _ timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.hour()
        style.timeZone = timeZone
        return date.formatted(style)
    }

    private func weekday(_ date: Date, _ timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated)
        style.timeZone = timeZone
        return date.formatted(style)
    }
}

/// Where a day's temperature range sits within the week's.
private struct RangeBar: View {
    let low: Double
    let high: Double
    let min: Double
    let max: Double

    var body: some View {
        GeometryReader { proxy in
            let span = Swift.max(max - min, 1)
            let start = (low - min) / span * proxy.size.width
            let width = Swift.max((high - low) / span * proxy.size.width, 6)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: width)
                    .offset(x: start)
            }
        }
        .frame(height: 5)
    }
}
