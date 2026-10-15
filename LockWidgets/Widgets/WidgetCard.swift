import SwiftUI

enum Theme {
    static let cardWidth: CGFloat = 280
    static let cardPadding: CGFloat = 18
    static let cornerRadius: CGFloat = 24
    static let spacing: CGFloat = 14
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
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .foregroundStyle(Theme.primary)
        .environment(\.colorScheme, .dark)
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
