import SwiftUI

struct AboutPage: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notchlight")
                            .font(.system(size: 22, weight: .bold))
                        Text(version)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Built with") {
                credit("SkyLightWindow", "Draws windows above the lock screen.", "https://github.com/Lakr233/SkyLightWindow")
                credit("Open-Meteo", "Weather forecasts.", "https://open-meteo.com")
            }

            Section {
                Link("Source on GitHub", destination: URL(string: "https://github.com/victorabuchi/notchlight")!)
            }
        }
        .formStyle(.grouped)
    }

    private func credit(_ name: String, _ detail: String, _ url: String) -> some View {
        LabeledContent {
            Link("Website", destination: URL(string: url)!)
        } label: {
            Text(name)
            Text(detail)
        }
    }
}
