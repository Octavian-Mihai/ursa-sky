import Foundation

struct ISSPass: Identifiable, Hashable {
    var aos: Date
    var los: Date
    var maxAlt: Double
    var maxAz: Double
    var maxTime: Date
    var id: Date { aos }

    var duration: TimeInterval { los.timeIntervalSince(aos) }
}

final class ISSPredictor {
    private(set) var tle: TLE
    private var sgp4: SGP4?

    init(tle: TLE) {
        self.tle = tle
        self.sgp4 = SGP4(tle: tle)
    }

    func update(tle: TLE) {
        self.tle = tle
        self.sgp4 = SGP4(tle: tle)
    }

    func position(at date: Date) -> SGP4.State? {
        guard let sgp4 else { return nil }
        return sgp4.propagate(minutesSinceEpoch: sgp4.minutes(since: date))
    }

    func altAz(at date: Date, latitude: Double, longitudeEast: Double) -> Horizontal? {
        guard let pos = position(at: date) else { return nil }
        let jd = JulianDate.julianDay(from: date)
        return TEME.altAz(positionKm: pos.positionKm, jd: jd, latitude: latitude, longitudeEast: longitudeEast)
    }

    /// Scan the next `hours` at 30 s steps and group above-horizon segments.
    func upcomingPasses(from start: Date, hours: Double, latitude: Double, longitudeEast: Double, minAlt: Double = 10) -> [ISSPass] {
        let step: TimeInterval = 30
        let end = start.addingTimeInterval(hours * 3600)
        var passes: [ISSPass] = []
        var currentAOS: Date?
        var maxAlt = -90.0
        var maxAz = 0.0
        var maxTime = start
        var t = start
        while t <= end {
            let h = altAz(at: t, latitude: latitude, longitudeEast: longitudeEast)
            let alt = h?.alt ?? -90
            if alt >= minAlt {
                if currentAOS == nil { currentAOS = t }
                if alt > maxAlt {
                    maxAlt = alt
                    maxAz = h?.az ?? 0
                    maxTime = t
                }
            } else if let aos = currentAOS {
                passes.append(ISSPass(aos: aos, los: t, maxAlt: maxAlt, maxAz: maxAz, maxTime: maxTime))
                currentAOS = nil
                maxAlt = -90
            }
            t = t.addingTimeInterval(step)
        }
        return passes
    }
}
