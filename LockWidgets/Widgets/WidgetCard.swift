import SwiftUI

enum Theme {
    static let cornerRadius = 24.0
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.38)
    static let accent = Color(red: 1, green: 0.36, blue: 0.33)
}

private struct WidgetPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True inside settings previews, where widgets show a placeholder instead of hiding.
    var isWidgetPreview: Bool {
        get { self[WidgetPreviewKey.self] }
        set { self[WidgetPreviewKey.self] = newValue }
    }
}

/// The card every widget sits in: fixed to its size, with an optional small header.
struct WidgetCard<Content: View>: View {
    let size: WidgetSize
    var title: String?
    var symbol: String?
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    @AppStorage(SettingsKey.cardStyle) private var style = CardStyle.glass
    @AppStorage(SettingsKey.cornerRadius) private var cornerRadius = Theme.cornerRadius

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Label(title.uppercased(), systemImage: symbol ?? "circle")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.secondary)
                    .lineLimit(1)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(padding)
        .frame(width: size.points.width, height: size.points.height)
        .background { background }
        .clipShape(RoundedRectangle(cornerRadius: style == .minimal ? 0 : cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(style == .minimal ? 0.55 : 0), radius: 6, y: 1)
        .foregroundStyle(Theme.primary)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private var background: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch style {
        case .glass:
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(Color.black.opacity(0.18)))
                .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        case .frosted:
            shape.fill(.regularMaterial)
                .overlay(shape.fill(Color.black.opacity(0.4)))
                .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        case .solid:
            shape.fill(Color(white: 0.11).opacity(0.94))
                .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        case .minimal:
            Color.clear
        }
    }
}

/// Message for widgets with nothing to show yet.
struct WidgetPlaceholder: View {
    let symbol: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20))
                .foregroundStyle(Theme.tertiary)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Small uppercase label used inside widgets.
struct Caption: View {
    let text: String
    var color: Color = Theme.secondary

    init(_ text: String, color: Color = Theme.secondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

struct ProgressBar: View {
    let fraction: Double
    var color: Color = .white
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.14))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

/// Shows a widget scaled down to fit a box, for previews and pickers.
struct FittedWidget: View {
    let instance: WidgetInstance
    let box: CGSize

    var body: some View {
        let size = instance.size.points
        let factor = min(1, box.width / size.width, box.height / size.height)
        WidgetView(instance: instance)
            .environment(\.isWidgetPreview, true)
            .scaleEffect(factor)
            .frame(width: size.width * factor, height: size.height * factor)
            .allowsHitTesting(false)
    }
}
