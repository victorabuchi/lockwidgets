import SwiftUI

enum Theme {
    static let cardWidth: CGFloat = 280
    static let cardPadding: CGFloat = 18
    static let cornerRadius = 24.0
    static let spacing = 14.0
    static let primary = Color.white
    static let secondary = Color.white.opacity(0.62)
    static let tertiary = Color.white.opacity(0.38)
}

/// Glass card shared by every widget: small uppercase header, then content.
struct WidgetCard<Content: View>: View {
    let title: String
    let symbol: String
    var showsHeader = true
    @ViewBuilder var content: Content

    @AppStorage(SettingsKey.cardStyle) private var style = CardStyle.glass
    @AppStorage(SettingsKey.cornerRadius) private var cornerRadius = Theme.cornerRadius

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                Label(title.uppercased(), systemImage: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.secondary)
            }
            content
        }
        .frame(width: Theme.cardWidth, alignment: .leading)
        .padding(Theme.cardPadding)
        .background { background }
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

/// Centred message for widgets with nothing to show yet.
struct WidgetPlaceholder: View {
    let symbol: String
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(Theme.tertiary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
