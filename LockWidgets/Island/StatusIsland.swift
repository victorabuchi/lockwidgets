import SwiftUI

// MARK: Bubble

/// A small round icon for a second live activity, shown at the top of the open card.
struct Bubble: View {
    let activity: IslandActivity
    let size: CGFloat
    @ObservedObject private var music = NowPlayingStore.shared

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.14))
            switch activity {
            case .music:
                Artwork(image: music.artwork, size: size - 4, cornerRadius: (size - 4) / 2)
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
        .font(.system(size: size * 0.46, weight: .semibold))
        .frame(width: size, height: size)
        .contentShape(Circle())
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

struct TimerExpanded: View {
    let notch: CGSize
    @ObservedObject private var timers = TimerStore.shared

    var body: some View {
        let timer = activeTimer(timers)
        HStack(spacing: 18) {
            Image(systemName: timer.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(timer.color)
            VStack(alignment: .leading, spacing: 0) {
                Text(timer.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(timer.text(context.date))
                        .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(timer.color)
                }
            }
            Spacer()
            if timers.pomodoroRunning {
                round("pause.fill", timer.color) { timers.togglePomodoro() }
                round("forward.end.fill", .white) { timers.skipPhase() }
            } else {
                round("pause.fill", timer.color) { timers.toggleStopwatch() }
                round("arrow.counterclockwise", .white) { timers.resetStopwatch() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, notch.height + 6)
    }
}

/// The round control buttons used on the iPhone's island.
func round(_ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 38, height: 38)
            .background(color.opacity(0.22), in: Circle())
    }
    .buttonStyle(IslandButtonStyle())
}

// MARK: Meeting

struct MeetingExpanded: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        if let meeting = status.meeting {
            HStack(spacing: 16) {
                if let bundleID = meeting.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.app == "Zoom" ? "Zoom Meeting" : "\(meeting.app) Call")
                        .font(.system(size: 15, weight: .semibold))
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Date.now.timeIntervalSince(meeting.started).clockText)
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.green)
                    }
                    HStack(spacing: 10) {
                        Label(meeting.microphone ? "Mic on" : "Mic off", systemImage: meeting.microphone ? "mic.fill" : "mic.slash.fill")
                        Label(meeting.camera ? "Camera on" : "Camera off", systemImage: meeting.camera ? "video.fill" : "video.slash.fill")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
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
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, notch.height + 8)
        }
    }
}

// MARK: Hotspot

struct HotspotExpanded: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "personalhotspot")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 38, height: 38)
                .background(Color.green.opacity(0.2), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Personal Hotspot")
                    .font(.system(size: 15, weight: .semibold))
                Text("Connected to \(status.hotspot ?? "iPhone")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, notch.height + 6)
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
