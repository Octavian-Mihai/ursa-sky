import Foundation
import CoreLocation
import Combine

enum LocationSource: String, Codable {
    case gps
    case city
    case manual
}

struct ObserverLocation: Equatable, Codable {
    var latitude: Double
    var longitude: Double
    var altitudeMeters: Double
    var timeZoneId: String
    var label: String
    var source: LocationSource

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneId) ?? .current
    }
}

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var current: ObserverLocation?
    @Published var authorization: CLAuthorizationStatus
    @Published var lastError: String?
    @Published var isUpdating = false

    private let manager = CLLocationManager()
    private let defaultsKey = "ursa.location.cached"

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let cached = try? JSONDecoder().decode(ObserverLocation.self, from: data) {
            current = cached
        }
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            lastError = "Location permission is off. Enable it in Settings, or pick a city."
            isUpdating = false
            return
        }
        isUpdating = true
        lastError = nil
        manager.requestLocation()
    }

    func applyCity(_ city: City) {
        let loc = ObserverLocation(
            latitude: city.latitude,
            longitude: city.longitude,
            altitudeMeters: 0,
            timeZoneId: city.timeZoneId,
            label: "\(city.name), \(city.country)",
            source: .city
        )
        set(loc)
    }

    func applyManual(latitude: Double, longitude: Double, timeZoneId: String?, label: String?) {
        let loc = ObserverLocation(
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: 0,
            timeZoneId: timeZoneId ?? TimeZone.current.identifier,
            label: label ?? String(format: "%.4f°, %.4f°", latitude, longitude),
            source: .manual
        )
        set(loc)
    }

    private func set(_ loc: ObserverLocation) {
        current = loc
        if let data = try? JSONEncoder().encode(loc) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorization = manager.authorizationStatus
            let authorized = manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways
            // Do not clobber a city/manual pick just because GPS is now allowed.
            if authorized, self.current == nil || self.current?.source == .gps {
                self.start()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.isUpdating = false
            let geo = ObserverLocation(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitudeMeters: loc.altitude,
                timeZoneId: TimeZone.current.identifier,
                label: "GPS",
                source: .gps
            )
            self.set(geo)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isUpdating = false
            self.lastError = error.localizedDescription
        }
    }
}

enum CityStore {
    static func load() -> [City] {
        guard let url = Bundle.main.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["cities"] as? [[String: Any]] else { return [] }
        return arr.compactMap { d in
            guard let name = d["name"] as? String else { return nil }
            let lat = (d["lat"] as? Double) ?? (d["lat"] as? NSNumber)?.doubleValue
            let lon = (d["lon"] as? Double) ?? (d["lon"] as? NSNumber)?.doubleValue
            guard let lat, let lon, let tz = d["tz"] as? String else { return nil }
            return City(name: name, country: d["country"] as? String ?? "", latitude: lat, longitude: lon, timeZoneId: tz)
        }.sorted { $0.name < $1.name }
    }
}
