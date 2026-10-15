import SwiftUI

struct WeatherWidget: View {
    @ObservedObject private var weather = WeatherStore.shared

    var body: some View {
        if let report = weather.report {
            WidgetCard(title: report.place, symbol: "location.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: WeatherCode.symbol(report.code, isDay: report.isDay))
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 38))
                        Text(degrees(report.temperature))
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(WeatherCode.description(report.code))
                                .font(.system(size: 14, weight: .semibold))
                            Text("H:\(degrees(report.high))  L:\(degrees(report.low))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                        }
                    }

                    if report.hours.count > 1 {
                        HStack(spacing: 0) {
                            ForEach(Array(report.hours.prefix(6).enumerated()), id: \.element.id) { index, hour in
                                VStack(spacing: 6) {
                                    Text(index == 0 ? "Now" : label(hour.id, in: report.timeZone))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.secondary)
                                    Image(systemName: WeatherCode.symbol(hour.code, isDay: hour.isDay))
                                        .symbolRenderingMode(.multicolor)
                                        .font(.system(size: 16))
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
        } else {
            WidgetCard(title: "Weather", symbol: "cloud.sun") {
                WidgetPlaceholder(symbol: "cloud", message: weather.problem ?? "Loading weather…")
            }
        }
    }

    private func degrees(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    private func label(_ date: Date, in timeZone: TimeZone) -> String {
        var style = Date.FormatStyle.dateTime.hour()
        style.timeZone = timeZone
        return date.formatted(style)
    }
}
