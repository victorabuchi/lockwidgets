import SwiftUI

/// Recent Activity: how long you've spent in each app today, like Screen Time. The three apps you've used
/// most get their own colour in the hourly chart.
struct ActivityWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var tracker = ActivityTracker.shared

    private static let colors: [Color] = [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.2, green: 0.78, blue: 0.85), .orange]

    var body: some View {
        WidgetCard(size: instance.size, title: "Today", symbol: "hourglass") {
            let top = tracker.topApps(instance.size == .large ? 6 : 3)
            switch instance.size {
            case .large:
                VStack(alignment: .leading, spacing: 10) {
                    totalText(size: 30)
                    chart(top: top, height: 92)
                    legend(top)
                    Divider().overlay(Color.white.opacity(0.15))
                    appGrid(top)
                }
            case .wide, .ultraWide:
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        totalText(size: 24)
                        chart(top: top, height: 64)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(top, id: \.bundleID) { app in appRow(app) }
                    }
                    .frame(width: 170, alignment: .leading)
                }
            default:
                VStack(alignment: .leading, spacing: 8) {
                    totalText(size: 24)
                    chart(top: top, height: 62)
                }
            }
        }
    }

    private func totalText(size: CGFloat) -> some View {
        Text(tracker.total.durationText)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .lineLimit(1)
    }

    /// 24 hourly bars, the top apps stacked in their colours over everything else in grey.
    private func chart(top: [(bundleID: String, seconds: Double)], height: CGFloat) -> some View {
        let colored = Array(top.prefix(3))
        return VStack(spacing: 3) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0 ..< 24, id: \.self) { hour in
                    let total = tracker.seconds(inHour: hour)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        let others = total - colored.reduce(0) { $0 + (tracker.usage.hours[hour][$1.bundleID] ?? 0) }
                        Rectangle().fill(Color.white.opacity(0.35)).frame(height: height * min(others, 3600) / 3600)
                        ForEach(Array(colored.enumerated().reversed()), id: \.element.bundleID) { index, app in
                            let seconds = tracker.usage.hours[hour][app.bundleID] ?? 0
                            Rectangle().fill(Self.colors[index]).frame(height: height * min(seconds, 3600) / 3600)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: height)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    .background(alignment: .bottom) {
                        if total == 0 { Capsule().fill(Color.white.opacity(0.08)).frame(height: 2) }
                    }
                }
            }
            .frame(height: height)
            HStack {
                ForEach(["0", "6", "12", "18"], id: \.self) { label in
                    Text(label).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Theme.tertiary)
        }
    }

    private func legend(_ top: [(bundleID: String, seconds: Double)]) -> some View {
        HStack(spacing: 14) {
            ForEach(Array(top.prefix(3).enumerated()), id: \.element.bundleID) { index, app in
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Circle().fill(Self.colors[index]).frame(width: 7, height: 7)
                        Text(AppInfo.name(app.bundleID))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                    }
                    Text(app.seconds.durationText)
                        .font(.system(size: 12, weight: .semibold))
                }
            }
        }
    }

    private func appGrid(_ top: [(bundleID: String, seconds: Double)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], alignment: .leading, spacing: 10) {
            ForEach(top, id: \.bundleID) { app in appRow(app) }
        }
    }

    private func appRow(_ app: (bundleID: String, seconds: Double)) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: AppInfo.icon(app.bundleID))
                .resizable()
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text(AppInfo.name(app.bundleID))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(app.seconds.durationText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.secondary)
            }
        }
    }
}
