import Foundation

/// Near-Earth SGP4 (Vallado / Spacetrack Report 3). TEME kilometres.
/// Deep-space SDP4 is omitted; ISS-class periods are well under 225 minutes.
struct SGP4 {
    struct State {
        var positionKm: SIMD3<Double>
        var velocityKmS: SIMD3<Double>
    }

    private let ecc0: Double
    private let ao: Double
    private let no: Double
    private let xincl: Double
    private let omegao: Double
    private let xnodeo: Double
    private let xmo: Double
    private let bstar: Double
    private let cosio: Double
    private let sinio: Double
    private let mdot: Double
    private let omgdot: Double
    private let nodedot: Double
    private let c1: Double
    private let c4: Double
    private let c5: Double
    private let d2: Double
    private let d3: Double
    private let d4: Double
    private let t2cof: Double
    private let t3cof: Double
    private let t4cof: Double
    private let t5cof: Double
    private let omgcof: Double
    private let xmcof: Double
    private let delmo: Double
    private let sinmo: Double
    private let nodecf: Double
    private let eta: Double
    private let epoch: Date

    private static let xke = 7.436691004e-2
    private static let qoms24 = 1.88027916e-9
    private static let s = 1.01222928
    private static let ck2 = 5.413080e-4
    static let earthRadiusKm = 6378.135

    init?(tle: TLE) {
        let deg = Double.pi / 180.0
        ecc0 = tle.eccentricity
        xincl = tle.inclinationDeg * deg
        omegao = tle.argPerigeeDeg * deg
        xnodeo = tle.raanDeg * deg
        xmo = tle.meanAnomalyDeg * deg
        bstar = tle.bstar
        epoch = tle.epoch
        let n0 = tle.meanMotionRevPerDay * 2.0 * .pi / 1440.0
        guard ecc0 >= 0, ecc0 < 0.999, n0 > 1e-8 else { return nil }
        // SDP4 (deep space) is omitted; periods ≥ 225 min are not valid here.
        let periodMin = 2.0 * .pi / n0
        guard periodMin < 225 else { return nil }

        cosio = cos(xincl)
        sinio = sin(xincl)
        let theta2 = cosio * cosio
        let con41 = 3 * theta2 - 1

        let a1 = pow(Self.xke / n0, 2.0 / 3.0)
        let delta1 = 1.5 * Self.ck2 * con41 / (a1 * a1)
        let a0 = a1 * (1 - delta1 / 3 - delta1 * delta1 - 134.0 / 81.0 * delta1 * delta1 * delta1)
        let delta0 = 1.5 * Self.ck2 * con41 / (a0 * a0)
        no = n0 / (1 + delta0)
        ao = a0 / (1 - delta0)

        let po = ao * (1 - ecc0 * ecc0)
        let con42 = 1 - 5 * theta2
        mdot = no * (1 + 1.5 * Self.ck2 * con41 / (po * po) * (1 + 1.5 * ecc0 * ecc0))
        omgdot = -0.5 * no * Self.ck2 * con42 / (po * po)
        nodedot = -1.5 * no * Self.ck2 * cosio / (po * po)

        var s4 = Self.s
        let perigeKm = (ao * (1 - ecc0) - 1) * Self.earthRadiusKm
        if perigeKm < 156 {
            var sf = perigeKm - 78
            if perigeKm < 98 { sf = 20 }
            s4 = sf / Self.earthRadiusKm + 1
        }
        let tsi = 1 / (ao - s4)
        let etaVal = ao * ecc0 * tsi
        eta = etaVal
        let etasq = etaVal * etaVal
        let eeta = ecc0 * etaVal
        let psisq = abs(1 - etasq)
        let coef = Self.qoms24 * pow(tsi, 4)
        let coef1 = coef / pow(psisq, 3.5)
        let c2 = coef1 * no * (
            ao * (1 + 1.5 * etasq + eeta * (4 + etasq))
            + 0.75 * Self.ck2 * tsi / psisq * con41 * (8 + 3 * etasq * (8 + etasq))
        )
        c1 = bstar * c2
        let x1mth2 = 1 - theta2
        c4 = 2 * no * coef1 * ao * psisq * (
            eta * (2 + 0.5 * etasq) + ecc0 * (0.5 + 2 * etasq)
            - 2 * Self.ck2 * tsi / (ao * psisq) * (
                -3 * con41 * (1 - 2 * eeta + etasq * (1.5 - 0.5 * eeta))
                + 0.75 * x1mth2 * (2 * etasq - eeta * (1 + etasq)) * cos(2 * omegao)
            )
        )
        c5 = 2 * coef1 * ao * psisq * (1 + 2.75 * (etasq + eeta) + eeta * etasq)
        omgcof = bstar * coef * etaVal * (2 + 2.5 * etasq)
        xmcof = (abs(ecc0) > 1e-4) ? (-2.0 / 3.0 * coef * bstar / eeta) : 0
        nodecf = 3.5 * psisq * nodedot * c1
        sinmo = sin(xmo)
        delmo = pow(1 + etaVal * cos(xmo), 3)

        d2 = 4 * ao * tsi * c1 * c1
        d3 = (4.0 / 3.0) * ao * tsi * tsi * (17 * ao + s4) * c1 * c1 * c1
        d4 = (2.0 / 3.0) * ao * tsi * tsi * tsi * (221 * ao + 31 * s4) * pow(c1, 4)
        t2cof = 1.5 * c1
        t3cof = d2 + 2 * c1 * c1
        t4cof = 0.25 * (3 * d3 + c1 * (12 * d2 + 10 * c1 * c1))
        t5cof = 0.2 * (3 * d4 + 12 * c1 * d3 + 6 * d2 * d2 + 15 * c1 * c1 * (2 * d2 + c1 * c1))
    }

