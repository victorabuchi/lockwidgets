import SwiftUI

/// Renders any placed widget.
struct WidgetView: View {
    let instance: WidgetInstance

    var body: some View {
        switch instance.kind {
        case .clock: ClockWidget(instance: instance)
        case .weather: WeatherWidget(instance: instance)
        case .calendar: CalendarWidget(instance: instance)
        case .nowPlaying: NowPlayingWidget(instance: instance)
        case .lyrics: LyricsWidget(instance: instance)
        case .battery: BatteryWidget(instance: instance)
        }
    }
}
