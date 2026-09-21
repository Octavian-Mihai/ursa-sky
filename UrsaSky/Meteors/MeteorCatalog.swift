import Foundation

struct MeteorShower: Identifiable, Hashable {
    var id: String
    var name: String
    var iauCode: String
    var parent: String
    var start: String
    var peak: String
    var end: String
    var zhr: Int
    var raJ2000: Double
    var decJ2000: Double
    var speedKms: Double
    var notes: String

    var equatorial: Equatorial { Equatorial(ra: raJ2000, dec: decJ2000) }

    func monthDay(_ key: String, year: Int) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let m = Int(parts[0]), let d = Int(parts[1]) else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.date(from: DateComponents(year: year, month: m, day: d, hour: 12))
    }

    func isActive(on date: Date) -> Bool {
        let cal = Calendar.current
        let year = cal.component(.year, from: date)
        guard let s = monthDay(start, year: year), let e = monthDay(end, year: year) else { return false }
        if e >= s {
            return date >= s.addingTimeInterval(-12 * 3600) && date <= e.addingTimeInterval(12 * 3600)
        }
        // wraps year (none currently, but keep)
        return date >= s || date <= e
    }
}

final class MeteorCatalog {
    static let shared = MeteorCatalog()
    private(set) var showers: [MeteorShower] = []

    init() {
        showers = Self.load()
    }

    func active(on date: Date) -> [MeteorShower] {
        showers.filter { $0.isActive(on: date) }
    }

    func sortedForCalendar(around date: Date) -> [MeteorShower] {
        let year = Calendar.current.component(.year, from: date)
        return showers.sorted {
            ($0.monthDay($0.peak, year: year) ?? .distantFuture) < ($1.monthDay($1.peak, year: year) ?? .distantFuture)
        }
    }

    private static func load() -> [MeteorShower] {
        guard let url = Bundle.main.url(forResource: "meteors", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = obj["showers"] as? [[String: Any]] else { return [] }
        return arr.compactMap { d in
            guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
            return MeteorShower(
                id: id,
                name: name,
                iauCode: d["iau_code"] as? String ?? "",
                parent: d["parent"] as? String ?? "",
                start: d["start"] as? String ?? "",
                peak: d["peak"] as? String ?? "",
                end: d["end"] as? String ?? "",
                zhr: d["zhr"] as? Int ?? 0,
                raJ2000: d["ra_j2000"] as? Double ?? 0,
                decJ2000: d["dec_j2000"] as? Double ?? 0,
                speedKms: d["speed_kms"] as? Double ?? 0,
                notes: d["notes"] as? String ?? ""
            )
        }
    }
}
