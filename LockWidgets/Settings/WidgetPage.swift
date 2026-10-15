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
            case .countdown: CountdownOptions()
            case .pomodoro: PomodoroOptions()
            case .stopwatch: StopwatchOptions()
            case .stickyNote: EmptyView()
            case .reminders: RemindersOptions()
            case .system: EmptyView()
            case .news: NewsOptions()
            case .stocks: StocksOptions()
            case .photos: PhotosOptions()
            case .earth: EarthOptions()
            case .dailyBrief: EmptyView()
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
                FittedWidget(instance: kind.sample(style: current.id, size: size), box: CGSize(width: 300, height: 200))
            }
            .frame(minWidth: 260, maxWidth: 360)

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
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            TextField("Cities", text: $zones, prompt: Text(WorldClock.defaultZones), axis: .vertical)
                .lineLimit(1 ... 3)
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
    @ObservedObject private var lyrics = LyricsStore.shared
    @AppStorage(SettingsKey.hideMusicWhenIdle) private var hideWhenIdle = true

    var body: some View {
        Section {
            LabeledContent("Now") {
                switch lyrics.state {
                case .found: Text("\(lyrics.lines.count) lines for this song").foregroundStyle(.secondary)
                case .loading: Text("Getting lyrics…").foregroundStyle(.secondary)
                case .unavailable: Text("No lyrics for this song").foregroundStyle(.secondary)
                case .otherPlayer: Text("Play something in Apple Music").foregroundStyle(.secondary)
                case .idle: Text("Nothing playing").foregroundStyle(.secondary)
                }
            }
            Toggle("Hide when nothing is playing", isOn: $hideWhenIdle)
        } header: {
            Text("Apple Music Lyrics")
        } footer: {
            Text("These are Apple Music's own lyrics, timed line by line exactly as in Music. LockWidgets reads them from Music on this Mac; nothing comes from anywhere else.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct CountdownOptions: View {
    var body: some View {
        Section {
            Text("Each countdown has its own title and date. Select one in Layout Studio to set them.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct PomodoroOptions: View {
    @ObservedObject private var timers = TimerStore.shared
    @AppStorage(TimerStore.focusMinutesKey) private var focus = 25
    @AppStorage(TimerStore.breakMinutesKey) private var shortBreak = 5
    @AppStorage(TimerStore.longBreakMinutesKey) private var longBreak = 15

    var body: some View {
        Section("Timer") {
            LabeledContent(timers.phase.title) {
                HStack {
                    Button(timers.pomodoroRunning ? "Pause" : "Start") { timers.togglePomodoro() }
                        .buttonStyle(.borderedProminent)
                    Button("Skip") { timers.skipPhase() }
                    Button("Reset") { timers.resetPomodoro() }
                }
            }
        }
        Section {
            Stepper("Focus: \(focus) min", value: $focus, in: 5 ... 90, step: 5)
            Stepper("Short break: \(shortBreak) min", value: $shortBreak, in: 1 ... 30)
            Stepper("Long break: \(longBreak) min", value: $longBreak, in: 5 ... 60, step: 5)
        } header: {
            Text("Sessions")
        } footer: {
            Text("A long break follows every four focus sessions. You can also start and pause from the menu bar.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct StopwatchOptions: View {
    @ObservedObject private var timers = TimerStore.shared

    var body: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                LabeledContent(timers.stopwatchElapsed(at: context.date).clockText) {
                    HStack {
                        Button(timers.stopwatchRunning ? "Stop" : "Start") { timers.toggleStopwatch() }
                            .buttonStyle(.borderedProminent)
                        Button("Reset") { timers.resetStopwatch() }
                    }
                }
                .monospacedDigit()
            }
        } header: {
            Text("Stopwatch")
        } footer: {
            Text("You can also start and stop it from the menu bar.")
                .foregroundStyle(.secondary)
        }
    }
}

private struct RemindersOptions: View {
    @ObservedObject private var reminders = RemindersStore.shared

    var body: some View {
        Section("Access") {
            LabeledContent("Reminders") {
                switch reminders.status {
                case .fullAccess:
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .notDetermined:
                    Button("Allow Access") { reminders.requestAccess() }
                default:
                    Button("Open Privacy Settings") { reminders.openPrivacySettings() }
                }
            }
        }
        .onAppear { reminders.reload() }
    }
}

private struct NewsOptions: View {
    @ObservedObject private var news = NewsStore.shared
    @AppStorage(NewsStore.feedKey) private var feed = NewsStore.sources[0].url
    @State private var custom = ""

    var body: some View {
        Section {
            Picker("Source", selection: $feed) {
                ForEach(NewsStore.sources, id: \.url) { Text($0.name).tag($0.url) }
                if !NewsStore.sources.contains(where: { $0.url == feed }) {
                    Text("Custom feed").tag(feed)
                }
            }
            .onChange(of: feed) { news.refresh() }
            LabeledContent("Custom RSS feed") {
                HStack {
                    TextField("https://…", text: $custom)
                        .labelsHidden()
                        .onSubmit(useCustom)
                    Button("Use", action: useCustom)
                        .disabled(URL(string: custom)?.scheme?.hasPrefix("http") != true)
                }
            }
            if let problem = news.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("News")
        } footer: {
            Text("Headlines refresh every 30 minutes. Any RSS or Atom feed works.")
                .foregroundStyle(.secondary)
        }
    }

    private func useCustom() {
        feed = custom.trimmingCharacters(in: .whitespaces)
        custom = ""
    }
}

private struct StocksOptions: View {
    @ObservedObject private var stocks = StocksStore.shared
    @AppStorage(StocksStore.symbolsKey) private var symbols = StocksStore.defaultSymbols
    @State private var draft = ""

    var body: some View {
        Section {
            LabeledContent("Symbols") {
                HStack {
                    TextField("Symbols", text: $draft)
                        .labelsHidden()
                        .onSubmit(apply)
                    Button("Apply", action: apply)
                        .disabled(draft == symbols)
                }
            }
            ForEach(stocks.quotes) { quote in
                LabeledContent(quote.symbol) {
                    Text("\(quote.priceText)  \(quote.changeText)")
                        .foregroundStyle(quote.change >= 0 ? .green : .red)
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Watchlist")
        } footer: {
            Text("Separate symbols with commas. Use BTC-USD for crypto and EURUSD=X for currency pairs. The first symbol leads the Spotlight style. Prices from Yahoo Finance, updated every 5 minutes.")
                .foregroundStyle(.secondary)
        }
        .onAppear { draft = symbols }
    }

    private func apply() {
        symbols = draft.uppercased().replacingOccurrences(of: " ", with: "")
        draft = symbols
        stocks.refresh()
    }
}

private struct PhotosOptions: View {
    @ObservedObject private var photos = PhotosStore.shared
    @AppStorage(PhotosStore.sourceKey) private var source = PhotosStore.Source.favorites
    @AppStorage(PhotosStore.intervalKey) private var interval = 15

    var body: some View {
        Section {
            Picker("Show", selection: $source) {
                ForEach(PhotosStore.Source.allCases) { Text($0.title).tag($0) }
            }
            .onChange(of: source) { photos.next() }
            if source == .folder {
                LabeledContent("Folder") {
                    HStack {
                        Text(photos.folderName ?? "None chosen")
                            .foregroundStyle(.secondary)
                        Button("Choose…") { photos.chooseFolder() }
                    }
                }
            } else if !photos.libraryAccess {
                LabeledContent("Photos access") {
                    Button("Allow Access") { photos.requestAccess() }
                }
            }
            Picker("Change photo", selection: $interval) {
                Text("Every minute").tag(1)
                Text("Every 5 minutes").tag(5)
                Text("Every 15 minutes").tag(15)
                Text("Every hour").tag(60)
            }
            .onChange(of: interval) { photos.restartTimer() }
            LabeledContent("Current photo") {
                Button("Show Another") { photos.next() }
            }
            if let problem = photos.problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Photos")
        }
    }
}

private struct EarthOptions: View {
    var body: some View {
        Section {
            Text("The globe is centred on your weather location and redrawn every 10 minutes, with night shading from the sun's real position.")
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
