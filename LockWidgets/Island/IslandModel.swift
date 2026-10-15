import AppKit
import Combine
import SwiftUI

/// Something the island can show, from a playing song to a passing alert.
enum IslandActivity: Equatable {
    // Ongoing, while the thing lasts.
    case meeting
    case timer
    case music
    case hotspot
    // Brief, shown for a few seconds over everything else.
    case charging(level: Int, pluggedIn: Bool)
    case lowBattery(level: Int)
    case notification(NotificationStore.Item)
    case event(title: String, start: Date, color: NSColor)
    case device(name: String, symbol: String, connected: Bool)
    case volume(level: Double, muted: Bool)
    case brightness(level: Double)
    case focus(name: String, symbol: String, on: Bool)

    var isTransient: Bool {
        switch self {
        case .meeting, .timer, .music, .hotspot: false
        default: true
        }
    }

    /// Banners drop down below the notch instead of sitting beside it.
    var isBanner: Bool {
        switch self {
        case .notification, .event: true
        default: false
        }
    }

    /// Width either side of the notch in the compact island.
    var compactSide: CGFloat {
        switch self {
        case .charging, .lowBattery, .device, .focus: 100
        case .volume, .brightness: 90
        case .timer, .meeting: 60
        default: 44
        }
    }

    /// Height of the full card below the notch.
    var expandedHeight: CGFloat {
        switch self {
        case .music: 0
        case .meeting: 118
        case .timer: 104
        default: 84
        }
    }

    var canExpand: Bool { !isTransient }
}

/// What the island is showing and how big it is. Shared by the window (for hit testing) and the view.
final class IslandModel: ObservableObject {
    static let shared = IslandModel()

    @Published private(set) var primary: IslandActivity?
    /// A second ongoing activity, shown as a small bubble beside the island like the iPhone's split island.
    @Published private(set) var secondary: IslandActivity?
    @Published var isExpanded = false
    @Published var isHovering = false

    /// The notch, or a stand-in on displays without one.
    @Published private(set) var notch = CGSize(width: 190, height: 32)
    @Published private(set) var hasNotch = false

    private var transient: IslandActivity?
    private var transientWork: DispatchWorkItem?
    /// Brief activities waiting their turn, so a burst of notifications plays one after another.
    private var pending: [(IslandActivity, Double)] = []
    /// The activity the user brought forward by tapping the bubble.
    private var pinned: IslandActivity?
    private var subscriptions: Set<AnyCancellable> = []

    private init() {
        updateNotch()
        let music = NowPlayingStore.shared
        let timers = TimerStore.shared
        let status = StatusMonitor.shared
        let battery = BatteryMonitor.shared

        Publishers.MergeMany(
            music.$track.map { _ in () }.eraseToAnyPublisher(),
            timers.$pomodoroRunning.map { _ in () }.eraseToAnyPublisher(),
            timers.$stopwatchRunning.map { _ in () }.eraseToAnyPublisher(),
            status.$isOnHotspot.map { _ in () }.eraseToAnyPublisher(),
            status.$meeting.map { $0?.app }.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification).map { _ in () }.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.refresh() }
        .store(in: &subscriptions)

