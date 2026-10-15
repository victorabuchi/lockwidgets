import SwiftUI

enum SettingsKey {
    static let widgetOrder = "widgetOrder"
    static let hiddenWidgets = "hiddenWidgets"
    static let position = "boardPosition"
    static let scale = "boardScale"
    static let use24Hour = "clockUse24Hour"
    static let showSeconds = "clockShowSeconds"
}

enum WidgetKind: String, CaseIterable, Identifiable {
    case clock
    case battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clock: "Clock"
        case .battery: "Battery"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock"
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
