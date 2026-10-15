import SwiftUI

// MARK: Bubble

/// The small circle beside the island showing a second ongoing activity.
struct Bubble: View {
    let activity: IslandActivity
    let notch: CGSize
    @ObservedObject private var music = NowPlayingStore.shared

    var body: some View {
        ZStack {
            Circle().fill(Color.black)
            switch activity {
            case .music:
                Artwork(image: music.artwork, size: notch.height - 10, cornerRadius: (notch.height - 10) / 2)
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
        .font(.system(size: 13, weight: .semibold))
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
        CompactSlots(notch: notch, side: IslandActivity.timer.compactSide) {
            Image(systemName: timer.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(timer.color)
        } trailing: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(timer.text(context.date))
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(timer.color)
            }
        }
    }
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
                        .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
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
        .padding(.horizontal, 26)
        .padding(.top, notch.height + 6)
    }
}

/// The round control buttons used on the iPhone's island.
func round(_ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 46, height: 46)
            .background(color.opacity(0.22), in: Circle())
    }
    .buttonStyle(IslandButtonStyle())
}

// MARK: Meeting

struct MeetingCompact: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        CompactSlots(notch: notch, side: IslandActivity.meeting.compactSide) {
            Image(systemName: status.meeting?.camera == true ? "video.fill" : "phone.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        } trailing: {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(Date.now.timeIntervalSince(status.meeting?.started ?? context.date).clockText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.green)
            }
        }
    }
}

struct MeetingExpanded: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        if let meeting = status.meeting {
            HStack(spacing: 16) {
                if let bundleID = meeting.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 48, height: 48)
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
            .padding(.horizontal, 26)
            .padding(.top, notch.height + 8)
        }
    }
}

// MARK: Hotspot

struct HotspotCompact: View {
    let notch: CGSize

    var body: some View {
        CompactSlots(notch: notch) {
            Image(systemName: "personalhotspot")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.green)
        } trailing: {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        }
    }
}

struct HotspotExpanded: View {
    let notch: CGSize
    @ObservedObject private var status = StatusMonitor.shared

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "personalhotspot")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 46, height: 46)
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
        .padding(.horizontal, 26)
        .padding(.top, notch.height + 6)
    }
}

// MARK: Battery

struct ChargingCompact: View {
    let notch: CGSize
    let level: Int
    let pluggedIn: Bool

    var body: some View {
        CompactSlots(notch: notch, side: 96) {
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
        CompactSlots(notch: notch, side: 96) {
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
