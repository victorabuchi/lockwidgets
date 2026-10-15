import SwiftUI

struct SystemWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var monitor = SystemMonitor.shared

    var body: some View {
        let sample = monitor.current
        if instance.style == "gauges" {
            WidgetCard(size: instance.size, title: instance.size == .small ? nil : "System", symbol: "cpu") {
                HStack(spacing: 14) {
                    gauge(sample.cpu, "CPU", .purple)
                    if instance.size == .medium {
                        gauge(sample.memory, "Memory", .green)
                        VStack(alignment: .leading, spacing: 6) {
                            metricLine("arrow.down", sample.download.rateText)
                            metricLine("arrow.up", sample.upload.rateText)
                            metricLine("internaldrive", "\(Int(sample.diskFreeGB)) GB free")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            WidgetCard(size: instance.size, title: "System", symbol: "cpu") {
                VStack(spacing: instance.size == .large ? 12 : 6) {
                    row("cpu", "CPU", "\(Int(sample.cpu * 100))%", monitor.cpuHistory, .purple)
                    row("memorychip", "Memory", "\(Int(sample.memory * 100))%", monitor.memoryHistory, .green)
                    row("arrow.up.arrow.down", "Network", "↓\(sample.download.rateText)", monitor.networkHistory, .cyan)
                    if instance.size == .large {
                        row("internaldrive", "Disk Free", "\(Int(sample.diskFreeGB)) of \(Int(sample.diskTotalGB)) GB", nil, .orange)
                        row("gauge.with.dots.needle.33percent", "1m Load", String(format: "%.2f", sample.load), nil, .pink)
                        row("clock.arrow.circlepath", "Uptime", uptime(sample.uptime), nil, .yellow)
                    }
                }
            }
        }
    }

    private func gauge(_ value: Double, _ label: String, _ color: Color) -> some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 8)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(3)
        .animation(.easeInOut, value: value)
    }

    private func metricLine(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.secondary)
            .lineLimit(1)
    }

    private func row(_ symbol: String, _ label: String, _ value: String, _ history: [Double]?, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 66, alignment: .leading)
            if let history {
                Sparkline(values: history, color: color)
                    .frame(height: 16)
            } else {
                Spacer()
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .frame(minWidth: 70, alignment: .trailing)
        }
    }

    private func uptime(_ seconds: TimeInterval) -> String {
        let days = Int(seconds) / 86400
        let hours = Int(seconds) / 3600 % 24
        return days > 0 ? "\(days)d \(hours)h" : "\(hours)h \(Int(seconds) / 60 % 60)m"
    }
}

struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let peak = max(values.max() ?? 1, 0.0001)
            Path { path in
                guard values.count > 1 else { return }
                for (index, value) in values.enumerated() {
                    let point = CGPoint(
                        x: proxy.size.width * CGFloat(index) / CGFloat(values.count - 1),
                        y: proxy.size.height * (1 - CGFloat(value / peak))
                    )
                    index == 0 ? path.move(to: point) : path.addLine(to: point)
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
