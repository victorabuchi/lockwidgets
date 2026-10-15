import SwiftUI

struct SettingsView: View {
    @ObservedObject var overlay: OverlayManager
    @ObservedObject private var calendar = CalendarStore.shared

    @AppStorage(SettingsKey.widgetOrder) private var order = WidgetKind.defaultOrder
    @AppStorage(SettingsKey.hiddenWidgets) private var hidden = ""
    @AppStorage(SettingsKey.position) private var position = BoardPosition.leading
    @AppStorage(SettingsKey.scale) private var scale = 1.0
    @AppStorage(SettingsKey.use24Hour) private var use24Hour = false
    @AppStorage(SettingsKey.showSeconds) private var showSeconds = false
    @AppStorage(SettingsKey.weatherCity) private var city = ""
    @AppStorage(SettingsKey.fahrenheit) private var fahrenheit = SettingsKey.defaultFahrenheit

    var body: some View {
        Form {
            Section {
                ForEach(Array(WidgetKind.ordered(order).enumerated()), id: \.element) { index, kind in
                    widgetRow(kind, index: index)
                }
            } header: {
                Text("Widgets")
            } footer: {
                Text("Widgets appear on the lock screen in this order.")
                    .foregroundStyle(.secondary)
            }

            Section("Layout") {
                Picker("Position", selection: $position) {
                    ForEach(BoardPosition.allCases) { Text($0.title).tag($0) }
                }
                LabeledContent("Size") {
                    HStack {
                        Slider(value: $scale, in: 0.8 ... 1.4, step: 0.05)
                        Text("\(Int((scale * 100).rounded()))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Clock") {
                Toggle("24-hour time", isOn: $use24Hour)
                Toggle("Show seconds", isOn: $showSeconds)
            }

            Section {
                TextField("City", text: $city, prompt: Text("Current location"))
                    .onSubmit { WeatherStore.shared.refresh() }
                Picker("Units", selection: $fahrenheit) {
                    Text("°C").tag(false)
                    Text("°F").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: fahrenheit) { WeatherStore.shared.refresh() }
            } header: {
                Text("Weather")
            } footer: {
                Text("Leave the city empty to use your Mac's location. Press Return to apply.")
                    .foregroundStyle(.secondary)
            }

            Section("Calendar") {
                LabeledContent("Access") {
                    switch calendar.status {
                    case .fullAccess:
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .notDetermined:
                        Button("Allow Access") { calendar.requestAccess() }
                    default:
                        Button("Open Privacy Settings") { calendar.openPrivacySettings() }
                    }
                }
            }

            Section {
                Button(overlay.isShowing ? "Hide Preview" : "Preview on Desktop") {
                    overlay.toggle()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { calendar.reload() }
    }

    private func widgetRow(_ kind: WidgetKind, index: Int) -> some View {
        let count = WidgetKind.allCases.count
        return HStack(spacing: 10) {
            Image(systemName: kind.symbol)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Toggle(kind.title, isOn: visibility(kind))
            Spacer()
            Button { move(kind, by: -1) } label: { Image(systemName: "chevron.up") }
                .disabled(index == 0)
            Button { move(kind, by: 1) } label: { Image(systemName: "chevron.down") }
                .disabled(index == count - 1)
        }
        .buttonStyle(.borderless)
        .toggleStyle(.checkbox)
    }

    private func visibility(_ kind: WidgetKind) -> Binding<Bool> {
        Binding {
            !hiddenSet.contains(kind.rawValue)
        } set: { isOn in
            var set = hiddenSet
            if isOn { set.remove(kind.rawValue) } else { set.insert(kind.rawValue) }
            hidden = set.sorted().joined(separator: ",")
        }
    }

    private var hiddenSet: Set<String> {
        Set(hidden.split(separator: ",").map(String.init))
    }

    private func move(_ kind: WidgetKind, by offset: Int) {
        var kinds = WidgetKind.ordered(order)
        guard let from = kinds.firstIndex(of: kind) else { return }
        let to = from + offset
        guard kinds.indices.contains(to) else { return }
        kinds.swapAt(from, to)
        order = kinds.map(\.rawValue).joined(separator: ",")
    }
}
