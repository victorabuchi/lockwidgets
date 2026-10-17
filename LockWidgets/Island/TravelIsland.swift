import SwiftUI

// MARK: Trip

/// "1:05" for an hour or more, "35m" under an hour, for the narrow side of the closed island.
private func shortDuration(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int((seconds / 60).rounded(.up)))
    return minutes >= 60 ? String(format: "%d:%02d", minutes / 60, minutes % 60) : "\(minutes)m"
}

/// "1 h 5 min", "35 min".
private func longDuration(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int((seconds / 60).rounded(.up)))
    return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
}

private func clock(_ date: Date, in zone: TimeZone = .current) -> String {
    date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
}

/// The bus, train or plane beside the camera, and on the right the departure time, then the time left once
/// under way, as an iPhone shows a journey.
struct TripCompact: View {
    let notch: CGSize
    @ObservedObject private var trips = TripStore.shared

    var body: some View {
        if let trip = trips.trip {
            CompactRow(notch: notch) {
                Image(systemName: trip.mode.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(trip.mode.color)
            } trailing: {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    let departed = trip.hasDeparted(at: context.date)
                    Text(departed ? shortDuration(trip.arrival.timeIntervalSince(context.date)) : clock(trip.departure))
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(departed ? trip.mode.color : .white)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }
}

struct TripExpanded: View {
    let notch: CGSize
    @ObservedObject private var trips = TripStore.shared

    var body: some View {
        if let trip = trips.trip {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let now = context.date
                let departed = trip.hasDeparted(at: now)
                CardLayout(notch: notch) {
                    circleIcon(trip.mode.symbol, trip.mode.color)
                } right: {
                    Text(departed ? "\(longDuration(trip.arrival.timeIntervalSince(now))) left" : "in \(longDuration(trip.departure.timeIntervalSince(now)))")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(departed ? trip.mode.color : .white)
                } below: {
                    HStack(spacing: 6) {
                        Text(trip.title)
                            .font(.system(size: 13, weight: .semibold))
                        if let number = trip.number {
                            Text(number)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .lineLimit(1)
                    .frame(height: 16)
                    .padding(.top, 4)
                    TripProgress(trip: trip, progress: trip.progress(at: now))
                        .padding(.top, 4)
                    HStack {
                        Text("\(departed ? "Left" : "Leaves") \(clock(trip.departure))")
                        Spacer()
                        Text("Arrives \(clock(trip.arrival))")
                    }
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(height: 14)
                    .padding(.top, 2)
                }
            }
        }
    }
}

/// The journey as a line that fills from departure to arrival, with the bus, train or plane riding along it.
private struct TripProgress: View {
    let trip: TripStore.Trip
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18)).frame(height: 4)
                Capsule().fill(trip.mode.color).frame(width: max(4, width * progress), height: 4)
                Image(systemName: trip.mode.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(trip.mode.color)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.black))
                    .offset(x: min(max(0, width * progress - 9), width - 18))
            }
            .frame(height: 18)
        }
        .frame(height: 18)
    }
}

// MARK: Home time

private let homeColor = Color(red: 0.39, green: 0.82, blue: 1)

/// While you're in another time zone: a house beside the camera and the time back home on the right.
struct HomeTimeCompact: View {
    let notch: CGSize

    var body: some View {
        CompactRow(notch: notch) {
            Image(systemName: "house.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(homeColor)
        } trailing: {
            TimelineView(.everyMinute) { context in
                Text(clock(context.date, in: HomeTime.zone))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(homeColor)
                    .minimumScaleFactor(0.6)
            }
        }
    }
}

struct HomeTimeExpanded: View {
    let notch: CGSize

    var body: some View {
        TimelineView(.everyMinute) { context in
            CardLayout(notch: notch) {
                circleIcon("house.fill", homeColor)
            } right: {
                Text(clock(context.date, in: HomeTime.zone))
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(homeColor)
            } below: {
                Text("Home in \(HomeTime.city(HomeTime.zone))")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(height: 16)
                    .padding(.top, 4)
                Text("\(HomeTime.city(.current)) is \(HomeTime.difference(at: context.date))")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(height: 14)
            }
        }
    }
}

/// A moment after the Mac changes time zone: the new place and how far it is from home.
struct TimeZoneAlert: View {
    let notch: CGSize
    let city: String
    let detail: String

    var body: some View {
        DropRow(notch: notch) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text(city)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(homeColor)
        } trailing: {
            Text(detail)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: To-dos

private let todoColor = Color(red: 1, green: 0.62, blue: 0.04)

extension RemindersStore {
    /// Reminders due today, or overdue, for the island.
    var dueToday: [Item] {
        let end = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        return items.filter { ($0.due ?? .distantFuture) < end }
    }
}

struct RemindersCompact: View {
    let notch: CGSize
    @ObservedObject private var reminders = RemindersStore.shared

    var body: some View {
        CompactRow(notch: notch) {
            Image(systemName: "checklist")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(todoColor)
        } trailing: {
            Text("\(reminders.dueToday.count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(todoColor)
        }
    }
}

/// The next three to-dos due today, with a dot in each list's colour.
struct RemindersExpanded: View {
    let notch: CGSize
    @ObservedObject private var reminders = RemindersStore.shared

    var body: some View {
        let due = reminders.dueToday
        CardLayout(notch: notch) {
            circleIcon("checklist", todoColor)
        } right: {
            Text("\(due.count) due today")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(todoColor)
        } below: {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(due.prefix(3)) { item in
                    HStack(spacing: 7) {
                        Circle()
                            .strokeBorder(Color(nsColor: item.color), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        Text(item.title)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        if let date = item.due, date < Calendar.current.startOfDay(for: .now) {
                            Text("Overdue")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(height: 15)
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: Starting a trip

/// The small window from the menu bar's "Start a Trip…": how you're travelling, where to and when you arrive.
struct TripStartView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var mode: TripStore.Mode = .bus
    @State private var destination = ""
    @State private var arrival = Date.now.addingTimeInterval(3600)

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Travelling by", selection: $mode) {
                    ForEach(TripStore.Mode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                TextField("To", text: $destination, prompt: Text("Helsinki"))
                DatePicker("Arrives at", selection: $arrival, displayedComponents: .hourAndMinute)
            }
            .formStyle(.grouped)
            HStack {
                Text("The island shows the time left until you arrive.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismissWindow(id: "trip") }
                    .keyboardShortcut(.cancelAction)
                Button("Start Trip") {
                    // A time earlier than now means tomorrow, for an overnight trip.
                    let when = arrival > .now ? arrival : arrival.addingTimeInterval(86400)
                    TripStore.shared.start(mode: mode, destination: destination, arrival: when)
                    dismissWindow(id: "trip")
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 440)
    }
}
