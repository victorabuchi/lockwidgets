import SwiftUI

/// A notification opening out from the notch. Its header sits either side of the camera, the app's icon
/// and name on the left and the time on the right, and the title and message run full width below.
struct NotificationBanner: View {
    let notch: CGSize
    let item: NotificationStore.Item

    var body: some View {
        CardLayout(notch: notch) {
            icon
                .frame(width: 20, height: 20)
            Text(item.appName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        } right: {
            Text("now")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
        } below: {
            Text(item.title.isEmpty ? item.appName : item.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(height: 16)
                .padding(.top, 4)
            Text([item.subtitle, item.body].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
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
