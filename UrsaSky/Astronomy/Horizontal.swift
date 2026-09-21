import Foundation

/// Equatorial → horizontal conversion, Meeus chapter 13, with optional refraction.
enum HorizontalConvert {
    /// Convert mean J2000 equatorial coordinates to altitude/azimuth.
    /// Azimuth is measured from north toward east.
    /// Longitude is east-positive. Latitude north-positive.
    static func altAz(
        equatorialJ2000: Equatorial,
        jd: Double,
        latitude: Double,
        longitudeEast: Double,
        applyNutation: Bool = true,
        applyRefraction: Bool = true
    ) -> Horizontal {
        let mean = Precession.precess(j2000: equatorialJ2000, toJD: jd)
        let eq = applyNutation ? Nutation.at(jd: jd).apply(to: mean) : mean
        let lst = Sidereal.lmstDegrees(jd: jd, longitudeEast: longitudeEast)
        let h = Angle.deg(Angle.wrap180(lst - eq.ra)) // hour angle
        let lat = Angle.deg(latitude)
        let dec = Angle.deg(eq.dec)
        let sinAlt = sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(h)
        var alt = Angle.rad(asin(max(-1, min(1, sinAlt))))
        let y = -sin(h) * cos(dec)
        let x = sin(dec) * cos(lat) - cos(dec) * sin(lat) * cos(h)
        let az = Angle.wrap360(Angle.rad(atan2(y, x)))
        if applyRefraction {
            alt += refraction(altDegrees: alt)
        }
        return Horizontal(alt: alt, az: az)
    }

    /// Saemundsson refraction in degrees. Input altitude in degrees.
    static func refraction(altDegrees: Double) -> Double {
        if altDegrees < -1 { return 0 }
        let h = max(altDegrees, -0.9)
        let rArcmin = 1.02 / tan(Angle.deg(h + 10.3 / (h + 5.11)))
        return rArcmin / 60.0
    }

    /// SceneKit ENU-ish direction: +X east, +Y up, +Z south (north = −Z).
    static func sceneDirection(altAz: Horizontal) -> SIMD3<Float> {
        let alt = Angle.deg(altAz.alt)
        let az = Angle.deg(altAz.az)
        let cAlt = cos(alt)
        let x = Float(cAlt * sin(az))
        let y = Float(sin(alt))
        let z = Float(-cAlt * cos(az))
        return SIMD3(x, y, z)
    }
}
