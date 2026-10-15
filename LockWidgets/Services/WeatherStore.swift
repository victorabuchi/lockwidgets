import CoreLocation
import Foundation

/// Current conditions and the next few hours from Open-Meteo (free, no API key).
/// Uses the city from settings, or the Mac's location when no city is set.
final class WeatherStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherStore()

    struct Hour: Identifiable {
        let id: Date
        let temperature: Double
        let code: Int
        let isDay: Bool
    }

    struct Report {
        let place: String
        let timeZone: TimeZone
        let temperature: Double
        let code: Int
        let isDay: Bool
        let high: Double
        let low: Double
        let hours: [Hour]
    }

    @Published private(set) var report: Report?
    @Published private(set) var problem: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var timer: Timer?

    private var city: String {
        (UserDefaults.standard.string(forKey: SettingsKey.weatherCity) ?? "").trimmingCharacters(in: .whitespaces)
    }

    private var fahrenheit: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.fahrenheit) as? Bool ?? SettingsKey.defaultFahrenheit
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        if city.isEmpty {
            requestLocation()
        } else {
            let name = city
            Task { await load(city: name) }
        }
    }

    // MARK: Location

    private var locationAllowed: Bool {
        switch manager.authorizationStatus {
        case .notDetermined, .denied, .restricted: false
        default: true
        }
    }

    private func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            publish(problem: "Location is off. Set a city in LockWidgets settings.")
        default:
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard city.isEmpty, manager.authorizationStatus != .notDetermined else { return }
        requestLocation()
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            let name = placemarks?.first?.locality ?? placemarks?.first?.name ?? "Current location"
            Task {
                await self?.load(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    place: name
                )
            }
        }
    }

    func locationManager(_: CLLocationManager, didFailWithError _: Error) {
        publish(problem: "Couldn't find your location. Set a city in LockWidgets settings.")
    }

    // MARK: Open-Meteo

    private func load(city: String) async {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [.init(name: "name", value: city), .init(name: "count", value: "1")]
        do {
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            guard let match = try JSONDecoder().decode(GeocodingResponse.self, from: data).results?.first else {
                publish(problem: "Couldn't find “\(city)”. Check the city in settings.")
                return
            }
            await load(latitude: match.latitude, longitude: match.longitude, place: match.name)
        } catch {
            publish(problem: "Weather is unavailable right now.")
        }
    }

    private func load(latitude: Double, longitude: Double, place: String) async {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,weather_code,is_day"),
            .init(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "forecast_days", value: "2"),
            .init(name: "forecast_hours", value: "6"),
            .init(name: "timezone", value: "auto"),
            .init(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
        ]
        do {
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            let forecast = try JSONDecoder().decode(ForecastResponse.self, from: data)
            let timeZone = TimeZone(secondsFromGMT: forecast.utc_offset_seconds) ?? .current
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.timeZone = timeZone
            parser.dateFormat = "yyyy-MM-dd'T'HH:mm"

            let hourly = forecast.hourly
            let hours = hourly.time.indices.compactMap { index -> Hour? in
                guard let date = parser.date(from: hourly.time[index]) else { return nil }
                return Hour(
                    id: date,
                    temperature: hourly.temperature_2m[index],
                    code: hourly.weather_code[index],
                    isDay: hourly.is_day[index] == 1
                )
            }
            let report = Report(
                place: place,
                timeZone: timeZone,
                temperature: forecast.current.temperature_2m,
                code: forecast.current.weather_code,
                isDay: forecast.current.is_day == 1,
                high: forecast.daily.temperature_2m_max.first ?? forecast.current.temperature_2m,
                low: forecast.daily.temperature_2m_min.first ?? forecast.current.temperature_2m,
                hours: hours
            )
            await MainActor.run {
                self.report = report
                self.problem = nil
            }
        } catch {
            publish(problem: "Weather is unavailable right now.")
        }
    }

    private func publish(problem: String) {
        DispatchQueue.main.async { self.problem = problem }
    }
}

private struct GeocodingResponse: Decodable {
    struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    let results: [Result]?
}

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
        let is_day: [Int]
    }

    struct Daily: Decodable {
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
    }

    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily
}

/// WMO weather interpretation codes used by Open-Meteo.
enum WeatherCode {
    static func symbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 65, 82: "cloud.heavyrain.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    static func description(_ code: Int) -> String {
        switch code {
        case 0: "Clear"
        case 1: "Mostly clear"
        case 2: "Partly cloudy"
        case 3: "Cloudy"
        case 45, 48: "Fog"
        case 51...57: "Drizzle"
        case 61...67, 80...82: "Rain"
        case 71...77, 85, 86: "Snow"
        case 95...99: "Thunderstorms"
        default: "—"
        }
    }
}
