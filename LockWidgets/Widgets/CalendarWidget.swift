import EventKit
import SwiftUI

struct CalendarWidget: View {
    @ObservedObject private var calendar = CalendarStore.shared
    @AppStorage(SettingsKey.calendarMaxEvents) private var maxEvents = 4
    @AppStorage(SettingsKey.calendarIncludeTomorrow) private var includeTomorrow = true

    var body: some View {
        WidgetCard(title: "Up Next", symbol: "calendar") {
            if !calendar.hasAccess {
                WidgetPlaceholder(symbol: "lock", message: "Allow calendar access in LockWidgets settings.")
            } else {
                // Re-render each minute so "now" and "in 5 min" stay current on the lock screen.
                TimelineView(.everyMinute) { context in
                    let sections = sections(now: context.date)
                    if sections.isEmpty {
                        WidgetPlaceholder(
                            symbol: "checkmark.circle",
                            message: includeTomorrow ? "Nothing else today or tomorrow." : "Nothing else today."
                        )
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(sections, id: \.title) { section in
                            if section.showsTitle {
                                Text(section.title.uppercased())
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(0.6)
                                    .foregroundStyle(Theme.tertiary)
                                    .padding(.top, 2)
                            }
                            ForEach(section.events, id: \.calendarItemIdentifier) { event in
                                EventRow(event: event, now: context.date)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct Section {
        let title: String
        let showsTitle: Bool
        let events: [EKEvent]
    }

    private func sections(now: Date) -> [Section] {
        let isToday = { (event: EKEvent) in Calendar.current.isDateInToday(event.startDate) || event.startDate < now }
        let upcoming = Array(calendar.events.filter { $0.endDate > now && (includeTomorrow || isToday($0)) }.prefix(maxEvents))
        let today = upcoming.filter(isToday)
        let tomorrow = upcoming.filter { !today.contains($0) }
        var result: [Section] = []
        if !today.isEmpty { result.append(Section(title: "Today", showsTitle: !tomorrow.isEmpty, events: today)) }
        if !tomorrow.isEmpty { result.append(Section(title: "Tomorrow", showsTitle: true, events: tomorrow)) }
        return result
    }
}

private struct EventRow: View {
    let event: EKEvent
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHappening ? Color.green : Theme.secondary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var isHappening: Bool {
        !event.isAllDay && event.startDate <= now
    }

    private var detail: String {
        if event.isAllDay { return "All day" }
        let range = "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))"
        if isHappening { return "Now · until \(event.endDate.formatted(date: .omitted, time: .shortened))" }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        if minutes < 60 { return "In \(Swift.max(minutes, 1)) min · \(range)" }
        if let location = event.location, !location.isEmpty { return "\(range) · \(location)" }
        return range
    }
}