    func propagate(minutesSinceEpoch t: Double) -> State {
        let xmdf = xmo + mdot * t
        let omgadf = omegao + omgdot * t
        let xnoddf = xnodeo + nodedot * t
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t2 * t2
        var tempa = 1 - c1 * t - d2 * t2 - d3 * t3 - d4 * t4
        var tempe = bstar * c4 * t
        let templ = t2cof * t2 + t3cof * t3 + t4cof * t4 + t5cof * t4 * t
        tempa = max(tempa, 0.7)
        tempe += bstar * c5 * (sin(xmdf) - sinmo)
        // `templ` is the drag secular term in mean longitude (Vallado SGP4).
        let mm = xmdf + xmcof * (pow(1 + eta * cos(xmdf), 3) - delmo) + templ
        let omega = omgadf + omgcof * t
        let xnode = xnoddf + nodecf * t2
        let a = ao * tempa * tempa
        var e = ecc0 - tempe
        e = min(max(e, 1e-6), 0.999)

        var ea = mm
        for _ in 0..<12 {
            let f = ea - e * sin(ea) - mm
            let fp = 1 - e * cos(ea)
            if abs(fp) < 1e-12 { break }
            ea -= f / fp
        }
        let r = a * (1 - e * cos(ea))
        let trueAnom = atan2(sqrt(1 - e * e) * sin(ea), cos(ea) - e)
        let u = trueAnom + omega
        let su = sin(u)
        let cu = cos(u)
        let cnode = cos(xnode)
        let snode = sin(xnode)
        let ci = cosio
        let si = sinio
        let ux = cu * cnode - su * snode * ci
        let uy = cu * snode + su * cnode * ci
        let uz = su * si
        let pos = SIMD3(ux, uy, uz) * r * Self.earthRadiusKm

        let p = a * (1 - e * e)
        let rdot = Self.xke * sqrt(a) * e * sin(ea) / max(r, 1e-9)
        let rfdot = Self.xke * sqrt(p) / max(r, 1e-9)
        let vx = rdot * ux + rfdot * (-su * cnode - cu * snode * ci)
        let vy = rdot * uy + rfdot * (-su * snode + cu * cnode * ci)
        let vz = rdot * uz + rfdot * (cu * si)
        let vel = SIMD3(vx, vy, vz) * Self.earthRadiusKm / 60.0
        _ = no
        return State(positionKm: pos, velocityKmS: vel)
    }

    func minutes(since date: Date) -> Double {
        date.timeIntervalSince(epoch) / 60.0
    }
}

enum TEME {
    /// Rotate TEME Earth-fixed-ish using GMST, then observer alt/az.
    static func altAz(positionKm: SIMD3<Double>, jd: Double, latitude: Double, longitudeEast: Double) -> Horizontal {
        let gmst = Angle.deg(Sidereal.gmstDegrees(jd: jd))
        let c = cos(gmst), s = sin(gmst)
        // TEME → PEF (ignore polar motion)
        let x = positionKm.x * c + positionKm.y * s
        let y = -positionKm.x * s + positionKm.y * c
        let z = positionKm.z
        let lat = Angle.deg(latitude)
        let lon = Angle.deg(longitudeEast)
        let re = 6378.137
        let f = 1 / 298.257223563
        let e2 = f * (2 - f)
        let sinLat = sin(lat), cosLat = cos(lat)
        let n = re / sqrt(1 - e2 * sinLat * sinLat)
        let ox = (n) * cosLat * cos(lon)
        let oy = (n) * cosLat * sin(lon)
        let oz = (n * (1 - e2)) * sinLat
        let rx = x - ox, ry = y - oy, rz = z - oz
        let south = sinLat * cos(lon) * rx + sinLat * sin(lon) * ry - cosLat * rz
        let east = -sin(lon) * rx + cos(lon) * ry
        let up = cosLat * cos(lon) * rx + cosLat * sin(lon) * ry + sinLat * rz
        let rng = sqrt(south * south + east * east + up * up)
        let alt = Angle.rad(asin(max(-1, min(1, up / rng))))
        let az = Angle.wrap360(Angle.rad(atan2(east, -south)))
        return Horizontal(alt: alt, az: az)
    }

    static func equatorial(positionKm: SIMD3<Double>) -> Equatorial {
        Equatorial.fromUnit(positionKm)
    }
}
