import AppKit
import EventKit

/// Today's and tomorrow's remaining events from every calendar the user has.
final class CalendarStore: ObservableObject {
    static let shared = CalendarStore()

    @Published private(set) var events: [EKEvent] = []
    /// "yyyy-MM-dd" for every day from the start of this month to six weeks on that has an event.
    @Published private(set) var eventDays: Set<String> = []
    @Published private(set) var status = EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()
    private var timer: Timer?

    var hasAccess: Bool { status == .fullAccess }

    private init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.reload()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.reload()
        }
        reload()
    }

    func requestAccess() {
        guard status == .notDetermined else { return }
        store.requestFullAccessToEvents { [weak self] _, _ in
            DispatchQueue.main.async { self?.reload() }
        }
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
    }

    func reload() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard hasAccess else {
            events = []
            eventDays = []
            return
        }
        let now = Date()
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now))!
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > now && $0.status != .canceled }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.startDate < rhs.startDate
            }

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: .day, value: 42, to: monthStart)!
        var days = Set<String>()
        for event in store.events(matching: store.predicateForEvents(withStart: monthStart, end: monthEnd, calendars: nil)) {
            days.insert(Self.dayKey(event.startDate))
        }
        eventDays = days
    }

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}
