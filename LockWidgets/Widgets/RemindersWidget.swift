import SwiftUI

struct RemindersWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var reminders = RemindersStore.shared

    var body: some View {
        let limit = instance.size == .large ? 8 : instance.size == .medium ? 3 : 2
        WidgetCard(size: instance.size, title: "Reminders", symbol: "checklist") {
            if !reminders.hasAccess {
                WidgetPlaceholder(symbol: "lock", message: "Allow Reminders access in Notchlight settings.")
            } else if reminders.items.isEmpty {
                WidgetPlaceholder(symbol: "checkmark.circle", message: "All done.")
            } else {
                VStack(alignment: .leading, spacing: instance.size == .small ? 7 : 9) {
                    if instance.size != .small {
                        Text("\(reminders.items.count) open")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                    }
                    ForEach(reminders.items.prefix(limit)) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .strokeBorder(Color(nsColor: item.color), lineWidth: 1.6)
                                .frame(width: 14, height: 14)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.title)
                                    .font(.system(size: instance.size == .small ? 12 : 13, weight: .semibold))
                                    .lineLimit(1)
                                if let due = item.due, instance.size != .small {
                                    Text(dueText(due))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(due < .now ? Color.red : Theme.secondary)
                                }
                            }
                            if item.isFlagged {
                                Spacer(minLength: 0)
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dueText(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today, \(date.formatted(date: .omitted, time: .shortened))"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}
