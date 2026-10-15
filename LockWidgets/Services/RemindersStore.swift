import AppKit
import EventKit

/// Incomplete reminders from every list, soonest due first.
final class RemindersStore: ObservableObject {
    static let shared = RemindersStore()

    struct Item: Identifiable {
        let id: String
        let title: String
        let due: Date?
        let color: NSColor
        let isFlagged: Bool
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var status = EKEventStore.authorizationStatus(for: .reminder)

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
        store.requestFullAccessToReminders { [weak self] _, _ in
            DispatchQueue.main.async { self?.reload() }
        }
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders")!)
    }

    func reload() {
        status = EKEventStore.authorizationStatus(for: .reminder)
        guard hasAccess else {
            items = []
            return
        }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] reminders in
            let items = (reminders ?? [])
                .map { reminder in
                    Item(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled",
                        due: reminder.dueDateComponents?.date,
                        color: reminder.calendar.color,
                        isFlagged: reminder.priority == 1
                    )
                }
                .sorted { lhs, rhs in
                    switch (lhs.due, rhs.due) {
                    case let (left?, right?): left < right
                    case (_?, nil): true
                    default: false
                    }
                }
            DispatchQueue.main.async { self?.items = items }
        }
    }
}
