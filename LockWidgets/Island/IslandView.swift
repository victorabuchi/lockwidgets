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

    var body: some View {
        let size = model.size
        ZStack(alignment: .top) {
            IslandShape(bottomRadius: model.isExpanded ? 34 : size.height * 0.42)
                .fill(Color.black)
                .frame(width: size.width, height: size.height)
                .shadow(color: .black.opacity(model.isExpanded ? 0.45 : 0), radius: 16, y: 6)
            content
                .frame(width: size.width, height: size.height, alignment: .top)
                .clipShape(IslandShape(bottomRadius: model.isExpanded ? 34 : size.height * 0.42))
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.isExpanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.primary)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: model.isHovering)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var content: some View {
        switch model.primary {
        case .music:
            if model.isExpanded {
                MusicExpanded(notch: model.notch)
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            } else {
                MusicCompact(notch: model.notch)
                    .transition(.opacity)
            }
        case nil:
            EmptyView()
        }
    }
}

/// Left and right of the notch, the way the iPhone island splits around the camera.
struct CompactSlots<Leading: View, Trailing: View>: View {
    let notch: CGSize
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: IslandModel.compactSide, alignment: .center)
            Spacer(minLength: notch.width)
            trailing
                .frame(width: IslandModel.compactSide, alignment: .center)
        }
        .padding(.horizontal, 6)
        .frame(height: notch.height)
    }
}
