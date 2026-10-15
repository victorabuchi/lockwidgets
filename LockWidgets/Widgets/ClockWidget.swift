import SwiftUI

struct ClockWidget: View {
    @AppStorage(SettingsKey.use24Hour) private var use24Hour = false
    @AppStorage(SettingsKey.showSeconds) private var showSeconds = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            WidgetCard(title: "Clock", symbol: "clock", showsHeader: false) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(time(context.date))
                            .font(.system(size: 56, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        if !use24Hour {
                            Text(meridiem(context.date))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                    Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
    }

    private func time(_ date: Date) -> String {
        let hour = use24Hour ? "HH" : "h"
        return Self.format(showSeconds ? "\(hour):mm:ss" : "\(hour):mm", date)
    }

    private func meridiem(_ date: Date) -> String {
        Self.format("a", date)
    }

    private static func format(_ pattern: String, _ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
