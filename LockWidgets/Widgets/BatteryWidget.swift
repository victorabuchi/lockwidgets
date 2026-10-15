import SwiftUI

struct BatteryWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var battery = BatteryMonitor.shared

    var body: some View {
        if let level = battery.level {
            if instance.style == "ring" {
                ring(level)
            } else {
                bar(level)
            }
        } else {
            WidgetCard(size: instance.size, title: "Battery", symbol: "powerplug") {
                WidgetPlaceholder(symbol: "powerplug", message: "This Mac has no battery.")
            }
        }
    }

    private func ring(_ level: Int) -> some View {
        WidgetCard(size: instance.size) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.14), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: CGFloat(level) / 100)
                        .stroke(color(level), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Image(systemName: battery.isCharging ? "bolt.fill" : "battery.75")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                        Text("\(level)%")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }
                .padding(4)
                Text(status)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func bar(_ level: Int) -> some View {
        WidgetCard(size: instance.size, title: "Battery", symbol: symbol(level)) {
            VStack(alignment: .leading, spacing: 12) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(level)%")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Spacer()
                    Text(status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
                ProgressBar(fraction: Double(level) / 100, color: color(level), height: 8)
            }
        }
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
