import Foundation

/// Greenwich and local sidereal time, Meeus chapter 12.
enum Sidereal {
    /// Greenwich Mean Sidereal Time in degrees, 0...360.
    /// Meeus (12.4), using UTC as an approximation of UT1.
    static func gmstDegrees(jd: Double) -> Double {
        let d = jd - 2451545.0
        let t = d / 36525.0
        let theta = 280.46061837
            + 360.98564736629 * d
            + 0.000387933 * t * t
            - t * t * t / 38710000.0
        return Angle.wrap360(theta)
    }

    /// Local Mean Sidereal Time in degrees. Longitude is east-positive.
    static func lmstDegrees(jd: Double, longitudeEast: Double) -> Double {
        Angle.wrap360(gmstDegrees(jd: jd) + longitudeEast)
    }
}
