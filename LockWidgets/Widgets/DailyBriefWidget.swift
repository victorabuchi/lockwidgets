import SwiftUI

struct DailyBriefWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var weather = WeatherStore.shared
    @ObservedObject private var calendar = CalendarStore.shared
    @ObservedObject private var reminders = RemindersStore.shared
    @ObservedObject private var news = NewsStore.shared

    var body: some View {
        TimelineView(.everyMinute) { context in
            WidgetCard(size: instance.size) {
                VStack(alignment: .leading, spacing: instance.size == .large ? 14 : 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Caption(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)), color: Theme.accent)
                        Text(greeting(context.date))
                            .font(.system(size: instance.size == .medium ? 20 : 24, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    if instance.size == .wide {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                weatherLine
                                eventLine(context.date)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 8) {
                                remindersLine
                                headlineLine
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        weatherLine
                        eventLine(context.date)
                        if instance.size == .large {
                            remindersLine
                            headlineLine
                        }
                    }
                }
            }
        }
    }

    private func greeting(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let part = hour < 5 ? "Good night" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
        let name = NSFullUserName().split(separator: " ").first.map(String.init) ?? ""
        return name.isEmpty ? part : "\(part), \(name)"
    }

    @ViewBuilder
    private var weatherLine: some View {
        if let report = weather.report {
            line(WeatherCode.symbol(report.code, isDay: report.isDay),
                 "\(Int(report.temperature.rounded()))° and \(WeatherCode.description(report.code).lowercased()), high of \(Int(report.high.rounded()))°",
                 multicolor: true)
        }
    }

    @ViewBuilder
    private func eventLine(_ now: Date) -> some View {
        if let event = calendar.events.first(where: { $0.endDate > now }) {
            let time = event.isAllDay ? "all day" : event.startDate <= now ? "now" : "at \(event.startDate.formatted(date: .omitted, time: .shortened))"
            line("calendar", "\(event.title ?? "Event") \(time)")
        } else if calendar.hasAccess {
            line("calendar", "Nothing else on your calendar")
        }
    }

    @ViewBuilder
    private var remindersLine: some View {
        if reminders.hasAccess {
            let count = reminders.items.count
            line("checklist", count == 0 ? "No reminders left" : "\(count) reminder\(count == 1 ? "" : "s") to do")
        }
    }

    @ViewBuilder
    private var headlineLine: some View {
        if let headline = news.headlines.first {
            line("newspaper", headline.title)
        }
    }

    private func line(_ symbol: String, _ text: String, multicolor: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .symbolRenderingMode(multicolor ? .multicolor : .monochrome)
                .foregroundStyle(Theme.secondary)
                .frame(width: 16)
            Text(text)
                .lineLimit(instance.size == .large ? 2 : 1)
        }
        .font(.system(size: 13, weight: .semibold))
    }
}
