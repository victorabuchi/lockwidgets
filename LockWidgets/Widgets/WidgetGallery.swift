#if DEBUG
import AppKit
import SwiftUI

/// Test builds only: draws every widget, in each style and size, with sample data to PNG files for the
/// website, then quits before any window, island or menu bar icon appears. The stores skip their live
/// updates while it runs, so it reads none of your data and talks to no app; see scripts/widget-gallery.sh.
enum WidgetGallery {
    /// Where to write the pictures, from the `-renderWidgets` launch argument.
    static let folder = UserDefaults.standard.string(forKey: "renderWidgets").map { URL(fileURLWithPath: $0, isDirectory: true) }
    static var isRendering: Bool { folder != nil }

    @MainActor
    static func run(into folder: URL) -> Never {
        let samples = UserDefaults.standard.string(forKey: "gallerySamples").map { URL(fileURLWithPath: $0, isDirectory: true) }
        let cover = samples.flatMap { NSImage(contentsOf: $0.appendingPathComponent("cover.jpg")) }
        let photo = samples.flatMap { NSImage(contentsOf: $0.appendingPathComponent("photo.jpg")) }

        func loadSamples() {
            WeatherStore.shared.loadSample()
            CalendarStore.shared.loadSample()
            NowPlayingStore.shared.loadSample(artwork: cover)
            LyricsStore.shared.loadSample()
            BatteryMonitor.shared.loadSample()
            SystemMonitor.shared.loadSample()
            TimerStore.shared.loadSample()
            RemindersStore.shared.loadSample()
            NewsStore.shared.loadSample()
            StocksStore.shared.loadSample()
            PhotosStore.shared.loadSample(photo)
            ActivityTracker.shared.loadSample()
        }

        let instances = instances()
        loadSamples()
        // A first pass asks MapKit for the maps and the globe, which arrive a few seconds later.
        instances.forEach { _ = png($0) }
        let deadline = Date.now.addingTimeInterval(20)
        while Date.now < deadline, !mapsReady() {
            RunLoop.main.run(until: .now.addingTimeInterval(0.25))
        }
        // Live updates, such as the battery and system monitors, may have landed while waiting.
        loadSamples()

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var written = 0
        for instance in instances {
            let name = "\(instance.kind.rawValue)-\(instance.style)-\(instance.size.rawValue).png"
            if let data = png(instance), (try? data.write(to: folder.appendingPathComponent(name))) != nil {
                written += 1
            } else {
                print("Couldn't draw \(name)")
            }
        }
        print("Drew \(written) of \(instances.count) widgets into \(folder.path)")
        exit(written == instances.count ? 0 : 1)
    }

    private static func instances() -> [WidgetInstance] {
        WidgetKind.allCases.flatMap { kind in
            kind.styles.flatMap { style in
                style.sizes.map { size in
                    var instance = kind.sample(style: style.id, size: size)
                    switch kind {
                    case .stickyNote:
                        instance.config = ["text": "Water the plants 🌿\nCall the bike shop\nGym at 6", "color": NoteColor.yellow.rawValue]
                    case .countdown:
                        let date = Date.now.addingTimeInterval(23 * 86400 + 6 * 3600 + 14 * 60)
                        instance.config = ["title": "Trip to Lisbon", "date": String(date.timeIntervalSince1970)]
                    default: break
                    }
                    return instance
                }
            }
        }
    }

    private static func mapsReady() -> Bool {
        guard EarthStore.shared.image != nil, let report = WeatherStore.shared.report else { return false }
        return WidgetKind.location.styles.flatMap(\.sizes).allSatisfy {
            MapSnapshots.shared.image(latitude: report.latitude, longitude: report.longitude, size: $0) != nil
        }
    }

    @MainActor
    private static func png(_ instance: WidgetInstance) -> Data? {
        let renderer = ImageRenderer(content: WidgetView(instance: instance))
        renderer.scale = 2
        renderer.isOpaque = false
        guard let image = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
#endif
