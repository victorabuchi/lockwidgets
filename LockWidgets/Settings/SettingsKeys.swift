import SwiftUI

enum SettingsKey {
    static let showOnLockScreen = "showOnLockScreen"
    static let scale = "boardScale"
    static let cardStyle = "cardStyle"
    static let cornerRadius = "cardCornerRadius"
    static let use24Hour = "clockUse24Hour"
    static let showSeconds = "clockShowSeconds"
    static let worldClockZones = "clockWorldZones"
    static let weatherCity = "weatherCity"
    static let fahrenheit = "weatherFahrenheit"
    static let hideMusicWhenIdle = "musicHideWhenIdle"
    static let lyricsUpcomingLines = "lyricsUpcomingLines"
    static let calendarMaxEvents = "calendarMaxEvents"
    static let calendarIncludeTomorrow = "calendarIncludeTomorrow"
    static let studioBackground = "studioBackground"
    static let hasLaunched = "hasLaunched"
    static let islandEnabled = "islandEnabled"
    static let islandMusic = "islandMusic"
    static let islandLyrics = "islandLyrics"

    /// Follows the region (°F in the US) until the user picks a unit.
    static var defaultFahrenheit: Bool { Locale.current.measurementSystem == .us }
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
