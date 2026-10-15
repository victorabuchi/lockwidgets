import AppKit
import Combine
import MapKit

/// A satellite globe centred on the user's location, with night drawn from the sun's current position.
final class EarthStore: ObservableObject {
    static let shared = EarthStore()

    @Published private(set) var image: NSImage?

    private var timer: Timer?
    private var subscription: AnyCancellable?
    private var snapshotter: MKMapSnapshotter?
    /// Globe radius as a fraction of the snapshot's width at the camera distance used below.
    private let globeRadius = 0.385

    private init() {
        subscription = WeatherStore.shared.$report
            .map { report in report.map { "\(Int($0.latitude)),\(Int($0.longitude))" } }
            .removeDuplicates()
            .sink { [weak self] _ in self?.refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    /// Where to centre the globe: the weather location, or a longitude guessed from the time zone.
    private var center: CLLocationCoordinate2D {
        if let report = WeatherStore.shared.report {
            return CLLocationCoordinate2D(latitude: max(min(report.latitude, 50), -50), longitude: report.longitude)
        }
        return CLLocationCoordinate2D(latitude: 20, longitude: Double(TimeZone.current.secondsFromGMT()) / 3600 * 15)
    }

    func refresh() {
        let center = center
        let options = MKMapSnapshotter.Options()
        options.mapType = .satelliteFlyover
        options.camera = MKMapCamera(lookingAtCenter: center, fromDistance: 25_000_000, pitch: 0, heading: 0)
        options.size = NSSize(width: 600, height: 600)
        options.appearance = NSAppearance(named: .darkAqua)
        let snapshotter = MKMapSnapshotter(options: options)
        self.snapshotter = snapshotter
        snapshotter.start { [weak self] snapshot, _ in
            guard let self, let snapshot else { return }
            let shaded = shade(snapshot.image, center: center, at: .now)
            DispatchQueue.main.async { self.image = shaded }
        }
    }

    // MARK: Night

    private func shade(_ globe: NSImage, center: CLLocationCoordinate2D, at date: Date) -> NSImage {
        let size = globe.size
        let sun = sunVector(center: center, at: date)
        let maskSize = 300
        var pixels = [UInt8](repeating: 0, count: maskSize * maskSize)
        let radius = Double(maskSize) * globeRadius
        let middle = Double(maskSize) / 2
        for row in 0 ..< maskSize {
            for column in 0 ..< maskSize {
                let x = (Double(column) + 0.5 - middle) / radius
                let y = (middle - Double(row) - 0.5) / radius
                let distance = x * x + y * y
                guard distance < 1 else { continue }
                let z = (1 - distance).squareRoot()
                let light = x * sun.x + y * sun.y + z * sun.z
                // Soft terminator: fully dark a little past the line between day and night.
                let darkness = min(max(-light / 0.18 + 0.15, 0), 1)
                pixels[row * maskSize + column] = UInt8(darkness * 200)
            }
        }
        let mask = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            CGContext(
                data: buffer.baseAddress, width: maskSize, height: maskSize, bitsPerComponent: 8, bytesPerRow: maskSize,
                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
            )?.makeImage()
        }

        let result = NSImage(size: size)
        result.lockFocus()
        // Keep only the globe, so the widget's own card (or none, in Minimal) shows around it.
        let clipRadius = size.width * (globeRadius - 0.003)
        NSBezierPath(ovalIn: NSRect(x: size.width / 2 - clipRadius, y: size.height / 2 - clipRadius, width: clipRadius * 2, height: clipRadius * 2)).addClip()
        globe.draw(in: NSRect(origin: .zero, size: size))
        if let mask, let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.clip(to: CGRect(origin: .zero, size: size), mask: mask)
            context.setFillColor(NSColor(red: 0.01, green: 0.02, blue: 0.08, alpha: 0.85).cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            context.restoreGState()
        }
        result.unlockFocus()
        return result
    }

    /// Direction of the sun in the globe view: x right, y up, z towards the viewer.
    private func sunVector(center: CLLocationCoordinate2D, at date: Date) -> (x: Double, y: Double, z: Double) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let day = Double(utc.ordinality(of: .day, in: .year, for: date) ?? 1)
        let parts = utc.dateComponents([.hour, .minute], from: date)
        let hours = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60

        let declination = 23.44 * sin(2 * .pi * (284 + day) / 365) * .pi / 180
        let subsolarLongitude = (12 - hours) * 15 * .pi / 180
        let latitude0 = center.latitude * .pi / 180
        let longitude0 = center.longitude * .pi / 180
        let deltaLongitude = subsolarLongitude - longitude0

        let x = cos(declination) * sin(deltaLongitude)
        let y = cos(latitude0) * sin(declination) - sin(latitude0) * cos(declination) * cos(deltaLongitude)
        let z = sin(latitude0) * sin(declination) + cos(latitude0) * cos(declination) * cos(deltaLongitude)
        return (x, y, z)
    }
}