        battery.$isPluggedIn.removeDuplicates().dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] plugged in
                guard self?.setting(SettingsKey.islandBattery) == true else { return }
                self?.show(.charging(level: battery.level ?? 0, pluggedIn: plugged), for: 4)
            }
            .store(in: &subscriptions)
        battery.$level.compactMap { $0 }.removeDuplicates()
            .scan((previous: 100, current: 100)) { ($0.current, $1) }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] change in
                guard self?.setting(SettingsKey.islandBattery) == true, !battery.isPluggedIn else { return }
                for threshold in [20, 10] where change.previous > threshold && change.current <= threshold {
                    self?.show(.lowBattery(level: change.current), for: 6)
                }
            }
            .store(in: &subscriptions)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.updateNotch() }
            .store(in: &subscriptions)

        NotificationStore.shared.onNotification = { [weak self] item in
            guard self?.setting(SettingsKey.islandNotifications) == true else { return }
            self?.show(.notification(item), for: 5)
        }

        DeviceMonitor.shared.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case let .device(name, symbol, connected):
                if setting(SettingsKey.islandDevices) { show(.device(name: name, symbol: symbol, connected: connected), for: 3.5) }
            case let .volume(level, muted):
                if setting(SettingsKey.islandHUD) { show(.volume(level: level, muted: muted), for: 1.6) }
            case let .brightness(level):
                if setting(SettingsKey.islandHUD) { show(.brightness(level: level), for: 1.6) }
            case let .focus(name, symbol, on):
                if setting(SettingsKey.islandFocus) { show(.focus(name: name, symbol: symbol, on: on), for: 3) }
            }
        }
        DeviceMonitor.shared.start()

        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.checkUpcomingEvents()
        }
    }

    /// Events already announced, so each gets one "starting soon" alert.
    private var announcedEvents: Set<String> = []

    private func checkUpcomingEvents() {
        guard setting(SettingsKey.islandCalendar) else { return }
        let now = Date.now
        for event in CalendarStore.shared.events where !event.isAllDay {
            let minutes = event.startDate.timeIntervalSince(now) / 60
            let key = "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)"
            guard minutes > 0, minutes <= 5, !announcedEvents.contains(key) else { continue }
            announcedEvents.insert(key)
            show(.event(title: event.title ?? "Event", start: event.startDate, color: event.calendar.color), for: 8)
        }
    }

    private func setting(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    /// Ongoing activities in priority order.
    private var ongoing: [IslandActivity] {
        var list: [IslandActivity] = []
        if setting(SettingsKey.islandMeetings), StatusMonitor.shared.meeting != nil { list.append(.meeting) }
        let timers = TimerStore.shared
        if setting(SettingsKey.islandTimers), timers.pomodoroRunning || timers.stopwatchRunning { list.append(.timer) }
        if setting(SettingsKey.islandMusic), NowPlayingStore.shared.track != nil { list.append(.music) }
        if setting(SettingsKey.islandHotspot), StatusMonitor.shared.isOnHotspot { list.append(.hotspot) }
        return list
    }

    func refresh() {
        var list = ongoing
        if let pinned, let index = list.firstIndex(of: pinned) {
            list.insert(list.remove(at: index), at: 0)
        } else {
            pinned = nil
        }
        let nextPrimary = transient ?? list.first
        let nextSecondary = transient == nil ? list.dropFirst().first : list.first
        if primary != nextPrimary {
            if primary != nil, nextPrimary != nil, transient == nil { isExpanded = false }
            primary = nextPrimary
        }
        if secondary != nextSecondary { secondary = nextSecondary }
        if primary == nil || primary?.canExpand == false { isExpanded = false }
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "islandExpanded"), primary?.canExpand == true { isExpanded = true }
        #endif
    }

    /// Shows a brief activity over everything else, then returns to what was there.
    func show(_ activity: IslandActivity, for seconds: Double) {
        // Banners queue behind whatever brief thing is showing; quick status alerts replace each other.
        if let current = transient, current.isBanner || activity.isBanner {
            pending.append((activity, seconds))
            return
        }
        transientWork?.cancel()
        isExpanded = false
        transient = activity
        refresh()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            transient = nil
            if !pending.isEmpty {
                let (next, duration) = pending.removeFirst()
                show(next, for: duration)
            } else {
                refresh()
            }
        }
        transientWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    /// Dismisses the current banner early, as when it is tapped.
    func dismissTransient() {
        transientWork?.perform()
    }

    /// Tapping the bubble brings its activity into the island.
    func promoteSecondary() {
        guard let secondary, transient == nil else { return }
        pinned = secondary
        isExpanded = false
        refresh()
    }

    // MARK: Geometry

    static var screen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func updateNotch() {
        guard let screen = Self.screen else { return }
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea
        {
            hasNotch = true
            notch = CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        } else {
            hasNotch = false
            notch = CGSize(width: 190, height: NSStatusBar.system.thickness)
        }
    }

    /// Size of the black shape for the current state.
    var size: CGSize {
        guard let primary else { return notch }
        if primary.isBanner {
            return CGSize(width: max(notch.width + 250, 450), height: notch.height + 74)
        }
        if isExpanded {
            // Music uses the space beside the camera, so its card is measured from the top edge.
            if primary == .music { return CGSize(width: max(notch.width + 250, 450), height: 248) }
            return CGSize(width: max(notch.width + 260, 470), height: notch.height + primary.expandedHeight)
        }
        // Exactly the notch's height, only widened, so it reads as the notch itself growing.
        return CGSize(width: notch.width + primary.compactSide * 2, height: notch.height)
    }

    /// Diameter of the side bubble, and the gap before it.
    var bubble: CGFloat { notch.height }
    static let bubbleGap: CGFloat = 6

    var showsBubble: Bool { secondary != nil && !isExpanded && primary?.isBanner != true }

    /// The notch's own bottom corner radius, used whenever the island is closed.
    static let notchRadius: CGFloat = 10

    var bottomRadius: CGFloat {
        if isExpanded || primary?.isBanner == true { return 36 }
        return Self.notchRadius
    }

    func toggleExpanded() {
        guard primary?.canExpand == true else { return }
        isExpanded.toggle()
    }
}
