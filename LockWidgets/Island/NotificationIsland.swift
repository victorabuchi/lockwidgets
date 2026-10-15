import SwiftUI

/// A notification dropping down from the island: app icon, title and message, like the iPhone's banner.
struct NotificationBanner: View {
    let notch: CGSize
    let item: NotificationStore.Item

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(item.title.isEmpty ? item.appName : item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Text("now")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Text([item.subtitle, item.body].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, notch.height + 6)
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
