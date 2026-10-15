import SwiftUI

/// Full-screen layer that stacks the enabled widgets in the chosen corner.
struct WidgetBoard: View {
    @AppStorage(SettingsKey.widgetOrder) private var order = WidgetKind.defaultOrder
    @AppStorage(SettingsKey.hiddenWidgets) private var hidden = ""
    @AppStorage(SettingsKey.position) private var position = BoardPosition.leading
    @AppStorage(SettingsKey.scale) private var scale = 1.0
    @AppStorage(SettingsKey.spacing) private var spacing = Theme.spacing

    var body: some View {
        VStack(alignment: position.horizontalAlignment, spacing: spacing) {
            ForEach(WidgetKind.visible(order: order, hidden: hidden)) { kind in
                Self.widget(for: kind)
            }
        }
        .scaleEffect(scale, anchor: position.anchor)
        .padding(.horizontal, 56)
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    }

    @ViewBuilder
    static func widget(for kind: WidgetKind) -> some View {
        switch kind {
        case .clock: ClockWidget()
        case .weather: WeatherWidget()
        case .calendar: CalendarWidget()
        case .nowPlaying: NowPlayingWidget()
        case .lyrics: LyricsWidget()
        case .battery: BatteryWidget()
        }
    }
}
