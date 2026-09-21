import Foundation
import simd
import SceneKit

enum Angle {
    static func deg(_ d: Double) -> Double { d * .pi / 180.0 }
    static func rad(_ r: Double) -> Double { r * 180.0 / .pi }
    static func wrap360(_ d: Double) -> Double {
        var x = d.truncatingRemainder(dividingBy: 360.0)
        if x < 0 { x += 360.0 }
        return x
    }
    static func wrap180(_ d: Double) -> Double {
        var x = wrap360(d)
        if x > 180 { x -= 360 }
        return x
    }
}

struct Equatorial: Equatable {
    /// Right ascension in degrees, 0...360
    var ra: Double
    /// Declination in degrees, −90...+90
    var dec: Double

    func unitVector() -> SIMD3<Double> {
        let raR = Angle.deg(ra)
        let decR = Angle.deg(dec)
        let cdec = cos(decR)
        return SIMD3(cdec * cos(raR), cdec * sin(raR), sin(decR))
    }

    static func fromUnit(_ v: SIMD3<Double>) -> Equatorial {
        let n = simd_normalize(v)
        let ra = Angle.wrap360(Angle.rad(atan2(n.y, n.x)))
        let dec = Angle.rad(asin(max(-1, min(1, n.z))))
        return Equatorial(ra: ra, dec: dec)
    }
}

struct Horizontal: Equatable {
    /// Altitude in degrees
    var alt: Double
    /// Azimuth in degrees, 0 = north, 90 = east
    var az: Double
}

enum QuatMath {
    static func slerp(_ a: simd_quatd, _ b: simd_quatd, t: Double) -> simd_quatd {
        simd_slerp(a, b, t)
    }

    static func sceneKit(_ q: simd_quatd) -> SCNQuaternion {
        SCNQuaternion(q.imag.x, q.imag.y, q.imag.z, q.real)
    }
}
