import SwiftUI

struct CountdownWidget: View {
    let instance: WidgetInstance

    var body: some View {
        let target = Countdown.target(instance)
        let title = Countdown.title(instance)
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(target.timeIntervalSince(context.date), 0)
            let days = Int(remaining / 86400)
            if instance.style == "units" {
                WidgetCard(size: instance.size, title: title, symbol: "hourglass") {
                    HStack(spacing: instance.size == .wide ? 12 : 8) {
                        unit(days, "days")
                        unit(Int(remaining) / 3600 % 24, "hours")
                        unit(Int(remaining) / 60 % 60, "min")
                        if instance.size == .wide {
                            unit(Int(remaining) % 60, "sec")
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            } else {
                WidgetCard(size: instance.size) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Caption(title, color: Theme.accent)
                            Spacer(minLength: 0)
                            Text("\(days)")
                                .font(.system(size: instance.size == .small ? 58 : 66, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(days == 1 ? "day to go" : "days to go")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.secondary)
                        }
                        if instance.size == .medium {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(target.formatted(.dateTime.weekday(.wide)))
                                    .font(.system(size: 14, weight: .semibold))
                                Text(target.formatted(.dateTime.day().month(.wide).year()))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.secondary)
                                Text("\(Int(remaining) / 3600 % 24)h \(Int(remaining) / 60 % 60)m")
                                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                                    .foregroundStyle(Theme.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.tertiary)
        }
    }
}

enum Countdown {
    static func title(_ instance: WidgetInstance) -> String {
        let title = instance.config["title"] ?? ""
        return title.isEmpty ? "New Year" : title
    }

    static func target(_ instance: WidgetInstance) -> Date {
        if let stored = instance.config["date"], let interval = Double(stored) {
            return Date(timeIntervalSince1970: interval)
        }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now) + 1
        return calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }
}

struct PomodoroWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var timers = TimerStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timers.pomodoroRemaining(at: context.date)
            let total = timers.duration(of: timers.phase)
            let color = timers.phase == .focus ? Theme.accent : Color.green
            WidgetCard(size: instance.size, padding: 14) {
                HStack(spacing: 18) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.14), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: total > 0 ? remaining / total : 0)
                            .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text(remaining.clockText)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            if instance.size == .small {
                                Text(timers.phase.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)
                    .padding(4)

                    if instance.size == .medium {
                        VStack(alignment: .leading, spacing: 6) {
                            Caption("Pomodoro", color: color)
                            Text(timers.phase.title)
                                .font(.system(size: 22, weight: .semibold))
                            Text(timers.pomodoroRunning ? "In progress" : "Paused")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.secondary)
                            HStack(spacing: 5) {
                                ForEach(0 ..< TimerStore.sessionsPerRound, id: \.self) { index in
                                    Circle()
                                        .fill(index < timers.completedSessions ? color : Color.white.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct StopwatchWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var timers = TimerStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = timers.stopwatchElapsed(at: context.date)
            let tenths = Int(elapsed * 10) % 10
            WidgetCard(size: instance.size, title: "Stopwatch", symbol: "stopwatch") {
                VStack(alignment: .leading, spacing: 4) {
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(elapsed.clockText)
                            .font(.system(size: instance.size == .small ? 40 : 60, weight: .semibold, design: .rounded))
                        Text(".\(tenths)")
                            .font(.system(size: instance.size == .small ? 22 : 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.secondary)
                    }
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    Label(timers.stopwatchRunning ? "Running" : elapsed > 0 ? "Paused" : "Ready",
                          systemImage: timers.stopwatchRunning ? "play.fill" : "pause.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(timers.stopwatchRunning ? Color.green : Theme.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
