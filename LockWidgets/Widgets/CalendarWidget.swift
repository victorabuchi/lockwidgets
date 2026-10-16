import EventKit
import SwiftUI

struct CalendarWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var calendar = CalendarStore.shared
    @AppStorage(SettingsKey.calendarIncludeTomorrow) private var includeTomorrow = true

    var body: some View {
        TimelineView(.everyMinute) { context in
            switch instance.style {
            case "monthly": monthly(context.date)
            case "upNext": upNext(context.date)
            default: date(context.date)
            }
        }
    }

    // MARK: Styles

    private func date(_ now: Date) -> some View {
        WidgetCard(size: instance.size) {
            HStack(spacing: 18) {
                bigDate(now, size: instance.size == .small ? 64 : 72)
                if instance.size == .medium {
                    Divider().overlay(Color.white.opacity(0.2))
                    VStack(alignment: .leading, spacing: 10) {
                        WeekStrip(date: now, eventDays: calendar.eventDays)
                        if let next = upcoming(now).first {
                            EventRow(event: next, now: now, compact: true)
                        } else {
                            Text(calendar.hasAccess ? "No more events today" : "Calendar access needed")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func monthly(_ now: Date) -> some View {
        WidgetCard(size: instance.size, padding: instance.size == .small ? 12 : 16) {
            switch instance.size {
            case .small:
                VStack(alignment: .leading, spacing: 4) {
                    Caption(now.formatted(.dateTime.month(.wide).year()), color: Theme.accent)
                    MonthGrid(date: now, fontSize: 9, eventDays: calendar.eventDays)
                }
            case .large:
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(now.formatted(.dateTime.month(.wide)))
                            .font(.system(size: 22, weight: .bold))
                        Text(now.formatted(.dateTime.year()))
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Theme.accent)
                    }
                    MonthGrid(date: now, fontSize: 14, eventDays: calendar.eventDays)
                    Divider().overlay(Color.white.opacity(0.2))
                    ForEach(Array(upcoming(now).prefix(2)), id: \.calendarItemIdentifier) { event in
                        EventRow(event: event, now: now, compact: true)
                    }
                }
            default:
                HStack(spacing: 16) {
                    bigDate(now, size: 60)
                    MonthGrid(date: now, fontSize: 10, eventDays: calendar.eventDays)
                }
            }
        }
    }

    private func upNext(_ now: Date) -> some View {
        let limit: Int = switch instance.size {
        case .small: 2
        case .medium: 3
        case .wide: 6
        default: 7
        }
        let events = Array(upcoming(now).prefix(limit))
        return WidgetCard(size: instance.size, title: "Up Next", symbol: "calendar") {
            if !calendar.hasAccess {
                WidgetPlaceholder(symbol: "lock", message: "Allow calendar access in Notchlight settings.")
            } else if events.isEmpty {
                WidgetPlaceholder(symbol: "checkmark.circle", message: includeTomorrow ? "Nothing else today or tomorrow." : "Nothing else today.")
            } else if instance.size == .wide {
                let today = events.filter { isToday($0, now) }
                let later = events.filter { !isToday($0, now) }
                HStack(alignment: .top, spacing: 16) {
                    column("Today", today, now)
                    column("Tomorrow", later, now)
                }
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(events, id: \.calendarItemIdentifier) { event in
                        EventRow(event: event, now: now, compact: instance.size == .small)
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private func bigDate(_ now: Date, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Caption(now.formatted(.dateTime.weekday(.wide)), color: Theme.accent)
            Text(now.formatted(.dateTime.day()))
                .font(.system(size: size, weight: .regular, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            Text(now.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
        }
        .fixedSize()
    }

    private func column(_ title: String, _ events: [EKEvent], _ now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(title, color: Theme.tertiary)
            if events.isEmpty {
                Text("Nothing scheduled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
            }
            ForEach(events.prefix(3), id: \.calendarItemIdentifier) { event in
                EventRow(event: event, now: now, compact: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isToday(_ event: EKEvent, _ now: Date) -> Bool {
        Calendar.current.isDateInToday(event.startDate) || event.startDate < now
    }

    private func upcoming(_ now: Date) -> [EKEvent] {
        calendar.events.filter { $0.endDate > now && (includeTomorrow || isToday($0, now)) }
    }
}

struct EventRow: View {
    let event: EKEvent
    let now: Date
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(nsColor: event.calendar.color))
                .frame(width: 3.5)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title ?? "Untitled")
                    .font(.system(size: compact ? 12 : 14, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: compact ? 11 : 12, weight: .medium))
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
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        if isHappening { return "Now · until \(end)" }
        let minutes = Int(event.startDate.timeIntervalSince(now) / 60)
        if minutes < 60 { return "In \(Swift.max(minutes, 1)) min · \(start)" }
        if !compact, let location = event.location, !location.isEmpty { return "\(start) – \(end) · \(location)" }
        return "\(start) – \(end)"
    }
}

struct MonthGrid: View {
    let date: Date
    let fontSize: CGFloat
    let eventDays: Set<String>

    var body: some View {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let days = calendar.range(of: .day, in: .month, for: start)!.count
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])
        let today = calendar.component(.day, from: date)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        VStack(spacing: fontSize * 0.35) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: fontSize * 0.9, weight: .bold))
                        .foregroundStyle(Theme.tertiary)
                }
            }
            LazyVGrid(columns: columns, spacing: fontSize * 0.3) {
                ForEach(0 ..< offset, id: \.self) { _ in Color.clear.frame(height: fontSize * 1.5) }
                ForEach(1 ... days, id: \.self) { day in
                    let key = CalendarStore.dayKey(calendar.date(byAdding: .day, value: day - 1, to: start)!)
                    Text("\(day)")
                        .font(.system(size: fontSize, weight: day == today ? .bold : .medium))
                        .monospacedDigit()
                        .frame(width: fontSize * 1.7, height: fontSize * 1.5)
                        .background { if day == today { Circle().fill(Theme.accent) } }
                        .overlay(alignment: .bottom) {
                            if day != today, eventDays.contains(key) {
                                Circle().fill(Theme.accent).frame(width: 3, height: 3).offset(y: 2)
                            }
                        }
                        .foregroundStyle(day < today ? Theme.secondary : Theme.primary)
                }
            }
        }
    }
}

struct WeekStrip: View {
    let date: Date
    let eventDays: Set<String>

    var body: some View {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        HStack(spacing: 0) {
            ForEach(0 ..< 7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                let isToday = calendar.isDate(day, inSameDayAs: date)
                VStack(spacing: 3) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.tertiary)
                    Text(day.formatted(.dateTime.day()))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .background { if isToday { Circle().fill(Theme.accent) } }
                    Circle()
                        .fill(eventDays.contains(CalendarStore.dayKey(day)) ? Theme.secondary : .clear)
                        .frame(width: 3, height: 3)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
