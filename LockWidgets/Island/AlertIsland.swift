import SwiftUI

struct EventBanner: View {
    let notch: CGSize
    let title: String
    let start: Date
    let color: NSColor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(nsColor: color))
                .frame(width: 38, height: 38)
                .background(Color(nsColor: color).opacity(0.2), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    let minutes = max(Int(ceil(start.timeIntervalSince(context.date) / 60)), 0)
                    Text(minutes == 0 ? "Starting now" : "Starts in \(minutes) min · \(start.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, notch.height + 6)
    }
}

struct DeviceCompact: View {
    let notch: CGSize
    let name: String
    let symbol: String
    let connected: Bool

    var body: some View {
        CompactSlots(notch: notch, side: 100) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(connected ? "Connected" : "Off")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(connected ? .white : .white.opacity(0.5))
        } trailing: {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(connected ? Color.green : Color.white.opacity(0.5))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

/// Volume and brightness, shown in the island the way iOS shows them.
struct LevelCompact: View {
    let notch: CGSize
    let symbol: String
    let level: Double

    var body: some View {
        CompactSlots(notch: notch, side: 90) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        } trailing: {
            ProgressBar(fraction: level, color: .white, height: 6)
                .frame(width: 66)
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
        CompactSlots(notch: notch, side: 100) {
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
