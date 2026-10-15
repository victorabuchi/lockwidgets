import SwiftUI

// MARK: Bubble

/// A small round icon for a second live activity, on the right of the open card, as on the iPhone.
struct Bubble: View {
    let activity: IslandActivity
    var size: CGFloat = 24
    @ObservedObject private var music = NowPlayingStore.shared

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.14))
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

/// A round icon for the left of the open card's top row, where a song's artwork would be.
private func circleIcon(_ symbol: String, _ color: Color) -> some View {
    Image(systemName: symbol)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(color)
        .frame(width: 28, height: 28)
        .background(color.opacity(0.2), in: Circle())
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
        CardLayout(notch: notch) {
            circleIcon(timer.symbol, timer.color)
        } right: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(timer.text(context.date))
                    .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(timer.color)
            }
        } below: {
            HStack(spacing: 10) {
                Text(timer.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                if timers.pomodoroRunning {
                    round("pause.fill", timer.color) { timers.togglePomodoro() }
                    round("forward.end.fill", .white) { timers.skipPhase() }
                } else {
                    round("pause.fill", timer.color) { timers.toggleStopwatch() }
                    round("arrow.counterclockwise", .white) { timers.resetStopwatch() }
                }
            }
            .frame(height: 30)
            .padding(.top, 6)
        }
    }
}

/// The round control buttons used on the iPhone's island.
func round(_ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
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
            CardLayout(notch: notch) {
                if let bundleID = meeting.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 28, height: 28)
                } else {
                    circleIcon(meeting.camera ? "video.fill" : "phone.fill", .green)
                }
            } right: {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date.timeIntervalSince(meeting.started).clockText)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.green)
                }
            } below: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(meeting.app == "Zoom" ? "Zoom Meeting" : "\(meeting.app) Call")
                            .font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 10) {
                            Label(meeting.microphone ? "Mic on" : "Mic off", systemImage: meeting.microphone ? "mic.fill" : "mic.slash.fill")
                            Label(meeting.camera ? "Camera on" : "Camera off", systemImage: meeting.camera ? "video.fill" : "video.slash.fill")
                        }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    }
                    .lineLimit(1)
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
                .frame(height: 30)
                .padding(.top, 6)
            }
        }
    }
}

// MARK: Hotspot

/// The hotspot sits where a song's artwork would, on the left beside the camera.
struct HotspotExpanded: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        CardLayout(notch: notch) {
            circleIcon("personalhotspot", .green)
        } right: {
            EmptyView()
        } below: {
            Text("Personal Hotspot")
                .font(.system(size: 13, weight: .semibold))
                .frame(height: 16)
                .padding(.top, 4)
            Text("Connected to \(status.hotspot ?? "iPhone")")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .frame(height: 14)
        }
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
