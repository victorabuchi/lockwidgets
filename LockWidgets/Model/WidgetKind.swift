import SwiftUI

/// Footprint of a widget on the lock screen, in screen points.
enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, wide, ultraWide, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .wide: "Wide"
        case .ultraWide: "Ultra Wide"
        case .large: "Large"
        }
    }

    var points: CGSize {
        switch self {
        case .small: CGSize(width: 164, height: 164)
        case .medium: CGSize(width: 344, height: 164)
        case .wide: CGSize(width: 524, height: 164)
        case .ultraWide: CGSize(width: 704, height: 164)
        case .large: CGSize(width: 344, height: 344)
        }
    }
}

/// One look a widget can take, offered in the sizes it supports.
struct WidgetStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let sizes: [WidgetSize]
}

enum WidgetCategory: String, CaseIterable {
    case essentials = "Essentials"
    case music = "Music"
    case productivity = "Productivity"
    case information = "Information"
}

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case weather
    case nowPlaying
    case lyrics
    case calendar
    case clock
    case battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weather: "Weather"
        case .nowPlaying: "Now Playing"
        case .lyrics: "Live Lyrics"
        case .calendar: "Calendar"
        case .clock: "Clock"
        case .battery: "Battery"
        }
    }

    var symbol: String {
        switch self {
        case .weather: "cloud.sun"
        case .nowPlaying: "music.note"
        case .lyrics: "quote.bubble"
        case .calendar: "calendar"
        case .clock: "clock"
        case .battery: "battery.75"
        }
    }

    var color: Color {
        switch self {
        case .weather: .cyan
        case .nowPlaying: .pink
        case .lyrics: .purple
        case .calendar: .red
        case .clock: .orange
        case .battery: .green
        }
    }

    var summary: String {
        switch self {
        case .weather: "Current conditions and the forecast ahead."
        case .nowPlaying: "The song playing in Apple Music or Spotify."
        case .lyrics: "Time-synced lyrics that follow the song."
        case .calendar: "Today's date, your month and what's next."
        case .clock: "Digital, analog and world clocks."
        case .battery: "Charge level and time remaining."
        }
    }

    var category: WidgetCategory {
        switch self {
        case .clock, .weather, .calendar, .battery: .essentials
        case .nowPlaying, .lyrics: .music
        }
    }

    var styles: [WidgetStyle] {
        switch self {
        case .clock: [
            WidgetStyle(id: "digital", name: "Digital", summary: "The time in large type, with the date.", sizes: [.small, .medium, .wide]),
            WidgetStyle(id: "analog", name: "Analog", summary: "A classic clock face.", sizes: [.small, .medium]),
            WidgetStyle(id: "world", name: "World Clock", summary: "The time in the cities you care about.", sizes: [.medium, .wide, .ultraWide]),
        ]
        case .weather: [
            WidgetStyle(id: "current", name: "Current", summary: "Conditions right now.", sizes: [.small, .medium]),
            WidgetStyle(id: "hourly", name: "Hourly", summary: "Now and the next few hours.", sizes: [.medium, .wide, .ultraWide]),
            WidgetStyle(id: "daily", name: "Five Day", summary: "The week ahead at a glance.", sizes: [.wide, .large]),
        ]
        case .calendar: [
            WidgetStyle(id: "date", name: "Date", summary: "Today's date, big and bold.", sizes: [.small, .medium]),
            WidgetStyle(id: "monthly", name: "Monthly", summary: "The full month with today highlighted.", sizes: [.small, .medium, .large]),
            WidgetStyle(id: "upNext", name: "Up Next", summary: "Your next events with times and colours.", sizes: [.small, .medium, .wide, .large]),
        ]
        case .nowPlaying: [
            WidgetStyle(id: "player", name: "Player", summary: "Artwork, song and progress.", sizes: [.medium, .wide]),
            WidgetStyle(id: "artwork", name: "Artwork", summary: "Album art front and centre.", sizes: [.small, .large]),
        ]
        case .lyrics: [
            WidgetStyle(id: "lyrics", name: "Lyrics", summary: "Follow along line by line.", sizes: [.medium, .wide, .large]),
        ]
        case .battery: [
            WidgetStyle(id: "ring", name: "Ring", summary: "A charge ring with the percentage.", sizes: [.small]),
            WidgetStyle(id: "bar", name: "Bar", summary: "Charge, status and time remaining.", sizes: [.medium, .wide]),
        ]
        }
    }

    var defaultStyle: WidgetStyle { styles[0] }

    func style(_ id: String) -> WidgetStyle {
        styles.first { $0.id == id } ?? defaultStyle
    }

    /// An unplaced instance used for previews.
    func sample(style: String? = nil, size: WidgetSize? = nil) -> WidgetInstance {
        let style = self.style(style ?? defaultStyle.id)
        return WidgetInstance(kind: self, style: style.id, size: size ?? style.sizes[0], center: .zero)
    }
}
