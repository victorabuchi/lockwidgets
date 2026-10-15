import SwiftUI

/// The black shape: flat along the top with small flared shoulders, like the notch it grows out of.
struct IslandShape: Shape {
    static let shoulderSize: CGFloat = 7

    var bottomRadius: CGFloat
    var shoulder: CGFloat = IslandShape.shoulderSize

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, (rect.height - shoulder) / 2, (rect.width - shoulder * 2) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + shoulder, y: rect.minY + shoulder), control: CGPoint(x: rect.minX + shoulder, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + shoulder, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + shoulder + r, y: rect.maxY), control: CGPoint(x: rect.minX + shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - shoulder - r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - shoulder, y: rect.maxY - r), control: CGPoint(x: rect.maxX - shoulder, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY + shoulder))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.maxX - shoulder, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct IslandView: View {
    @ObservedObject private var model = IslandModel.shared

    var body: some View {
        island(model.size)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.5, dampingFraction: 0.72), value: model.isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.primary)
            .environment(\.colorScheme, .dark)
    }

    private func island(_ size: CGSize) -> some View {
        ZStack(alignment: .top) {
            IslandShape(bottomRadius: model.bottomRadius)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(model.isExpanded ? 0.5 : 0), radius: 20, y: 8)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(IslandShape(bottomRadius: model.bottomRadius))
        }
        // Width and height move on different springs: closing, the card narrows first and then rises
        // into the notch (a genie-like pull); opening, it widens first and then drops down.
        .frame(height: size.height)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: size.height)
        .frame(width: size.width)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: size.width)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
    }

    private var content: some View {
        activityContent(model.notch)
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.08)),
                removal: .opacity.animation(.easeIn(duration: 0.12))
            ))
            .id(contentID)
    }

    @ViewBuilder
    private func activityContent(_ notch: CGSize) -> some View {
        switch (model.primary, model.isExpanded) {
        case (.music, true): MusicExpanded(notch: notch)
        case (.music, false): MusicCompact(notch: notch)
        case (.timer, true): TimerExpanded(notch: notch)
        case (.timer, false): TimerCompact(notch: notch)
        case (.meeting, true): MeetingExpanded(notch: notch)
        case (.meeting, false): MeetingCompact(notch: notch)
        case (.hotspot, true): HotspotExpanded(notch: notch)
        case (.hotspot, false): HotspotCompact(notch: notch)
        case let (.charging(level, plugged), _): ChargingCompact(notch: notch, level: level, pluggedIn: plugged)
        case let (.lowBattery(level), _): LowBatteryCompact(notch: notch, level: level)
        case let (.notification(item), _): NotificationBanner(notch: notch, item: item)
        case let (.event(title, start, color), _): EventBanner(notch: notch, title: title, start: start, color: color)
        case let (.device(name, symbol, connected), _): DeviceCompact(notch: notch, name: name, symbol: symbol, connected: connected)
        case let (.volume(level, muted), _): LevelCompact(notch: notch, symbol: muted ? "speaker.slash.fill" : level < 0.34 ? "speaker.wave.1.fill" : level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill", level: muted ? 0 : level)
        case let (.brightness(level), _): LevelCompact(notch: notch, symbol: level < 0.5 ? "sun.min.fill" : "sun.max.fill", level: level)
        case let (.focus(name, symbol, on), _): FocusCompact(notch: notch, name: name, symbol: symbol, on: on)
        default: EmptyView()
        }
    }

    private var contentID: String {
        "\(String(describing: model.primary))-\(model.isExpanded)"
    }
}

/// Live activities sit either side of the camera at the notch's own height, like the iPhone's compact island.
/// Each side runs from the shoulder to the notch, so nothing is hidden by the camera or cut by the edge.
struct CompactRow<Leading: View, Trailing: View>: View {
    let notch: CGSize
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let side = IslandModel.wing(notch) - IslandShape.shoulderSize
        HStack(spacing: 0) {
            leading
                .frame(width: side, height: notch.height)
            Spacer(minLength: notch.width)
            trailing
                .frame(width: side, height: notch.height)
        }
        .lineLimit(1)
        .padding(.horizontal, IslandShape.shoulderSize)
        .frame(height: notch.height)
    }
}

/// Brief alerts hang below the notch at the notch's own width, so the island never grows sideways.
struct DropRow<Leading: View, Trailing: View>: View {
    let notch: CGSize
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            leading
            Spacer(minLength: 6)
            trailing
        }
        .lineLimit(1)
        .padding(.horizontal, IslandShape.shoulderSize + 14)
        .frame(height: IslandModel.dropHeight)
        .padding(.top, notch.height)
    }
}
