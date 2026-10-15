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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.isHovering)
        .environment(\.colorScheme, .dark)
    }

    private func island(_ size: CGSize) -> some View {
        ZStack(alignment: .top) {
            IslandShape(bottomRadius: model.isExpanded || model.primary?.isBanner == true ? 36 : size.height * 0.42)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(model.isExpanded ? 0.5 : 0), radius: 20, y: 8)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(IslandShape(bottomRadius: model.isExpanded || model.primary?.isBanner == true ? 36 : size.height * 0.42))
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
    }

    @ViewBuilder
    private var content: some View {
        let notch = model.notch
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
            case (nil, _): EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.25).delay(0.08)),
            removal: .opacity.animation(.easeIn(duration: 0.12))
        ))
        .id(contentID)
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
        .padding(.horizontal, 6)
        .frame(height: notch.height)
    }
}
