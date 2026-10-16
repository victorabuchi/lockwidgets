import AppKit

/// Stopwatch and Pomodoro state, shared by their widgets, settings pages and the menu bar.
final class TimerStore: ObservableObject {
    static let shared = TimerStore()

    // MARK: Stopwatch

    @Published private(set) var stopwatchRunning = false
    private var stopwatchStart: Date?
    private var stopwatchAccumulated: TimeInterval = 0

    func stopwatchElapsed(at date: Date = .now) -> TimeInterval {
        stopwatchAccumulated + (stopwatchStart.map { date.timeIntervalSince($0) } ?? 0)
    }

    func toggleStopwatch() {
        if let start = stopwatchStart {
            stopwatchAccumulated += Date.now.timeIntervalSince(start)
            stopwatchStart = nil
            stopwatchRunning = false
        } else {
            stopwatchStart = .now
            stopwatchRunning = true
        }
    }

    func resetStopwatch() {
        stopwatchStart = stopwatchRunning ? .now : nil
        stopwatchAccumulated = 0
        objectWillChange.send()
    }

    // MARK: Pomodoro

    enum Phase: String {
        case focus, shortBreak, longBreak

        var title: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Short Break"
            case .longBreak: "Long Break"
            }
        }
    }

    static let focusMinutesKey = "pomodoroFocusMinutes"
    static let breakMinutesKey = "pomodoroBreakMinutes"
    static let longBreakMinutesKey = "pomodoroLongBreakMinutes"
    static let sessionsPerRound = 4

    @Published private(set) var phase = Phase.focus
    @Published private(set) var pomodoroRunning = false
    /// Focus sessions finished in the current round of four.
    @Published private(set) var completedSessions = 0
    private var phaseEnd: Date?
    private var pausedRemaining: TimeInterval?
    private var ticker: Timer?

    func duration(of phase: Phase) -> TimeInterval {
        let defaults = UserDefaults.standard
        let minutes: Int = switch phase {
        case .focus: defaults.object(forKey: Self.focusMinutesKey) as? Int ?? 25
        case .shortBreak: defaults.object(forKey: Self.breakMinutesKey) as? Int ?? 5
        case .longBreak: defaults.object(forKey: Self.longBreakMinutesKey) as? Int ?? 15
        }
        return TimeInterval(minutes * 60)
    }

    func pomodoroRemaining(at date: Date = .now) -> TimeInterval {
        if let phaseEnd { return max(phaseEnd.timeIntervalSince(date), 0) }
        return pausedRemaining ?? duration(of: phase)
    }

    func togglePomodoro() {
        if pomodoroRunning {
            pausedRemaining = pomodoroRemaining()
            phaseEnd = nil
            pomodoroRunning = false
            ticker?.invalidate()
        } else {
            phaseEnd = Date.now.addingTimeInterval(pausedRemaining ?? duration(of: phase))
            pausedRemaining = nil
            pomodoroRunning = true
            startTicker()
        }
    }

    func resetPomodoro() {
        ticker?.invalidate()
        phase = .focus
        completedSessions = 0
        phaseEnd = nil
        pausedRemaining = nil
        pomodoroRunning = false
    }

    func skipPhase() {
        advance(playSound: false)
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, pomodoroRunning, pomodoroRemaining() <= 0 else { return }
            advance(playSound: true)
        }
    }

    private func advance(playSound: Bool) {
        if phase == .focus {
            completedSessions += 1
            phase = completedSessions >= Self.sessionsPerRound ? .longBreak : .shortBreak
        } else {
            if phase == .longBreak { completedSessions = 0 }
            phase = .focus
        }
        pausedRemaining = nil
        phaseEnd = pomodoroRunning ? Date.now.addingTimeInterval(duration(of: phase)) : nil
        if playSound { NSSound(named: "Glass")?.play() }
    }
}

extension TimeInterval {
    /// 3725 → "1:02:05", 125 → "2:05"
    var clockText: String {
        let total = Int(self.rounded(.down))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }
}

#if DEBUG
extension TimerStore {
    func loadSample() {
        phase = .focus
        pomodoroRunning = true
        completedSessions = 2
        phaseEnd = Date.now.addingTimeInterval(14 * 60 + 32)
        pausedRemaining = nil
        stopwatchRunning = true
        stopwatchStart = Date.now.addingTimeInterval(-192)
        stopwatchAccumulated = 0
    }
}
#endif
