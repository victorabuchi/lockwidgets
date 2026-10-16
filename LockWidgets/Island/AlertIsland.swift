import SwiftUI

struct EventBanner: View {
    let notch: CGSize
    let title: String
    let start: Date
    let color: NSColor

    var body: some View {
        CardLayout(notch: notch) {
            Image(nsImage: AppInfo.icon("com.apple.iCal"))
                .resizable()
                .frame(width: 20, height: 20)
            Text("Calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        } right: {
            Text(start.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        } below: {
            HStack(spacing: 6) {
                Circle().fill(Color(nsColor: color)).frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(height: 16)
            .padding(.top, 4)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let minutes = max(Int(ceil(start.timeIntervalSince(context.date) / 60)), 0)
                Text(minutes == 0 ? "Starting now" : "Starts in \(minutes) min")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

struct DeviceCompact: View {
    let notch: CGSize
    let name: String
    let symbol: String
    let connected: Bool

    var body: some View {
        DropRow(notch: notch) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .truncationMode(.tail)
        } trailing: {
            Text(connected ? "Connected" : "Disconnected")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(connected ? Color.green : Color.white.opacity(0.5))
        }
        .foregroundStyle(.white)
    }
}

/// Volume and brightness, shown in the island the way iOS shows them.
struct LevelCompact: View {
    let notch: CGSize
    let symbol: String
    let level: Double

    var body: some View {
        DropRow(notch: notch) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22)
        } trailing: {
            ProgressBar(fraction: level, color: .white, height: 6)
                .frame(width: max(notch.width - 76, 60))
                .animation(.easeOut(duration: 0.15), value: level)
        }
    }
}

struct FocusCompact: View {
    let notch: CGSize
    let name: String
    let symbol: String
    let on: Bool

    var body: some View {
        DropRow(notch: notch) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(on ? Color.indigo : Color.white.opacity(0.6))
        } trailing: {
            Text(on ? "On" : "Off")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(on ? Color.indigo : Color.white.opacity(0.6))
        }
    }
}
