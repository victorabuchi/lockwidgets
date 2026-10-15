import SwiftUI

struct ClockWidget: View {
    let instance: WidgetInstance

    @AppStorage(SettingsKey.use24Hour) private var use24Hour = false
    @AppStorage(SettingsKey.showSeconds) private var showSeconds = false
    @AppStorage(SettingsKey.worldClockZones) private var zones = WorldClock.defaultZones

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            switch instance.style {
            case "analog": analog(context.date)
            case "world": world(context.date)
            default: digital(context.date)
            }
        }
    }

    private func digital(_ date: Date) -> some View {
        let size: CGFloat = switch instance.size {
        case .small: 44
        case .wide: 76
        default: 60
        }
        return WidgetCard(size: instance.size) {
            VStack(alignment: .leading, spacing: 2) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Self.time(date, use24Hour: use24Hour, seconds: showSeconds))
                        .font(.system(size: size, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    if !use24Hour {
                        Text(Self.format("a", date))
                            .font(.system(size: size * 0.3, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.secondary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                Text(date.formatted(instance.size == .small
                        ? .dateTime.weekday(.abbreviated).day().month(.abbreviated)
                        : .dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: instance.size == .small ? 13 : 16, weight: .medium))
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }

    private func analog(_ date: Date) -> some View {
        WidgetCard(size: instance.size, padding: 14) {
            HStack(spacing: 18) {
                AnalogFace(date: date)
                    .aspectRatio(1, contentMode: .fit)
                if instance.size != .small {
                    VStack(alignment: .leading, spacing: 4) {
                        Caption(date.formatted(.dateTime.weekday(.wide)), color: Theme.accent)
                        Text(Self.time(date, use24Hour: use24Hour, seconds: false))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text(date.formatted(.dateTime.month(.wide).day()))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func world(_ date: Date) -> some View {
        let count = instance.size == .medium ? 2 : instance.size == .wide ? 3 : 4
        let list = WorldClock.zones(from: zones).prefix(count)
        return WidgetCard(size: instance.size, title: "World Clock", symbol: "globe") {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(list), id: \.identifier) { zone in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(WorldClock.city(zone))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                        Text(Self.time(date, use24Hour: use24Hour, seconds: false, zone: zone))
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(WorldClock.offset(zone, at: date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    static func time(_ date: Date, use24Hour: Bool, seconds: Bool, zone: TimeZone = .current) -> String {
        let hour = use24Hour ? "HH" : "h"
        return format(seconds ? "\(hour):mm:ss" : "\(hour):mm", date, zone: zone)
    }

    static func format(_ pattern: String, _ date: Date, zone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

enum WorldClock {
    static let defaultZones = "America/New_York,Europe/London,Asia/Tokyo,Australia/Sydney"

    static func zones(from list: String) -> [TimeZone] {
        list.split(separator: ",").compactMap { TimeZone(identifier: String($0).trimmingCharacters(in: .whitespaces)) }
    }

    static func city(_ zone: TimeZone) -> String {
        zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone.identifier
    }

    static func offset(_ zone: TimeZone, at date: Date) -> String {
        let hours = Double(zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)) / 3600
        if hours == 0 { return "Same time" }
        let value = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
        return hours > 0 ? "+\(value) h" : "\(value) h"
    }
}

struct AnalogFace: View {
    let date: Date

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            func point(_ angle: Double, _ length: CGFloat) -> CGPoint {
                CGPoint(x: center.x + sin(angle) * length, y: center.y - cos(angle) * length)
            }

            for tick in 0 ..< 60 {
                let angle = Double(tick) / 60 * 2 * .pi
                let major = tick % 5 == 0
                var path = Path()
                path.move(to: point(angle, radius * (major ? 0.8 : 0.88)))
                path.addLine(to: point(angle, radius * 0.95))
                context.stroke(path, with: .color(.white.opacity(major ? 0.9 : 0.3)), lineWidth: major ? 2 : 1)
            }

            let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
            let second = Double(parts.second ?? 0)
            let minute = Double(parts.minute ?? 0) + second / 60
            let hour = Double((parts.hour ?? 0) % 12) + minute / 60

            func hand(_ angle: Double, _ length: CGFloat, _ width: CGFloat, _ color: Color) {
                var path = Path()
                path.move(to: point(angle + .pi, radius * 0.1))
                path.addLine(to: point(angle, length))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            hand(hour / 12 * 2 * .pi, radius * 0.5, 4.5, .white)
            hand(minute / 60 * 2 * .pi, radius * 0.75, 3, .white)
            hand(second / 60 * 2 * .pi, radius * 0.85, 1.2, Theme.accent)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(Theme.accent))
        }
    }
}
