import AppKit
import SkyLightWindow
import SwiftUI
import UniformTypeIdentifiers

/// Favourite Apps: icons for the apps you pick, as a grid of your favourites or one or two apps of your choosing
/// that you can place anywhere. Click one on the lock screen and it opens as soon as you unlock, like the iPhone;
/// over your desktop it opens straight away.
struct FavoritesWidget: View {
    let instance: WidgetInstance
    @AppStorage(SettingsKey.favoriteApps) private var stored = ""

    var body: some View {
        WidgetCard(size: instance.size, padding: 0) {
            ZStack(alignment: .topLeading) {
                ForEach(Array(FavoriteApps.slots(for: instance, stored: stored).enumerated()), id: \.offset) { _, slot in
                    VStack(spacing: slot.iconSize > 60 ? 8 : 5) {
                        Image(nsImage: AppInfo.icon(slot.app))
                            .resizable()
                            .frame(width: slot.iconSize, height: slot.iconSize)
                        Text(AppInfo.name(slot.app))
                            .font(.system(size: slot.iconSize > 60 ? 13 : 10, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                            .lineLimit(1)
                            .frame(width: slot.rect.width - 4)
                    }
                    .position(x: slot.rect.midX, y: slot.rect.midY)
                }
            }
            .frame(width: instance.size.points.width, height: instance.size.points.height, alignment: .topLeading)
        }
    }
}

/// The favourite apps and where each sits in a widget, shared with the layer that makes them clickable.
enum FavoriteApps {
    static let iconSize: CGFloat = 46

    static let defaults = [
        "com.apple.Safari", "com.apple.mail", "com.apple.Music", "com.apple.iCal",
        "com.apple.Notes", "com.apple.MobileSMS", "com.apple.Photos", "com.apple.Maps",
        "com.apple.reminders", "com.apple.finder", "com.apple.AppStore", "com.apple.systempreferences",
    ]

    /// One app in a widget: which, where in the widget, and how big its icon is.
    struct Slot {
        let app: String
        let rect: CGRect
        let iconSize: CGFloat
    }

    /// Installed apps from the saved list, or a starting set before you've chosen any.
    static func list(_ stored: String) -> [String] {
        let chosen = stored.isEmpty ? defaults : stored.split(separator: ",").map(String.init)
        return chosen.filter { AppInfo.url($0) != nil }
    }

    static func save(_ apps: [String]) {
        UserDefaults.standard.set(apps.joined(separator: ","), forKey: SettingsKey.favoriteApps)
    }

    /// How many apps a style holds: One App and Two Apps hold their own; the grid shows your favourites.
    static func count(for style: String) -> Int? {
        switch style {
        case "single": 1
        case "pair": 2
        default: nil
        }
    }

    /// The apps a One App or Two Apps widget shows: the ones chosen for it, or your first favourites until you
    /// choose.
    static func apps(of instance: WidgetInstance, stored: String) -> [String] {
        guard let count = count(for: instance.style) else { return list(stored) }
        let chosen = (instance.config["apps"] ?? "").split(separator: ",").map(String.init).filter { AppInfo.url($0) != nil }
        return Array((chosen + list(stored).filter { !chosen.contains($0) }).prefix(count))
    }

    /// Each app's place in the widget, left to right and top to bottom.
    static func slots(for instance: WidgetInstance, stored: String) -> [Slot] {
        let area = CGRect(origin: .zero, size: instance.size.points)
        switch instance.style {
        case "single":
            return apps(of: instance, stored: stored).map { Slot(app: $0, rect: area, iconSize: 84) }
        case "pair":
            let inner = area.insetBy(dx: 8, dy: 8)
            return apps(of: instance, stored: stored).enumerated().map { index, app in
                Slot(app: app, rect: CGRect(x: inner.minX + CGFloat(index) * inner.width / 2, y: inner.minY, width: inner.width / 2, height: inner.height), iconSize: 60)
            }
        default:
            return zip(list(stored), cells(for: instance.size)).map { Slot(app: $0, rect: $1, iconSize: iconSize) }
        }
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

    /// The grid's squares, left to right and top to bottom.
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

/// Lets you choose the app, or two apps, a One App or Two Apps widget opens. Shown under Layout Studio when one is
/// selected.
struct FavoriteAppPicker: View {
    let instance: WidgetInstance
    @AppStorage(SettingsKey.favoriteApps) private var stored = ""

    var body: some View {
        let apps = FavoriteApps.apps(of: instance, stored: stored)
        let count = FavoriteApps.count(for: instance.style) ?? 0
        ForEach(0 ..< count, id: \.self) { index in
            LabeledContent(count == 1 ? "App" : index == 0 ? "First app" : "Second app") {
                Button {
                    choose(at: index, in: apps)
                } label: {
                    if index < apps.count {
                        Label {
                            Text(AppInfo.name(apps[index]))
                        } icon: {
                            Image(nsImage: AppInfo.icon(apps[index])).resizable().frame(width: 18, height: 18)
                        }
                    } else {
                        Text("Choose…")
                    }
                }
                .help("Choose another app")
            }
        }
    }

    private func choose(at index: Int, in apps: [String]) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let app = panel.url.flatMap({ Bundle(url: $0)?.bundleIdentifier }) else { return }
        var chosen = apps
        if index < chosen.count { chosen[index] = app } else { chosen.append(app) }
        LayoutStore.shared.update(instance.id) { $0.config["apps"] = chosen.joined(separator: ",") }
    }
}

/// The widget layer lets clicks through, so the Mac stays usable over the desktop and the login works on the lock
/// screen. A clear panel over each Favourite Apps widget takes its clicks instead, in the same top layer as the
/// widgets so it is never under them. Over the desktop a click opens the app; on the lock screen it marks the app
/// and opens it as soon as you unlock, like the iPhone.
final class FavoritesClickLayer {
    private var panels: [NSPanel] = []
    private let taps = FavoriteTaps()

    func show(locked: Bool) {
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
                let panel = ClickPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isReleasedWhenClosed = false
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.canBecomeVisibleWithoutLogin = true
                panel.level = NSWindow.Level(rawValue: Int(Int32.max - 1))
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
                let slots = FavoriteApps.slots(for: instance, stored: stored)
                panel.contentView = ClickThroughHostingView(rootView: FavoritesHitView(slots: slots, size: instance.size, scale: scale, locked: locked, taps: taps) { [weak self] app in
                    self?.tapped(app, locked: locked)
                })
                panel.orderFrontRegardless()
                SkyLightOperator.shared.delegateWindow(panel)
                panels.append(panel)
            }
        }
    }

    func hide() {
        panels.forEach { $0.close() }
        panels.removeAll()
    }

    /// Opens the app tapped on the lock screen. Called once you've unlocked.
    func openWaitingApp() {
        guard let app = taps.waiting else { return }
        taps.waiting = nil
        FavoriteApps.open(app)
    }

    private func tapped(_ app: String, locked: Bool) {
        if locked {
            taps.waiting = taps.waiting == app ? nil : app
        } else {
            FavoriteApps.open(app)
        }
    }
}

/// The app waiting to open after you unlock, shared by every panel so only one is marked at a time.
private final class FavoriteTaps: ObservableObject {
    @Published var waiting: String?
}

/// Click targets matching the icons in the widget. On the lock screen the tapped app is ringed and says it will
/// open when you unlock; tapping it again cancels.
private struct FavoritesHitView: View {
    let slots: [FavoriteApps.Slot]
    let size: WidgetSize
    let scale: CGFloat
    let locked: Bool
    @ObservedObject var taps: FavoriteTaps
    let tap: (String) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                let waiting = locked && taps.waiting == slot.app
                ZStack(alignment: .bottom) {
                    // Almost clear, since fully clear pixels of a window let clicks through.
                    Rectangle()
                        .fill(Color.white.opacity(0.001))
                    if waiting {
                        RoundedRectangle(cornerRadius: slot.iconSize * 0.3 * scale, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 2.5 * scale)
                            .frame(width: (slot.iconSize + 10) * scale, height: (slot.iconSize + 10) * scale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(y: -9 * scale)
                        Text("Opens when you unlock")
                            .font(.system(size: 10 * scale, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8 * scale)
                            .padding(.vertical, 4 * scale)
                            .background(Color.black.opacity(0.6), in: Capsule())
                            .fixedSize()
                            .padding(.bottom, 2 * scale)
                    }
                }
                .frame(width: slot.rect.width * scale, height: slot.rect.height * scale)
                .contentShape(Rectangle())
                .onTapGesture { tap(slot.app) }
                .help(AppInfo.name(slot.app))
                .position(x: slot.rect.midX * scale, y: slot.rect.midY * scale)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: waiting)
            }
        }
        .frame(width: size.points.width * scale, height: size.points.height * scale, alignment: .topLeading)
    }
}

/// A panel that takes clicks but never keyboard focus, so on the lock screen typing still goes to the password.
private final class ClickPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Takes the first click without activating Notchlight first.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { true }
}
