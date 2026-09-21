import Foundation
import SceneKit
import simd

enum HitTester {
    static func nearestStar(
        tap: CGPoint,
        in view: SCNView,
        stars: [Star],
        jd: Double,
        latitude: Double,
        longitude: Double,
        magLimit: Double,
        maxDegrees: Double = 2.2
    ) -> Star? {
        let near = SCNVector3(Float(tap.x), Float(tap.y), 0)
        let far = SCNVector3(Float(tap.x), Float(tap.y), 1)
        let p0 = view.unprojectPoint(near)
        let p1 = view.unprojectPoint(far)
        let origin = SIMD3<Double>(Double(p0.x), Double(p0.y), Double(p0.z))
        let dest = SIMD3<Double>(Double(p1.x), Double(p1.y), Double(p1.z))
        var dir = dest - origin
        let len = simd_length(dir)
        guard len > 0 else { return nil }
        dir /= len

        var best: Star?
        var bestAng = maxDegrees
        for star in stars where star.mag <= magLimit {
            let h = HorizontalConvert.altAz(
                equatorialJ2000: star.equatorial,
                jd: jd,
                latitude: latitude,
                longitudeEast: longitude
            )
            let d = HorizontalConvert.sceneDirection(altAz: h)
            let v = SIMD3<Double>(Double(d.x), Double(d.y), Double(d.z))
            let ang = Angle.rad(acos(max(-1, min(1, simd_dot(simd_normalize(v), dir)))))
            let limit = maxDegrees + max(0, (3.5 - star.mag) * 0.25)
            if ang < bestAng && ang < limit {
                bestAng = ang
                best = star
            }
        }
        return best
    }
}
