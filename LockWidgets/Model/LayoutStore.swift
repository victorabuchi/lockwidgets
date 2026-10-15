import AppKit
import SwiftUI

/// A widget placed on the lock screen.
struct WidgetInstance: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: WidgetKind
    var style: String
    var size: WidgetSize
    /// Centre of the widget as a fraction of the screen, so layouts carry across displays.
    var center: CGPoint
    /// Per-widget settings, such as a sticky note's text.
    var config: [String: String] = [:]
}

/// Reference screen used to convert between points and the stored fractions.
enum ScreenGeometry {
    static var size: CGSize {
        NSScreen.main?.frame.size ?? CGSize(width: 1512, height: 982)
    }

    /// Areas the system uses on the lock screen: the large clock and the login controls.
    static let reservedZones = [
        CGRect(x: 0.33, y: 0.0, width: 0.34, height: 0.3),
        CGRect(x: 0.4, y: 0.76, width: 0.2, height: 0.24),
    ]
}

final class LayoutStore: ObservableObject {
    static let shared = LayoutStore()

    @Published private(set) var instances: [WidgetInstance]

    private static let key = "layout.v2"
    static let edgePadding: CGFloat = 24

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([WidgetInstance].self, from: data)
        {
            instances = saved
        } else {
            instances = LayoutPreset.starter.instances
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(instances) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    // MARK: Editing

    @discardableResult
    func add(_ kind: WidgetKind, style: String, size: WidgetSize) -> UUID {
        var instance = WidgetInstance(kind: kind, style: style, size: size, center: .zero)
        instance.center = freeSpot(for: instance)
        instances.append(instance)
        // Ask for access the moment a widget needs it, while the user is looking.
        switch kind {
        case .calendar, .dailyBrief: CalendarStore.shared.requestAccess()
        case .reminders: RemindersStore.shared.requestAccess()
        case .photos: if !PhotosStore.shared.libraryAccess { PhotosStore.shared.requestAccess() }
        default: break
        }
        save()
        return instance.id
    }

    func remove(_ id: UUID) {
        instances.removeAll { $0.id == id }
        save()
    }

    func removeAll() {
        instances = []
        save()
    }

    func update(_ id: UUID, _ change: (inout WidgetInstance) -> Void) {
        guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
        change(&instances[index])
        instances[index].center = clamped(instances[index].center, for: instances[index])
        save()
    }

    func move(_ id: UUID, by fraction: CGSize) {
        update(id) { $0.center = CGPoint(x: $0.center.x + fraction.width, y: $0.center.y + fraction.height) }
    }

    func apply(_ preset: LayoutPreset) {
        instances = preset.instances.map { instance in
            var copy = instance
            copy.id = UUID()
            return copy
        }
        save()
    }

    // MARK: Geometry

    /// The widget's frame as fractions of the screen.
    static func frame(of instance: WidgetInstance, center: CGPoint? = nil) -> CGRect {
        let screen = ScreenGeometry.size
        let scale = UserDefaults.standard.object(forKey: SettingsKey.scale) as? Double ?? 1
        let width = instance.size.points.width * scale / screen.width
        let height = instance.size.points.height * scale / screen.height
        let center = center ?? instance.center
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    static func overlapsSystemUI(_ instance: WidgetInstance, center: CGPoint? = nil) -> Bool {
        let frame = frame(of: instance, center: center)
        return ScreenGeometry.reservedZones.contains { $0.intersects(frame) }
    }

    private func clamped(_ center: CGPoint, for instance: WidgetInstance) -> CGPoint {
        let frame = Self.frame(of: instance, center: center)
        let screen = ScreenGeometry.size
        let padX = Self.edgePadding / screen.width
        let padY = Self.edgePadding / screen.height
        let halfW = frame.width / 2
        let halfH = frame.height / 2
        return CGPoint(
            x: min(max(center.x, halfW + padX), 1 - halfW - padX),
            y: min(max(center.y, halfH + padY), 1 - halfH - padY)
        )
    }

    /// First spot, scanning down the left then the right edge, that clears other widgets and system UI.
    private func freeSpot(for instance: WidgetInstance) -> CGPoint {
        let screen = ScreenGeometry.size
        let frame = Self.frame(of: instance)
        let stepY = 16 / screen.height
        let leftX = frame.width / 2 + 56 / screen.width
        let columns = [leftX, 1 - leftX]
        for x in columns {
            var y = frame.height / 2 + 64 / screen.height
            while y + frame.height / 2 < 1 - 24 / screen.height {
                let candidate = CGPoint(x: x, y: y)
                let rect = Self.frame(of: instance, center: candidate).insetBy(dx: -0.005, dy: -0.008)
                let clear = !instances.contains { Self.frame(of: $0).intersects(rect) }
                    && !Self.overlapsSystemUI(instance, center: candidate)
                if clear { return candidate }
                y += stepY
            }
        }
        return CGPoint(x: 0.5, y: 0.5)
    }
}

/// A ready-made layout from the gallery.
struct LayoutPreset: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let colors: [Color]
    let instances: [WidgetInstance]

    /// Places a widget by its top-left corner in points on a 1512×982 reference screen.
    static func place(_ kind: WidgetKind, _ style: String, _ size: WidgetSize, x: CGFloat, y: CGFloat) -> WidgetInstance {
        let reference = CGSize(width: 1512, height: 982)
        let points = size.points
        return WidgetInstance(
            kind: kind,
            style: style,
            size: size,
            center: CGPoint(x: (x + points.width / 2) / reference.width, y: (y + points.height / 2) / reference.height)
        )
    }

    static let starter = LayoutPreset(
        id: "starter",
        name: "Starter",
        tagline: "Clock, weather, calendar and music",
        colors: [Color(red: 0.36, green: 0.27, blue: 0.75), Color(red: 0.12, green: 0.1, blue: 0.38)],
        instances: [
            place(.clock, "digital", .medium, x: 56, y: 230),
            place(.weather, "hourly", .medium, x: 56, y: 410),
            place(.calendar, "upNext", .medium, x: 56, y: 590),
            place(.nowPlaying, "player", .medium, x: 1112, y: 410),
            place(.battery, "ring", .small, x: 1292, y: 590),
        ]
    )

    static let gallery: [LayoutPreset] = [
        LayoutPreset(
            id: "everyday", name: "Everyday", tagline: "A little of everything",
            colors: [Color(red: 0.05, green: 0.25, blue: 0.35), Color(red: 0.02, green: 0.08, blue: 0.15)],
            instances: [
                place(.weather, "hourly", .medium, x: 56, y: 250),
                place(.calendar, "upNext", .medium, x: 56, y: 430),
                place(.nowPlaying, "player", .medium, x: 1112, y: 250),
                place(.battery, "bar", .medium, x: 1112, y: 430),
            ]
        ),
        LayoutPreset(
            id: "afterHours", name: "After Hours", tagline: "Let the music take over",
            colors: [Color(red: 0.3, green: 0.08, blue: 0.35), Color(red: 0.05, green: 0.02, blue: 0.12)],
            instances: [
                place(.lyrics, "lyrics", .large, x: 1112, y: 280),
                place(.nowPlaying, "player", .wide, x: 494, y: 560),
                place(.clock, "analog", .small, x: 56, y: 280),
                place(.weather, "current", .small, x: 56, y: 460),
            ]
        ),
        LayoutPreset(
            id: "inTheZone", name: "In the Zone", tagline: "Find your focus",
            colors: [Color(red: 0.08, green: 0.3, blue: 0.2), Color(red: 0.02, green: 0.1, blue: 0.07)],
            instances: [
                place(.pomodoro, "ring", .medium, x: 56, y: 280),
                place(.stickyNote, "paper", .medium, x: 56, y: 460),
                place(.reminders, "list", .large, x: 1112, y: 280),
            ]
        ),
        LayoutPreset(
            id: "dayAhead", name: "Day Ahead", tagline: "Catch up. Look ahead.",
            colors: [Color(red: 0.6, green: 0.4, blue: 0.25), Color(red: 0.2, green: 0.12, blue: 0.08)],
            instances: [
                place(.dailyBrief, "brief", .large, x: 56, y: 280),
                place(.calendar, "monthly", .medium, x: 1112, y: 280),
                place(.weather, "daily", .wide, x: 932, y: 460),
            ]
        ),
        LayoutPreset(
            id: "missionControl", name: "Mission Control", tagline: "The bigger picture",
            colors: [Color(red: 0.08, green: 0.12, blue: 0.3), Color(red: 0.01, green: 0.02, blue: 0.08)],
            instances: [
                place(.stocks, "watchlist", .medium, x: 56, y: 250),
                place(.news, "headlines", .large, x: 56, y: 430),
                place(.system, "list", .large, x: 1112, y: 250),
                place(.earth, "globe", .small, x: 1292, y: 610),
            ]
        ),
        LayoutPreset(
            id: "traveller", name: "Traveller", tagline: "Time and weather wherever you are",
            colors: [Color(red: 0.1, green: 0.35, blue: 0.55), Color(red: 0.02, green: 0.1, blue: 0.2)],
            instances: [
                place(.weather, "daily", .large, x: 56, y: 250),
                place(.earth, "globe", .medium, x: 1112, y: 250),
                place(.clock, "world", .ultraWide, x: 404, y: 560),
            ]
        ),
        LayoutPreset(
            id: "minimal", name: "Minimal", tagline: "Just the essentials, out of the way",
            colors: [Color(white: 0.3), Color(white: 0.08)],
            instances: [
                place(.clock, "digital", .wide, x: 56, y: 760),
                place(.weather, "current", .small, x: 1292, y: 760),
            ]
        ),
    ]
}
