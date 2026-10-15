import SwiftUI

struct WhatsNewPage: View {
    private struct Release {
        let version: String
        let summary: String
        let items: [(symbol: String, title: String, detail: String)]
    }

    private let releases = [
        Release(
            version: "1.1",
            summary: "Place widgets anywhere, in the size and style you like, with ten new widgets to choose from.",
            items: [
                ("quote.bubble", "Apple Music lyrics", "Live Lyrics now shows Apple Music's own synced lyrics, timed exactly as in Music."),
                ("rectangle.3.group", "Layout Studio", "Drag widgets anywhere on the lock screen. Select one to change its size, its style or to remove it."),
                ("square.grid.2x2", "Layout Gallery", "Seven ready-made layouts, from After Hours to Mission Control."),
                ("plus.rectangle.on.rectangle", "Widget sizes and styles", "Small, Medium, Wide, Ultra Wide and Large, with live previews when you add a widget."),
                ("sparkles", "Ten new widgets", "Earth, News, Stock Ticker, Photos, Countdown, Pomodoro, Stopwatch, Reminders, System and Daily Brief."),
                ("note.text", "Sticky Notes", "Leave yourself a note on the lock screen in five paper colours."),
                ("menubar.rectangle", "A fuller menu bar", "Open any page, hide widgets, and control the Pomodoro and Stopwatch."),
                ("figure.wave", "Setup Guide", "A short introduction to get started, available any time from General."),
            ]
        ),
        Release(
            version: "1.0",
            summary: "The first release.",
            items: [
                ("lock.display", "Widgets on the lock screen", "Clock, Weather, Calendar, Now Playing, Live Lyrics and Battery."),
                ("quote.bubble", "Live Lyrics", "Time-synced lyrics on the lock screen."),
                ("checkmark.seal", "Signed and notarized", "Installs and opens like any app from the App Store."),
            ]
        ),
    ]

    private var installed: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 18) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What's New").font(.system(size: 26, weight: .bold))
                        Text("What's changed in recent LockWidgets updates.").foregroundStyle(.secondary)
                        Label("Installed version: \(installed)", systemImage: "checkmark.circle.fill")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
                ForEach(releases, id: \.version) { release in
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("LockWidgets \(release.version)").font(.system(size: 20, weight: .bold))
                            Text(release.summary).foregroundStyle(.secondary)
                        }
                        ForEach(release.items, id: \.title) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).font(.headline)
                                    Text(item.detail).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
