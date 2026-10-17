import AppKit
import Combine
import EventKit
import SwiftUI

/// The trip you're on by bus, train or plane, for the island: one started from the menu bar, or one found in
/// your calendar, such as a flight. Like a Live Activity on the iPhone, it counts down to departure and then
/// follows the journey. A Mac has no GPS, so the journey is followed by the clock, from departure to arrival.
final class TripStore: ObservableObject {
    static let shared = TripStore()

    enum Mode: String, CaseIterable, Codable, Identifiable {
        case bus, train, plane

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bus: "Bus"
            case .train: "Train"
            case .plane: "Plane"
            }
        }

        var symbol: String {
            switch self {
            case .bus: "bus.fill"
            case .train: "train.side.front.car"
            case .plane: "airplane"
            }
        }

        var color: Color {
            switch self {
            case .bus: Color(red: 1, green: 0.62, blue: 0.04)
            case .train: Color(red: 0.19, green: 0.82, blue: 0.35)
            case .plane: Color(red: 0.39, green: 0.82, blue: 1)
            }
        }
    }

    struct Trip: Codable, Equatable {
        var mode: Mode
        var destination: String
        var departure: Date
        var arrival: Date
        /// A flight number, when the calendar event has one.
        var number: String?
        /// The calendar event it came from, so ending the trip hides that event.
        var eventKey: String?

        var title: String { destination.isEmpty ? mode.title : "\(mode.title) to \(destination)" }

        func hasDeparted(at date: Date) -> Bool { date >= departure }

        /// How far along the journey is, from 0 at departure to 1 at arrival.
        func progress(at date: Date) -> Double {
            let length = arrival.timeIntervalSince(departure)
            guard length > 0 else { return 1 }
            return min(1, max(0, date.timeIntervalSince(departure) / length))
        }
    }

    @Published private(set) var trip: Trip?

    private static let savedKey = "tripInProgress"
    /// A trip started from the menu bar. It ends ten minutes after arrival, or when you end it.
    private var manual: Trip? {
        didSet { save() }
    }

    /// Calendar trips you ended, so they don't come back.
    private var ended: Set<String> = []
    private var timer: Timer?
    private var subscription: AnyCancellable?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.savedKey) {
            manual = try? JSONDecoder().decode(Trip.self, from: data)
        }
        subscription = CalendarStore.shared.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func start(mode: Mode, destination: String, arrival: Date) {
        let now = Date.now
        manual = Trip(
            mode: mode,
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines),
            departure: now,
            arrival: max(arrival, now.addingTimeInterval(60))
        )
        refresh()
    }

    func end() {
        if let key = trip?.eventKey { ended.insert(key) }
        manual = nil
        refresh()
    }

    func refresh() {
        let now = Date.now
        if let current = manual, current.arrival.addingTimeInterval(10 * 60) < now { manual = nil }
        let next = manual ?? calendarTrip(now: now)
        if trip != next { trip = next }
    }

    private func save() {
        if let manual, let data = try? JSONEncoder().encode(manual) {
            UserDefaults.standard.set(data, forKey: Self.savedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.savedKey)
        }
    }

    // MARK: Trips in the calendar

    /// The soonest trip in the calendar that leaves within three hours or is under way.
    private func calendarTrip(now: Date) -> Trip? {
        for event in CalendarStore.shared.events where !event.isAllDay {
            guard event.endDate > now, event.startDate.timeIntervalSince(now) < 3 * 3600 else { continue }
            let key = "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)"
            guard !ended.contains(key), let mode = Self.mode(of: event) else { continue }
            return Trip(
                mode: mode,
                destination: Self.destination(of: event),
                departure: event.startDate,
                arrival: event.endDate,
                number: mode == .plane ? Self.flightNumber(in: event.title ?? "") : nil,
                eventKey: key
            )
        }
        return nil
    }

    /// Words that mark an event as a journey, in English and Finnish, matched as whole words so "business"
    /// isn't a bus and "training" isn't a train.
    private static let words: [(Mode, String)] = [
        (.plane, #"\b(flight|flights|fly|flying|airport|boarding|lento|lennon)\b|✈"#),
        (.train, #"\b(train|rail|railway|juna|junalla|pendolino|intercity|eurostar|amtrak)\b"#),
        (.bus, #"\b(bus|coach|bussi|bussilla|linja-auto|onnibus|matkahuolto|flixbus|megabus)\b"#),
    ]

    static func mode(of event: EKEvent) -> Mode? {
        let title = event.title ?? ""
        if flightNumber(in: title) != nil { return .plane }
        let text = [title, event.location ?? "", String((event.notes ?? "").prefix(300))].joined(separator: " ")
        for (mode, pattern) in words where text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return mode
        }
        return nil
    }

    /// An airline code and number at the start of the title, such as "AY 1031" or "Flight FR123".
    static func flightNumber(in title: String) -> String? {
        guard let range = title.range(of: #"^(?:Flight\s+)?[A-Z][A-Z0-9]\s?\d{2,4}\b"#, options: .regularExpression) else { return nil }
        return title[range].replacingOccurrences(of: "Flight", with: "").trimmingCharacters(in: .whitespaces)
    }

    /// Where the trip goes: "Helsinki" from "Bus to Helsinki" or "Turku – Helsinki", else the event's location.
    static func destination(of event: EKEvent) -> String {
        let title = event.title ?? ""
        if let range = title.range(of: #"\bto\s+[^(,]+"#, options: [.regularExpression, .caseInsensitive]) {
            return String(title[range].dropFirst(2)).trimmingCharacters(in: .whitespaces)
        }
        for separator in ["→", "->", " – ", " — ", " - "] where title.contains(separator) {
            if let last = title.components(separatedBy: separator).last?.split(separator: "(").first {
                return String(last).trimmingCharacters(in: .whitespaces)
            }
        }
        if let place = event.location?.split(whereSeparator: { $0 == "," || $0 == "\n" }).first {
            return String(place).trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}

/// The time back home while your Mac is in another time zone. Home is the time zone Notchlight first saw,
/// until you choose another in Island settings.
enum HomeTime {
    static var zone: TimeZone {
        if let id = UserDefaults.standard.string(forKey: SettingsKey.homeTimeZone), let zone = TimeZone(identifier: id) { return zone }
        return .current
    }

    /// Remembers where home is the first time Notchlight runs, before any travel.
    static func rememberHome() {
        guard UserDefaults.standard.string(forKey: SettingsKey.homeTimeZone) == nil else { return }
        setHomeToCurrent()
    }

    static func setHomeToCurrent() {
        UserDefaults.standard.set(TimeZone.current.identifier, forKey: SettingsKey.homeTimeZone)
    }

    /// True while the Mac's clock shows a different time from home.
    static var isAway: Bool { offset(at: .now) != 0 }

    /// Seconds the local time is ahead of home; negative when behind.
    static func offset(at date: Date) -> Int {
        TimeZone.current.secondsFromGMT(for: date) - zone.secondsFromGMT(for: date)
    }

    static func city(_ zone: TimeZone) -> String {
        (zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier).replacingOccurrences(of: "_", with: " ")
    }

    /// "2 hours ahead of Helsinki", "30 min behind Helsinki".
    static func difference(at date: Date = .now) -> String {
        let seconds = offset(at: date)
        let hours = abs(seconds) / 3600, minutes = abs(seconds) % 3600 / 60
        let amount = switch (hours, minutes) {
        case (1, 0): "1 hour"
        case (_, 0): "\(hours) hours"
        case (0, _): "\(minutes) min"
        default: "\(hours) h \(minutes) min"
        }
        return "\(amount) \(seconds > 0 ? "ahead of" : "behind") \(city(zone))"
    }

    /// "+2 h", "−1 h", "+5:30", for the short alert under the notch.
    static func shortDifference(at date: Date = .now) -> String {
        let seconds = offset(at: date)
        let hours = abs(seconds) / 3600, minutes = abs(seconds) % 3600 / 60
        let sign = seconds > 0 ? "+" : "−"
        return minutes == 0 ? "\(sign)\(hours) h" : "\(sign)\(hours):\(String(format: "%02d", minutes))"
    }
}
