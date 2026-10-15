import SwiftUI

struct EarthWidget: View {
    let instance: WidgetInstance
    @ObservedObject private var earth = EarthStore.shared
    @ObservedObject private var weather = WeatherStore.shared

    var body: some View {
        WidgetCard(size: instance.size, padding: instance.size == .medium ? 8 : 6) {
            HStack(spacing: 0) {
                globe
                    .frame(width: instance.size.points.height, height: instance.size.points.height)
                if instance.size == .medium {
                    details
                        .padding(.trailing, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { if earth.image == nil { earth.refresh() } }
    }

    @ViewBuilder
    private var globe: some View {
        if let image = earth.image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                // The snapshot's globe spans 77% of the image; enlarge it to fill ~90% of the widget.
                .scaleEffect(1.17)
                .shadow(color: .black.opacity(0.4), radius: 8)
        } else {
            ProgressView().controlSize(.small)
        }
    }

    private var details: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 6) {
                Caption(weather.report?.place ?? "Earth", color: Theme.secondary)
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                if let sunrise = weather.report?.sunrise, let sunset = weather.report?.sunset {
                    Label(sunrise.formatted(date: .omitted, time: .shortened), systemImage: "sunrise.fill")
                    Label(sunset.formatted(date: .omitted, time: .shortened), systemImage: "sunset.fill")
                    Text(daylight(sunrise, sunset))
                        .foregroundStyle(Theme.tertiary)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .symbolRenderingMode(.multicolor)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func daylight(_ sunrise: Date, _ sunset: Date) -> String {
        let minutes = Int(sunset.timeIntervalSince(sunrise) / 60)
        return "\(minutes / 60)h \(minutes % 60)m of daylight"
    }
}
