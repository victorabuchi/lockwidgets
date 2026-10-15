import SwiftUI

/// The black shape: square along the top, where it meets the notch and the screen edge, with rounded
/// bottom corners like the notch's own.
struct IslandShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = max(0, min(bottomRadius, rect.height / 2, rect.width / 2))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
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
        .overlay(alignment: .topTrailing) {
            // A second live activity, such as the hotspot while a song plays, waits in its own circle
            // on the right, as on the iPhone.
            if model.showsBubble, let secondary = model.secondary {
                Bubble(activity: secondary, size: model.bubbleSize, fill: .black)
                    .offset(x: IslandModel.bubbleGap + model.bubbleSize)
                    .transition(.scale(scale: 0.4, anchor: .leading).combined(with: .opacity))
            }
        }
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
/// Each side runs from the island's edge to the notch, so nothing is hidden by the camera.
struct CompactRow<Leading: View, Trailing: View>: View {
    let notch: CGSize
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        let side = IslandModel.wing(notch)
        HStack(spacing: 0) {
            leading
                .frame(width: side, height: notch.height)
            Spacer(minLength: notch.width)
            trailing
                .frame(width: side, height: notch.height)
        }
        .lineLimit(1)
        .frame(height: notch.height)
    }
}

/// The open card and banners. They are wider than the notch, so their top row sits either side of the
/// camera, something on the left and something on the right, and the rest runs full width below it.
struct CardLayout<Left: View, Right: View, Below: View>: View {
    let notch: CGSize
    @ViewBuilder var left: Left
    @ViewBuilder var right: Right
    @ViewBuilder var below: Below

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 6) { left }
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear
                    .frame(width: notch.width)
                HStack(spacing: 6) { right }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .lineLimit(1)
            .frame(height: notch.height)
            VStack(alignment: .leading, spacing: 0) { below }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .padding(.horizontal, 14)
        .frame(height: IslandModel.dropHeight)
        .padding(.top, notch.height)
    }
}
