import SwiftUI

struct WidgetPage: View {
    let kind: WidgetKind

    var body: some View {
        Form {
            Section {
                WidgetHeader(kind: kind)
            }

            switch kind {
            case .clock: ClockOptions()
            case .weather: WeatherOptions()
            case .calendar: CalendarOptions()
            case .nowPlaying: NowPlayingOptions()
            case .lyrics: LyricsOptions()
            case .battery: BatteryOptions()
            }
        }
        .formStyle(.grouped)
        .id(kind)
    }
}

/// Preview of the chosen style and size, with a button to add it to the layout.
private struct WidgetHeader: View {
    let kind: WidgetKind

    @ObservedObject private var layout = LayoutStore.shared
    @State private var style = ""
    @State private var size = WidgetSize.small
    @State private var added = false

    var body: some View {
        let current = kind.style(style)
        let placed = layout.instances.filter { $0.kind == kind }.count
        HStack(alignment: .top, spacing: 22) {
            PreviewStage(height: 230) {
                FittedWidget(instance: kind.sample(style: current.id, size: size), box: CGSize(width: 340, height: 200))
            }
            .frame(width: 380)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    WidgetIcon(kind: kind, size: 30)
                    Text(kind.title).font(.system(size: 22, weight: .bold))
                }
                Text(kind.summary).foregroundStyle(.secondary)
                if kind.styles.count > 1 {
                    Picker("Style", selection: $style) {
                        ForEach(kind.styles) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                HStack(spacing: 6) {
                    ForEach(current.sizes) { option in
                        SizeChip(size: option, isSelected: option == size) { size = option }
                    }
                    Text(size.title).foregroundStyle(.secondary).padding(.leading, 4)
                }
                HStack(spacing: 10) {
                    Button {
                        layout.add(kind, style: current.id, size: size)
                        withAnimation { added = true }
                    } label: {
                        Label("Add Widget", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    if added {
                        Label("Added", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.opacity)
                    }
                }
                Text(placed == 0 ? "Not on your lock screen yet." : "\(placed) on your lock screen. Move them in Layout Studio.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            style = kind.defaultStyle.id
            size = kind.defaultStyle.sizes[0]
        }
        .onChange(of: style) {
            let sizes = kind.style(style).sizes
            if !sizes.contains(size) { size = sizes[0] }
            added = false
        }
        .onChange(of: size) { added = false }
    }
}

/// A small proportional tile representing a widget size.
struct SizeChip: View {
    let size: WidgetSize
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            let points = size.points
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.white : Color.secondary)
                .frame(width: points.width / 22, height: points.height / 22)
                .frame(width: 40, height: 28)
                .background(
                    isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .help(size.title)
    }
}

private struct ClockOptions: View {
    @AppStorage(SettingsKey.use24Hour) private var use24Hour = false
    @AppStorage(SettingsKey.showSeconds) private var showSeconds = false
    @AppStorage(SettingsKey.worldClockZones) private var zones = WorldClock.defaultZones

    var body: some View {
        Section("Clock") {
            Toggle("24-hour time", isOn: $use24Hour)
            Toggle("Show seconds", isOn: $showSeconds)
        }
        Section {
            TextField("Cities", text: $zones, prompt: Text(WorldClock.defaultZones))
        } header: {
            Text("World Clock")
        } footer: {
            Text("Time zone names separated by commas, such as Europe/Paris or America/Los_Angeles.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct WeatherOptions: View {
    @ObservedObject private var weather = WeatherStore.shared
    @AppStorage(SettingsKey.weatherCity) private var city = ""
    @AppStorage(SettingsKey.fahrenheit) private var fahrenheit = SettingsKey.defaultFahrenheit
    @State private var draft = ""

    var body: some View {
        Section {
            LabeledContent("City") {
                HStack {
                    TextField("City", text: $draft, prompt: Text("Current location"))
                        .labelsHidden()
                        .onSubmit(apply)
                    Button("Apply", action: apply)
                        .disabled(draft == city)
                }
            }
            Picker("Units", selection: $fahrenheit) {
                Text("Celsius (°C)").tag(false)
                Text("Fahrenheit (°F)").tag(true)
            }
            .onChange(of: fahrenheit) { weather.refresh() }
            if let problem = weather.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Weather")
        } footer: {
            Text("Leave the city empty to use your Mac's location. Forecasts from Open-Meteo, updated every 15 minutes.")
                .foregroundStyle(.secondary)
        }
        .onAppear { draft = city }
    }

    private func apply() {
        city = draft.trimmingCharacters(in: .whitespaces)
        weather.refresh()
    }
}

private struct CalendarOptions: View {
    @ObservedObject private var calendar = CalendarStore.shared
    @AppStorage(SettingsKey.calendarIncludeTomorrow) private var includeTomorrow = true

    var body: some View {
        Section("Events") {
            Toggle(isOn: $includeTomorrow) {
                Text("Include tomorrow")
                Text("Turn off to show only what is left today.")
            }
        }
        Section("Access") {
            LabeledContent("Calendar") {
                switch calendar.status {
                case .fullAccess:
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notDetermined:
                    Button("Allow Access") { calendar.requestAccess() }
                default:
                    Button("Open Privacy Settings") { calendar.openPrivacySettings() }
                }
            }
        }
        .onAppear { calendar.reload() }
    }
}

private struct NowPlayingOptions: View {
    @ObservedObject private var music = NowPlayingStore.shared
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true

    var body: some View {
        Section {
            Toggle(isOn: $hideWhenIdle) {
                Text("Hide when nothing is playing")
                Text("Shared with Live Lyrics.")
            }
            if music.needsPermission {
                LabeledContent("Automation access is off") {
                    Button("Open Privacy Settings") { music.openAutomationSettings() }
                }
            }
        } header: {
            Text("Now Playing")
        } footer: {
            Text("Works with Apple Music and Spotify. LockWidgets only reads from a player that is already open and never launches one.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct LyricsOptions: View {
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true

    var body: some View {
        Section {
            Toggle("Hide when nothing is playing", isOn: $hideWhenIdle)
        } header: {
            Text("Lyrics")
        } footer: {
            Text("Time-synced lyrics come from LRCLIB, a free community database. Some songs have no synced lyrics yet.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct BatteryOptions: View {
    var body: some View {
        Section {
            Text("Shows charge, charging state and time remaining. Hidden automatically on Macs without a battery.")
                .foregroundStyle(.secondary)
        }
    }
}
