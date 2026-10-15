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

/// Everything that describes a widget kind, kept together so adding one is a single edit.
struct WidgetMeta {
    let title: String
    let symbol: String
    let color: Color
    let summary: String
    let category: WidgetCategory
    let styles: [WidgetStyle]
}

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    // Sidebar order.
    case weather, nowPlaying, lyrics, calendar, clock, countdown, pomodoro, stopwatch, reminders, battery, stickyNote

    var id: String { rawValue }
    var title: String { meta.title }
    var symbol: String { meta.symbol }
    var color: Color { meta.color }
    var summary: String { meta.summary }
    var category: WidgetCategory { meta.category }
    var styles: [WidgetStyle] { meta.styles }

    var meta: WidgetMeta {
        switch self {
        case .weather: WidgetMeta(
            title: "Weather", symbol: "cloud.sun", color: .cyan,
            summary: "Current conditions and the forecast ahead.", category: .essentials,
            styles: [
                WidgetStyle(id: "current", name: "Current", summary: "Conditions right now.", sizes: [.small, .medium]),
                WidgetStyle(id: "hourly", name: "Hourly", summary: "Now and the next few hours.", sizes: [.medium, .wide, .ultraWide]),
                WidgetStyle(id: "daily", name: "Five Day", summary: "The week ahead at a glance.", sizes: [.wide, .large]),
            ]
        )
        case .nowPlaying: WidgetMeta(
            title: "Now Playing", symbol: "music.note", color: .pink,
            summary: "The song playing in Apple Music or Spotify.", category: .music,
            styles: [
                WidgetStyle(id: "player", name: "Player", summary: "Artwork, song and progress.", sizes: [.medium, .wide]),
                WidgetStyle(id: "artwork", name: "Artwork", summary: "Album art front and centre.", sizes: [.small, .large]),
            ]
        )
        case .lyrics: WidgetMeta(
            title: "Live Lyrics", symbol: "quote.bubble", color: .purple,
            summary: "Time-synced lyrics that follow the song.", category: .music,
            styles: [
                WidgetStyle(id: "lyrics", name: "Lyrics", summary: "Follow along line by line.", sizes: [.medium, .wide, .large]),
            ]
        )
        case .calendar: WidgetMeta(
            title: "Calendar", symbol: "calendar", color: .red,
            summary: "Today's date, your month and what's next.", category: .essentials,
            styles: [
                WidgetStyle(id: "date", name: "Date", summary: "Today's date, big and bold.", sizes: [.small, .medium]),
                WidgetStyle(id: "monthly", name: "Monthly", summary: "The full month with today highlighted.", sizes: [.small, .medium, .large]),
                WidgetStyle(id: "upNext", name: "Up Next", summary: "Your next events with times and colours.", sizes: [.small, .medium, .wide, .large]),
            ]
        )
        case .clock: WidgetMeta(
            title: "Clock", symbol: "clock", color: .orange,
            summary: "Digital, analog and world clocks.", category: .essentials,
            styles: [
                WidgetStyle(id: "digital", name: "Digital", summary: "The time in large type, with the date.", sizes: [.small, .medium, .wide]),
                WidgetStyle(id: "analog", name: "Analog", summary: "A classic clock face.", sizes: [.small, .medium]),
                WidgetStyle(id: "world", name: "World Clock", summary: "The time in the cities you care about.", sizes: [.medium, .wide, .ultraWide]),
            ]
        )
        case .countdown: WidgetMeta(
            title: "Countdown", symbol: "hourglass", color: Color(red: 0.95, green: 0.4, blue: 0.35),
            summary: "Days, hours and minutes until something you're waiting for.", category: .productivity,
            styles: [
                WidgetStyle(id: "days", name: "Days", summary: "A big day count.", sizes: [.small, .medium]),
                WidgetStyle(id: "units", name: "Flip", summary: "Days, hours, minutes and seconds.", sizes: [.medium, .wide]),
            ]
        )
        case .pomodoro: WidgetMeta(
            title: "Pomodoro", symbol: "timer", color: Color(red: 0.98, green: 0.45, blue: 0.3),
            summary: "Focus sessions with breaks in between.", category: .productivity,
            styles: [
                WidgetStyle(id: "ring", name: "Ring", summary: "Time left in the current session.", sizes: [.small, .medium]),
            ]
        )
        case .stopwatch: WidgetMeta(
            title: "Stopwatch", symbol: "stopwatch", color: .teal,
            summary: "Time anything. Start and stop it from the menu bar.", category: .productivity,
            styles: [
                WidgetStyle(id: "digits", name: "Digits", summary: "Elapsed time in large type.", sizes: [.small, .medium]),
            ]
        )
        case .reminders: WidgetMeta(
            title: "Reminders", symbol: "checklist", color: .blue,
            summary: "Your open reminders, soonest first.", category: .productivity,
            styles: [
                WidgetStyle(id: "list", name: "List", summary: "What's left to do.", sizes: [.small, .medium, .large]),
            ]
        )
        case .battery: WidgetMeta(
            title: "Battery", symbol: "battery.75", color: .green,
            summary: "Charge level and time remaining.", category: .essentials,
            styles: [
                WidgetStyle(id: "ring", name: "Ring", summary: "A charge ring with the percentage.", sizes: [.small]),
                WidgetStyle(id: "bar", name: "Bar", summary: "Charge, status and time remaining.", sizes: [.medium, .wide]),
            ]
        )
        case .stickyNote: WidgetMeta(
            title: "Sticky Note", symbol: "note.text", color: .yellow,
            summary: "A note to yourself, right on the lock screen.", category: .productivity,
            styles: [
                WidgetStyle(id: "paper", name: "Paper", summary: "A coloured note.", sizes: [.small, .medium, .large]),
                WidgetStyle(id: "glass", name: "Glass", summary: "Matches your other widgets.", sizes: [.small, .medium, .large]),
            ]
        )
        }
    }

    /// Kinds listed under Widget Settings; sticky notes have their own page.
    static var settingsKinds: [WidgetKind] { allCases.filter { $0 != .stickyNote } }

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
