import Foundation

/// IAU 1976 precession, J2000.0 → date of JD. Meeus chapter 21.
enum Precession {
    static func precess(j2000: Equatorial, toJD jd: Double) -> Equatorial {
        let t = JulianDate.centuriesSinceJ2000(jd: jd)
        if abs(t) < 1e-12 { return j2000 }

        // Arcseconds → radians
        let zeta = Angle.deg((2306.2181 * t + 0.30188 * t * t + 0.017998 * t * t * t) / 3600.0)
        let z = Angle.deg((2306.2181 * t + 1.09468 * t * t + 0.018203 * t * t * t) / 3600.0)
        let theta = Angle.deg((2004.3109 * t - 0.42665 * t * t - 0.041833 * t * t * t) / 3600.0)

        let ra0 = Angle.deg(j2000.ra)
        let dec0 = Angle.deg(j2000.dec)
        let cosDec = cos(dec0)
        let sinDec = sin(dec0)

        let a = cosDec * sin(ra0 + zeta)
        let b = cos(theta) * cosDec * cos(ra0 + zeta) - sin(theta) * sinDec
        let c = sin(theta) * cosDec * cos(ra0 + zeta) + cos(theta) * sinDec

        let ra = Angle.wrap360(Angle.rad(atan2(a, b) + z))
        let dec = Angle.rad(asin(max(-1, min(1, c))))
        return Equatorial(ra: ra, dec: dec)
    }
}
