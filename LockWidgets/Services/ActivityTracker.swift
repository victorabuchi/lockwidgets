import AppKit

/// Time spent in each app today, hour by hour, for the Recent Activity widget. Notchlight notes which app
/// is in front and adds up the time, pausing while the Mac is locked or asleep. It never leaves this Mac.
final class ActivityTracker: ObservableObject {
    static let shared = ActivityTracker()

    struct Usage: Codable, Equatable {
        var day: String
        /// Seconds per app for each hour of the day, keyed by bundle identifier.
        var hours: [[String: Double]]

        static func empty(_ day: String) -> Usage { Usage(day: day, hours: Array(repeating: [:], count: 24)) }
    }

    @Published private(set) var usage: Usage

    private var current: (bundleID: String, since: Date)?
    private var paused = false
    private var timer: Timer?
    private var started = false

    private static var file: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Notchlight", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("activity.json")
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private init() {
        let today = Self.dayKey(.now)
        if let data = try? Data(contentsOf: Self.file), let saved = try? JSONDecoder().decode(Usage.self, from: data), saved.day == today, saved.hours.count == 24 {
            usage = saved
        } else {
            usage = .empty(today)
        }
    }

    func start() {
        guard !started else { return }
        started = true
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.switchTo(app?.bundleIdentifier)
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.pause() }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.resume() }
        }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in self?.pause() }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in self?.resume() }

        switchTo(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.flush()
            self?.save()
        }
    }

    // MARK: Totals for the widget

    var total: Double { usage.hours.reduce(0) { $0 + $1.values.reduce(0, +) } }

    func seconds(inHour hour: Int) -> Double { usage.hours[hour].values.reduce(0, +) }

    /// Apps by time today, longest first.
    func topApps(_ count: Int) -> [(bundleID: String, seconds: Double)] {
        var totals: [String: Double] = [:]
        for hour in usage.hours { for (app, seconds) in hour { totals[app, default: 0] += seconds } }
        return totals.sorted { $0.value > $1.value }.prefix(count).map { ($0.key, $0.value) }
    }

    func reset() {
        usage = .empty(Self.dayKey(.now))
        current = current.map { ($0.bundleID, Date.now) }
        save()
    }

    // MARK: Counting

    private func switchTo(_ bundleID: String?) {
        flush()
        current = bundleID.map { ($0, Date.now) }
    }

    private func pause() {
        flush()
        paused = true
        save()
    }

    private func resume() {
        paused = false
        current = current.map { ($0.bundleID, Date.now) }
    }

    /// Adds the time since the last count to the app in front, split across the hours it spans.
    private func flush(until end: Date = .now) {
        guard let current, !paused, end > current.since else { return }
        var next = usage
        var start = current.since
        while start < end {
            let day = Self.dayKey(start)
            if next.day != day { next = .empty(day) }
            let hourStart = Calendar.current.dateInterval(of: .hour, for: start)?.end ?? end
            let stop = min(hourStart, end)
            let hour = Calendar.current.component(.hour, from: start)
            next.hours[hour][current.bundleID, default: 0] += stop.timeIntervalSince(start)
            start = stop
        }
        self.current = (current.bundleID, end)
        if next != usage { usage = next }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(usage) {
            try? data.write(to: Self.file, options: .atomic)
        }
    }
}

/// Names and icons of installed apps, looked up once.
enum AppInfo {
    private static var cache: [String: (name: String, icon: NSImage)] = [:]

    static func url(_ bundleID: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func name(_ bundleID: String) -> String { lookup(bundleID).name }
    static func icon(_ bundleID: String) -> NSImage { lookup(bundleID).icon }

    private static func lookup(_ bundleID: String) -> (name: String, icon: NSImage) {
        if let cached = cache[bundleID] { return cached }
        let info: (name: String, icon: NSImage)
        if let url = url(bundleID) {
            info = (FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""), NSWorkspace.shared.icon(forFile: url.path))
        } else {
            info = (bundleID.components(separatedBy: ".").last ?? bundleID, NSWorkspace.shared.icon(for: .application))
        }
        cache[bundleID] = info
        return info
    }
}

extension Double {
    /// "4 h 41 min", "41 min" or "under a minute".
    var durationText: String {
        let minutes = Int(self / 60)
        if minutes < 1 { return "0 min" }
        let hours = minutes / 60
        return hours > 0 ? "\(hours) h \(minutes % 60) min" : "\(minutes) min"
    }
}

