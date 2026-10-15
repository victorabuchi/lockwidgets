import SwiftUI

struct AppearancePage: View {
    @AppStorage(SettingsKey.cardStyle) private var style = CardStyle.glass
    @AppStorage(SettingsKey.cornerRadius) private var cornerRadius = Theme.cornerRadius

    var body: some View {
        Form {
            Section {
                PageHeader(title: "Appearance", subtitle: "Applies to every widget.")
                PreviewStage(height: 300) {
                    HStack(alignment: .top, spacing: 14) {
                        FittedWidget(instance: WidgetKind.clock.sample(size: .medium), box: CGSize(width: 290, height: 150))
                        FittedWidget(instance: WidgetKind.weather.sample(style: "hourly", size: .medium), box: CGSize(width: 290, height: 150))
                    }
                }
            }

            Section("Card style") {
                Picker("Card style", selection: $style) {
                    ForEach(CardStyle.allCases) { style in
                        VStack(alignment: .leading) {
                            Text(style.title)
                            Text(style.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Section {
                LabeledContent("Corner radius") {
                    SliderValue(value: $cornerRadius, range: 0 ... 36, step: 1) { "\(Int($0)) pt" }
                }
                .disabled(style == .minimal)
            }
        }
        .formStyle(.grouped)
    }
}
