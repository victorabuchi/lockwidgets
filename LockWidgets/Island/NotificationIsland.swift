import SwiftUI

/// A notification dropping down from the notch at the notch's width: the app icon beside the title and message.
struct NotificationBanner: View {
    let notch: CGSize
    let item: NotificationStore.Item

    var body: some View {
        BannerLayout(notch: notch) {
            icon
        } text: {
            Text(item.title.isEmpty ? item.appName : item.title)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(1)
            Text([item.subtitle, item.body].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: .init())
            }
            IslandModel.shared.dismissTransient()
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
        } else {
            Image(systemName: "app.badge.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// Banner arrangement below the notch, as wide as the notch: the icon beside the title and message,
/// both starting right under the camera so there is no empty band.
struct BannerLayout<Icon: View, Content: View>: View {
    let notch: CGSize
    @ViewBuilder var icon: Icon
    @ViewBuilder var text: Content

    static var iconSize: CGFloat { 30 }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            icon
                .frame(width: Self.iconSize, height: Self.iconSize)
            VStack(alignment: .leading, spacing: 1) {
                text
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, notch.height + 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
