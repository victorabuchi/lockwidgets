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

/// The bus, train or plane beside the camera in navigation blue, and on the right the departure time, then the
/// time left once under way, as Maps shows a journey on the iPhone.
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
                        .foregroundStyle(trip.mode.color)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }
}

/// The open card, laid out like a journey's Live Activity in Maps on the iPhone: how you travel and the time
/// left, when you arrive and where, and a blue line with you moving along it to the destination.
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
                    Text(departed ? longDuration(trip.arrival.timeIntervalSince(now)) : "in \(longDuration(trip.departure.timeIntervalSince(now)))")
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(trip.mode.color)
                } below: {
                    HStack(spacing: 6) {
                        Text(trip.title)
                            .font(.system(size: 13, weight: .semibold))
                        if let number = trip.number {
                            Text(number)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer(minLength: 8)
                        Text(departed ? "Arrives \(clock(trip.arrival))" : "Leaves \(clock(trip.departure))")
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .lineLimit(1)
                    .frame(height: 16)
                    .padding(.top, 4)
                    TripProgress(trip: trip, progress: trip.progress(at: now))
                        .padding(.top, 6)
                }
            }
        }
    }
}

/// The journey as a blue line to the destination, with you as a blue arrow moving along it and the way
/// already travelled in grey, as Maps draws it on the iPhone.
private struct TripProgress: View {
    let trip: TripStore.Trip
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let knob: CGFloat = 22, end: CGFloat = 14
            let track = proxy.size.width - knob / 2 - end / 2
            let x = knob / 2 + track * progress
            ZStack(alignment: .leading) {
                Capsule().fill(trip.mode.color)
                    .frame(width: track, height: 6)
                    .offset(x: knob / 2)
                Capsule().fill(.white.opacity(0.3))
                    .frame(width: max(0, x - knob / 2), height: 6)
                    .offset(x: knob / 2)
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().strokeBorder(Color.black, lineWidth: 2.5))
                    .overlay(Circle().fill(Color.black).frame(width: 5, height: 5))
                    .frame(width: end, height: end)
                    .offset(x: proxy.size.width - end)
                Image(systemName: "location.north.fill")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(.white)
                    .frame(width: knob, height: knob)
                    .background(Circle().fill(trip.mode.color))
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2.5))
                    .offset(x: x - knob / 2)
            }
            .frame(height: knob)
        }
        .frame(height: 22)
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

/// The trip window from the menu bar: how you're travelling, where to, when you left and when you arrive. Opened
/// during a trip it changes that trip, so a bus you're already on picks up from how far along you are.
struct TripStartView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var mode: TripStore.Mode = .bus
    @State private var destination = ""
    @State private var departure = Date.now
    @State private var arrival = Date.now.addingTimeInterval(3600)
    @State private var changing = false

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Picker("Travelling by", selection: $mode) {
                    ForEach(TripStore.Mode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                TextField("To", text: $destination, prompt: Text("Kamppi, Helsinki"))
                DatePicker("Left at", selection: $departure, displayedComponents: .hourAndMinute)
                DatePicker("Arrives at", selection: $arrival, displayedComponents: .hourAndMinute)
            }
            .formStyle(.grouped)
            HStack {
                Text("Already on your way? Set when you left, and the island picks up from there.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button("Cancel") { dismissWindow(id: "trip") }
                    .keyboardShortcut(.cancelAction)
                Button(changing ? "Update Trip" : "Start Trip") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 460)
        .onAppear {
            if let trip = TripStore.shared.trip {
                mode = trip.mode
                destination = trip.destination
                departure = trip.departure
                arrival = trip.arrival
                changing = true
            }
        }
    }

    private func save() {
        // The pickers only set hours and minutes, so a departure far in the future means last night, and an
        // arrival before the departure means the next day.
        var left = departure
        if left.timeIntervalSince(.now) > 12 * 3600 { left.addTimeInterval(-86400) }
        var arrives = arrival
        while arrives <= left { arrives.addTimeInterval(86400) }
        TripStore.shared.start(mode: mode, destination: destination, departure: left, arrival: arrives)
        dismissWindow(id: "trip")
    }
}
