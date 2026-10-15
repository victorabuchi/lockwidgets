import SwiftUI

// MARK: Bubble

/// A small round icon for a second live activity: beside the closed island, and on the right of the open card.
struct Bubble: View {
    let activity: IslandActivity
    var size: CGFloat = 22
    var fill = Color.white.opacity(0.14)
    @ObservedObject private var music = NowPlayingStore.shared

    var body: some View {
        ZStack {
            Circle().fill(fill)
            switch activity {
            case .music:
                Artwork(image: music.artwork, size: size * 0.78, cornerRadius: size * 0.39)
            case .timer:
                Image(systemName: "timer").foregroundStyle(.orange)
            case .meeting:
                Image(systemName: "video.fill").foregroundStyle(.green)
            case .hotspot:
                Image(systemName: "personalhotspot").foregroundStyle(.green)
            default:
                EmptyView()
            }
        }
        .font(.system(size: size * 0.5, weight: .semibold))
        .frame(width: size, height: size)
    }
}

// MARK: Timer

private struct ActiveTimer {
    let symbol: String
    let title: String
    let color: Color
    let text: (Date) -> String
}

private func activeTimer(_ timers: TimerStore) -> ActiveTimer {
    if timers.pomodoroRunning {
        let color: Color = timers.phase == .focus ? .orange : .green
        return ActiveTimer(symbol: "timer", title: timers.phase.title, color: color) { timers.pomodoroRemaining(at: $0).clockText }
    }
    return ActiveTimer(symbol: "stopwatch", title: "Stopwatch", color: .orange) { timers.stopwatchElapsed(at: $0).clockText }
}

struct TimerCompact: View {
    let notch: CGSize
    @ObservedObject private var timers = TimerStore.shared

    var body: some View {
        let timer = activeTimer(timers)
        CompactRow(notch: notch) {
            Image(systemName: timer.symbol)
                .font(.system(size: 15, weight: .semibold))
        } trailing: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(timer.text(context.date))
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(timer.color)
    }
}

struct TimerExpanded: View {
    let notch: CGSize
    @ObservedObject private var timers = TimerStore.shared

    var body: some View {
        let timer = activeTimer(timers)
        HStack(spacing: 8) {
            Image(systemName: timer.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(timer.color)
            VStack(alignment: .leading, spacing: 0) {
                Text(timer.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(timer.text(context.date))
                        .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(timer.color)
                        .minimumScaleFactor(0.6)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            if timers.pomodoroRunning {
                round("pause.fill", timer.color) { timers.togglePomodoro() }
                round("forward.end.fill", .white) { timers.skipPhase() }
            } else {
                round("pause.fill", timer.color) { timers.toggleStopwatch() }
                round("arrow.counterclockwise", .white) { timers.resetStopwatch() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, notch.height + 8)
    }
}

/// The round control buttons used on the iPhone's island.
func round(_ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.22), in: Circle())
    }
    .buttonStyle(IslandButtonStyle())
}

// MARK: Meeting

struct MeetingCompact: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        CompactRow(notch: notch) {
            Image(systemName: status.meeting?.camera == true ? "video.fill" : "phone.fill")
                .font(.system(size: 14, weight: .semibold))
        } trailing: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.timeIntervalSince(status.meeting?.started ?? context.date).clockText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(.green)
    }
}

struct MeetingExpanded: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared
    @ObservedObject private var island = IslandModel.shared

    var body: some View {
        if let meeting = status.meeting {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    if let bundleID = meeting.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 30, height: 30)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(meeting.app == "Zoom" ? "Zoom Meeting" : "\(meeting.app) Call")
                            .font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 6) {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                Text(context.date.timeIntervalSince(meeting.started).clockText)
                                    .foregroundStyle(.green)
                            }
                            Image(systemName: meeting.microphone ? "mic.fill" : "mic.slash.fill")
                                .help(meeting.microphone ? "Mic on" : "Mic off")
                            Image(systemName: meeting.camera ? "video.fill" : "video.slash.fill")
                                .help(meeting.camera ? "Camera on" : "Camera off")
                        }
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    if let other = island.secondary {
                        Bubble(activity: other)
                    }
                }
                .frame(height: 30)
                HStack(spacing: 12) {
                    if meeting.app == "Zoom" {
                        round("mic.slash.fill", .white) { StatusMonitor.sendZoomShortcut(StatusMonitor.zoomMuteKey) }
                            .help("Mute or unmute in Zoom")
                        round("video.slash.fill", .white) { StatusMonitor.sendZoomShortcut(StatusMonitor.zoomVideoKey) }
                            .help("Start or stop video in Zoom")
                    }
                    round("arrow.up.forward.app.fill", .green) {
                        if let bundleID = meeting.bundleID {
                            NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.activate()
                        }
                    }
                    .help("Open \(meeting.app)")
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.top, notch.height + 8)
        }
    }
}

// MARK: Hotspot

/// While closed, the hotspot sits where a song's artwork would, as on the iPhone.
struct HotspotCompact: View {
    let notch: CGSize

    var body: some View {
        CompactRow(notch: notch) {
            Image(systemName: "personalhotspot")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.green)
        } trailing: {
            Color.clear
        }
    }
}

struct HotspotExpanded: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "personalhotspot")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 30, height: 30)
                .background(Color.green.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("Personal Hotspot")
                    .font(.system(size: 13, weight: .semibold))
                Text("Connected to \(status.hotspot ?? "iPhone")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, notch.height + 8)
    }
}

// MARK: Battery

struct ChargingCompact: View {
    let notch: CGSize
    let level: Int
    let pluggedIn: Bool

    var body: some View {
        DropRow(notch: notch) {
            Text(pluggedIn ? "Charging" : "On Battery")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(pluggedIn ? .green : .white)
        } trailing: {
            HStack(spacing: 4) {
                Text("\(level)%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                Image(systemName: pluggedIn ? "battery.100.bolt" : "battery.75")
                    .font(.system(size: 15))
            }
            .foregroundStyle(pluggedIn ? .green : .white)
        }
    }
}

struct LowBatteryCompact: View {
    let notch: CGSize
    let level: Int

    var body: some View {
        DropRow(notch: notch) {
            Text("Low Battery")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
        } trailing: {
            HStack(spacing: 4) {
                Text("\(level)%")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                Image(systemName: "battery.25")
                    .font(.system(size: 15))
            }
            .foregroundStyle(.red)
        }
    }
}
