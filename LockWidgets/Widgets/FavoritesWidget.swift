import AppKit
import SwiftUI

/// Favourite Apps: icons for the apps you pick. Over your desktop, click one to open it.
struct FavoritesWidget: View {
    let instance: WidgetInstance
    @AppStorage(SettingsKey.favoriteApps) private var stored = ""

    var body: some View {
        WidgetCard(size: instance.size, padding: 0) {
            let apps = FavoriteApps.list(stored)
            let cells = FavoriteApps.cells(for: instance.size)
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(apps, cells).enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 5) {
                        Image(nsImage: AppInfo.icon(pair.0))
                            .resizable()
                            .frame(width: FavoriteApps.iconSize, height: FavoriteApps.iconSize)
                        Text(AppInfo.name(pair.0))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                            .frame(width: pair.1.width - 4)
                    }
                    .position(x: pair.1.midX, y: pair.1.midY)
                }
            }
            .frame(width: instance.size.points.width, height: instance.size.points.height, alignment: .topLeading)
        }
    }
}

/// The favourite apps and where each sits in the widget, shared with the layer that makes them clickable.
enum FavoriteApps {
    static let iconSize: CGFloat = 46

    static let defaults = [
        "com.apple.Safari", "com.apple.mail", "com.apple.Music", "com.apple.iCal",
        "com.apple.Notes", "com.apple.MobileSMS", "com.apple.Photos", "com.apple.Maps",
        "com.apple.reminders", "com.apple.finder", "com.apple.AppStore", "com.apple.systempreferences",
    ]

    /// Installed apps from the saved list, or a starting set before you've chosen any.
    static func list(_ stored: String) -> [String] {
        let chosen = stored.isEmpty ? defaults : stored.split(separator: ",").map(String.init)
        return chosen.filter { AppInfo.url($0) != nil }
    }

    static func save(_ apps: [String]) {
        UserDefaults.standard.set(apps.joined(separator: ","), forKey: SettingsKey.favoriteApps)
    }

    static func columns(for size: WidgetSize) -> Int {
        switch size {
        case .small: 2
        case .medium, .large: 4
        case .wide: 6
        case .ultraWide: 8
        }
    }

    static func rows(for size: WidgetSize) -> Int { size == .large ? 4 : 2 }

    /// Each app's square inside the widget, left to right and top to bottom.
    static func cells(for size: WidgetSize) -> [CGRect] {
        let inset: CGFloat = 12
        let area = CGRect(origin: .zero, size: size.points).insetBy(dx: inset, dy: inset)
        let columns = columns(for: size), rows = rows(for: size)
        let width = area.width / CGFloat(columns), height = area.height / CGFloat(rows)
        return (0 ..< rows).flatMap { row in
            (0 ..< columns).map { column in
                CGRect(x: area.minX + CGFloat(column) * width, y: area.minY + CGFloat(row) * height, width: width, height: height)
            }
        }
    }

    static func open(_ bundleID: String) {
        guard let url = AppInfo.url(bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

/// While the widgets show on the desktop, the widget layer lets clicks through so the Mac stays usable.
/// A clear panel sits under each Favourite Apps widget instead and opens the app you click.
final class FavoritesClickLayer {
    private var panels: [NSPanel] = []

    func show() {
        hide()
        let scale = UserDefaults.standard.object(forKey: SettingsKey.scale) as? Double ?? 1
        let stored = UserDefaults.standard.string(forKey: SettingsKey.favoriteApps) ?? ""
        for screen in NSScreen.screens {
            for instance in LayoutStore.shared.instances where instance.kind == .favorites {
                let size = CGSize(width: instance.size.points.width * scale, height: instance.size.points.height * scale)
                let frame = NSRect(
                    x: screen.frame.minX + instance.center.x * screen.frame.width - size.width / 2,
                    y: screen.frame.maxY - instance.center.y * screen.frame.height - size.height / 2,
                    width: size.width,
                    height: size.height
                )
                let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.level = .statusBar
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                panel.contentView = ClickThroughHostingView(rootView: FavoritesHitView(apps: FavoriteApps.list(stored), size: instance.size, scale: scale))
                panel.orderFrontRegardless()
                panels.append(panel)
            }
        }
    }

    func hide() {
        panels.forEach { $0.close() }
        panels.removeAll()
    }
}

/// Click targets matching the icons in the widget.
private struct FavoritesHitView: View {
    let apps: [String]
    let size: WidgetSize
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(zip(apps, FavoriteApps.cells(for: size)).enumerated()), id: \.offset) { _, pair in
                // Almost clear, since fully clear pixels of a window let clicks through.
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: pair.1.width * scale, height: pair.1.height * scale)
                    .contentShape(Rectangle())
                    .onTapGesture { FavoriteApps.open(pair.0) }
                    .help(AppInfo.name(pair.0))
                    .position(x: pair.1.midX * scale, y: pair.1.midY * scale)
            }
        }
        .frame(width: size.points.width * scale, height: size.points.height * scale, alignment: .topLeading)
    }
}

/// Takes the first click without activating Notchlight first.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}
