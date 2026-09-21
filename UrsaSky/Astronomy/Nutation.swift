import Foundation

/// Simplified IAU 1980 nutation (leading lunar-node terms). Meeus chapter 22.
struct Nutation {
    /// Nutation in longitude Δψ and obliquity Δε, in degrees.
    var dPsi: Double
    var dEps: Double
    /// Mean obliquity of the ecliptic ε0, degrees.
    var meanObliquity: Double
    var trueObliquity: Double { meanObliquity + dEps }

    static func at(jd: Double) -> Nutation {
        let t = JulianDate.centuriesSinceJ2000(jd: jd)
        // Longitude of the mean ascending node of the Moon, degrees.
        let omega = Angle.wrap360(125.04452 - 1934.136261 * t + 0.0020708 * t * t + t * t * t / 450000.0)
        let om = Angle.deg(omega)
        // Arcseconds → degrees (dominant terms only).
        let dPsi = (-17.20 * sin(om) - 1.32 * sin(Angle.deg(280.47 + 36000.77 * t))) / 3600.0
        let dEps = (9.20 * cos(om) + 0.57 * cos(Angle.deg(280.47 + 36000.77 * t))) / 3600.0
        let eps0 = 23.43929111111111 - (46.8150 * t + 0.00059 * t * t - 0.001813 * t * t * t) / 3600.0
        return Nutation(dPsi: dPsi, dEps: dEps, meanObliquity: eps0)
    }

    /// Apply nutation of the equator to a mean-of-date equatorial position.
    func apply(to mean: Equatorial) -> Equatorial {
        let eps = Angle.deg(meanObliquity)
        let ra = Angle.deg(mean.ra)
        let dec = Angle.deg(mean.dec)
        let dpsi = Angle.deg(dPsi)
        let deps = Angle.deg(dEps)
        let cosEps = cos(eps)
        let sinEps = sin(eps)
        let dRA = (cosEps + sinEps * sin(ra) * tan(dec)) * dpsi - cos(ra) * tan(dec) * deps
        let dDec = sinEps * cos(ra) * dpsi + sin(ra) * deps
        return Equatorial(ra: Angle.wrap360(mean.ra + Angle.rad(dRA)),
                          dec: mean.dec + Angle.rad(dDec))
    }
}
