import SwiftUI

/// The black shape: flat along the top with small flared shoulders, like the notch it grows out of.
struct IslandShape: Shape {
    var bottomRadius: CGFloat
    var shoulder: CGFloat = 7

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
    @Namespace private var namespace

    var body: some View {
        let size = model.size
        HStack(alignment: .top, spacing: IslandModel.bubbleGap) {
            // Keeps the island centred on the notch when the bubble shows.
            if model.showsBubble {
                Color.clear.frame(width: model.bubble, height: 1)
            }
            island(size)
            if model.showsBubble, let secondary = model.secondary {
                Bubble(activity: secondary, notch: model.notch)
                    .frame(width: model.bubble, height: model.bubble)
                    .onTapGesture { model.promoteSecondary() }
                    .transition(.scale(scale: 0.3, anchor: .leading).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: model.isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.primary)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.secondary)
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

    @ViewBuilder
    private var content: some View {
        let notch = model.notch
        Group {
            if model.isNotchOnly {
                EmptyView()
            } else {
                activityContent(notch)
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.08)),
            removal: .opacity.animation(.easeIn(duration: 0.12))
        ))
        .id(contentID)
    }

    @ViewBuilder
    private func activityContent(_ notch: CGSize) -> some View {
        Group {
            switch (model.primary, model.isExpanded) {
            case (.music, true): MusicExpanded(notch: notch, namespace: namespace)
            case (.music, false): MusicCompact(notch: notch, namespace: namespace)
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
            case (nil, _): EmptyView()
            }
        }
    }

    private var contentID: String {
        "\(String(describing: model.primary))-\(model.isExpanded)"
    }
}

/// Left and right of the notch, the way the iPhone island splits around the camera.
struct CompactSlots<Leading: View, Trailing: View>: View {
    let notch: CGSize
    var side: CGFloat = 44
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: side, alignment: .center)
            Spacer(minLength: notch.width)
            trailing
                .frame(width: side, alignment: .center)
        }
        .padding(.horizontal, 3)
        .frame(height: notch.height)
    }
}
