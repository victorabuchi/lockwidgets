import SwiftUI

struct BatteryWidget: View {
    @ObservedObject private var battery = BatteryMonitor.shared
    @Environment(\.isWidgetPreview) private var isPreview

    var body: some View {
        if let level = battery.level {
            WidgetCard(title: "Battery", symbol: symbol(level)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(level)%")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Spacer()
                        Text(status)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                    bar(level)
                }
            }
        } else if isPreview {
            WidgetCard(title: "Battery", symbol: "powerplug") {
                WidgetPlaceholder(symbol: "powerplug", message: "This Mac has no battery, so the widget stays hidden.")
            }
        }
    }

    private func bar(_ level: Int) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(color(level))
                    .frame(width: proxy.size.width * CGFloat(level) / 100)
            }
        }
        .frame(height: 8)
    }

    private var status: String {
        let time = battery.minutesRemaining.map { m in m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m" }
        if battery.isCharging {
            return time.map { "\($0) to full" } ?? "Charging"
        }
        if battery.isPluggedIn {
            return "Plugged in"
        }
        return time.map { "\($0) left" } ?? "On battery"
    }

    private func color(_ level: Int) -> Color {
        if battery.isCharging || battery.isPluggedIn { return .green }
        if level <= 10 { return .red }
        if level <= 20 { return .orange }
        return .white
    }

    private func symbol(_ level: Int) -> String {
        if battery.isCharging { return "battery.100.bolt" }
        switch level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}
