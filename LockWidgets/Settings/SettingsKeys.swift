import SwiftUI

enum SettingsKey {
    static let showOnLockScreen = "showOnLockScreen"
    static let widgetOrder = "widgetOrder"
    static let hiddenWidgets = "hiddenWidgets"
    static let position = "boardPosition"
    static let scale = "boardScale"
    static let cardStyle = "cardStyle"
    static let cornerRadius = "cardCornerRadius"
    static let spacing = "boardSpacing"
    static let use24Hour = "clockUse24Hour"
    static let showSeconds = "clockShowSeconds"
    static let weatherCity = "weatherCity"
    static let fahrenheit = "weatherFahrenheit"
    static let hideMusicWhenIdle = "musicHideWhenIdle"
    static let lyricsUpcomingLines = "lyricsUpcomingLines"

    /// Follows the region (°F in the US) until the user picks a unit.
    static var defaultFahrenheit: Bool { Locale.current.measurementSystem == .us }
}

enum WidgetKind: String, CaseIterable, Identifiable {
    case clock
    case weather
    case calendar
    case nowPlaying
    case lyrics
    case battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: "Clock"
        case .weather: "Weather"
        case .calendar: "Up Next"
        case .nowPlaying: "Now Playing"
        case .lyrics: "Live Lyrics"
        case .battery: "Battery"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
        case .weather: "cloud.sun"
        case .calendar: "calendar"
        case .nowPlaying: "music.note"
        case .lyrics: "quote.bubble"
        case .battery: "battery.75"
        }
    }

    static var defaultOrder: String { allCases.map(\.rawValue).joined(separator: ",") }

    /// Stored order, with unknown entries dropped and newly added kinds appended.
    static func ordered(_ order: String) -> [WidgetKind] {
        var kinds = order.split(separator: ",").compactMap { WidgetKind(rawValue: String($0)) }
        kinds += allCases.filter { !kinds.contains($0) }
        return kinds
    }

    static func visible(order: String, hidden: String) -> [WidgetKind] {
        let hiddenSet = Set(hidden.split(separator: ",").map(String.init))
        return ordered(order).filter { !hiddenSet.contains($0.rawValue) }
    }
}

enum CardStyle: String, CaseIterable, Identifiable {
    case glass, frosted, solid, minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: "Glass"
        case .frosted: "Frosted"
        case .solid: "Solid"
        case .minimal: "Minimal"
        }
    }

    var detail: String {
        switch self {
        case .glass: "See-through blur that picks up your wallpaper."
        case .frosted: "Heavier blur with a darker tint for busy wallpapers."
        case .solid: "Opaque dark cards."
        case .minimal: "No card at all, just text with a soft shadow."
        }
    }
}

enum BoardPosition: String, CaseIterable, Identifiable {
    case topLeading, leading, bottomLeading, topTrailing, trailing, bottomTrailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeading: "Top left"
        case .leading: "Left"
        case .bottomLeading: "Bottom left"
        case .topTrailing: "Top right"
        case .trailing: "Right"
        case .bottomTrailing: "Bottom right"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .leading: .leading
        case .bottomLeading: .bottomLeading
        case .topTrailing: .topTrailing
        case .trailing: .trailing
        case .bottomTrailing: .bottomTrailing
        }
    }

    var anchor: UnitPoint {
        switch self {
        case .topLeading: .topLeading
        case .leading: .leading
        case .bottomLeading: .bottomLeading
        case .topTrailing: .topTrailing
        case .trailing: .trailing
        case .bottomTrailing: .bottomTrailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .topLeading, .leading, .bottomLeading: .leading
        case .topTrailing, .trailing, .bottomTrailing: .trailing
        }
    }
}
