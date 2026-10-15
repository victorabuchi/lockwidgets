import SwiftUI

struct WidgetPage: View {
    let kind: WidgetKind

    @AppStorage(SettingsKey.hiddenWidgets) private var hidden = ""

    var body: some View {
        Form {
            Section {
                PageHeader(title: kind.title, subtitle: kind.summary)
                PreviewStage {
                    WidgetBoard.widget(for: kind)
                }
            }

            Section {
                Toggle("Show on the Lock Screen", isOn: kind.visibility($hidden))
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

private struct ClockOptions: View {
    @AppStorage(SettingsKey.use24Hour) private var use24Hour = false
    @AppStorage(SettingsKey.showSeconds) private var showSeconds = false

    var body: some View {
        Section("Clock") {
            Toggle("24-hour time", isOn: $use24Hour)
            Toggle("Show seconds", isOn: $showSeconds)
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
    @AppStorage(SettingsKey.calendarMaxEvents) private var maxEvents = 4
    @AppStorage(SettingsKey.calendarIncludeTomorrow) private var includeTomorrow = true

    var body: some View {
        Section("Events") {
            Stepper("Show up to \(maxEvents) events", value: $maxEvents, in: 1 ... 8)
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
    @AppStorage(SettingsKey.lyricsUpcomingLines) private var upcomingLines = 2
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true

    var body: some View {
        Section {
            Stepper("Show \(upcomingLines) upcoming \(upcomingLines == 1 ? "line" : "lines")", value: $upcomingLines, in: 0 ... 4)
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
