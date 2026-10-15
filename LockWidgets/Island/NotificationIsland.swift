import SwiftUI

/// A notification dropping down from the island: app icon, title and message, like the iPhone's banner.
struct NotificationBanner: View {
    let notch: CGSize
    let item: NotificationStore.Item

    var body: some View {
        BannerLayout(notch: notch) {
            icon
        } corner: {
            Text("now")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        } text: {
            Text(item.title.isEmpty ? item.appName : item.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
            Text([item.subtitle, item.body].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 13))
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

/// Banner arrangement that uses the band beside the camera: the icon sits in the top-left corner and a
/// small detail in the top-right, with the text column starting right under the notch, as on the iPhone.
struct BannerLayout<Icon: View, Corner: View, Content: View>: View {
    let notch: CGSize
    @ViewBuilder var icon: Icon
    @ViewBuilder var corner: Corner
    @ViewBuilder var text: Content

    static var iconSize: CGFloat { 40 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            icon
                .frame(width: Self.iconSize, height: Self.iconSize)
                .padding(.leading, 16)
                .padding(.top, 9)
            corner
                .frame(maxWidth: .infinity, alignment: .trailing)
                .frame(height: notch.height)
                .padding(.trailing, 20)
            VStack(alignment: .leading, spacing: 1) {
                text
            }
            .foregroundStyle(.white)
            .padding(.leading, 16 + Self.iconSize + 12)
            .padding(.trailing, 20)
            .padding(.top, notch.height - 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
