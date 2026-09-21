import XCTest
@testable import UrsaSky

final class AstronomyTests: XCTestCase {

    func testJulianDayJ2000() {
        // 2000 January 1.5 TT = JD 2451545.0 (Meeus)
        let jd = JulianDate.julianDay(year: 2000, month: 1, day: 1.5)
        XCTAssertEqual(jd, 2451545.0, accuracy: 1e-6)
    }

    func testJulianDaySputnik() {
        // Meeus example 7.a: 1957 Oct 4.81 → 2436116.31
        let jd = JulianDate.julianDay(year: 1957, month: 10, day: 4.81)
        XCTAssertEqual(jd, 2436116.31, accuracy: 1e-4)
    }

    func testJulianDayFromDateUTC() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = cal.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 12))!
        XCTAssertEqual(JulianDate.julianDay(from: date), 2451545.0, accuracy: 1e-6)
    }

    func testGMSTMeeus12a() {
        // Meeus example 12.a: 1987 April 10, 0h UT
        let jd = JulianDate.julianDay(year: 1987, month: 4, day: 10.0)
        let gmst = Sidereal.gmstDegrees(jd: jd)
        // Meeus 12.4 continuous formula; example 12.a 0h series is 197.69223°.
        XCTAssertEqual(gmst, 197.69320, accuracy: 0.002)
    }

    func testMeridianAltitude() {
        // Star on the meridian, H = 0: alt = 90° − |lat − dec|
        let eq = Equatorial(ra: 100, dec: 0)
        // Choose JD so LST at lon 0 equals RA 100°: GMST = 100
        // We instead pass longitude so that LMST = RA.
        let jd = 2451545.0
        let gmst = Sidereal.gmstDegrees(jd: jd)
        let lon = Angle.wrap180(eq.ra - gmst)
        let horiz = HorizontalConvert.altAz(
            equatorialJ2000: eq,
            jd: jd,
            latitude: 40,
            longitudeEast: lon,
            applyNutation: false,
            applyRefraction: false
        )
        XCTAssertEqual(horiz.alt, 50.0, accuracy: 0.15)
        XCTAssertEqual(horiz.az, 180.0, accuracy: 1.0) // due south for equatorial star
    }

    func testVegaAltAzFixture() {
        // Vega HR 7001: RA 18h 36m 56.3s = 279.2346°, Dec +38.7836°
        // Observer: 40.0 N, 74.0 W, 2020-06-21 00:00 UTC
        let vega = Equatorial(ra: 279.2346, dec: 38.7836)
        let jd = JulianDate.julianDay(year: 2020, month: 6, day: 21.0)
        let h = HorizontalConvert.altAz(
            equatorialJ2000: vega,
            jd: jd,
            latitude: 40.0,
            longitudeEast: -74.0,
            applyNutation: false,
            applyRefraction: false
        )
        // Precessed to date, HA ≈ −83.8°, alt ≈ 27.89°, az ≈ 61.2° (ENE)
        XCTAssertEqual(h.alt, 27.89, accuracy: 0.25)
        XCTAssertEqual(h.az, 61.22, accuracy: 0.8)
        XCTAssertGreaterThan(h.alt, 0)
        XCTAssertLessThan(h.az, 180)
    }

    func testPrecessionMovesPolaris() {
        let polaris = Equatorial(ra: 37.9546, dec: 89.2641)
        let future = Precession.precess(j2000: polaris, toJD: JulianDate.julianDay(year: 2100, month: 1, day: 1.5))
        // Polaris declination slowly increases toward the pole this century, RA increases.
        XCTAssertGreaterThan(future.ra, polaris.ra)
        XCTAssertGreaterThan(future.dec, 89.2)
    }

    func testNutationAtPoleIsFinite() {
        let pole = Equatorial(ra: 0, dec: 89.95)
        let n = Nutation.at(jd: 2451545.0)
        let eq = n.apply(to: pole)
        XCTAssertTrue(eq.ra.isFinite)
        XCTAssertTrue(eq.dec.isFinite)
        XCTAssertGreaterThan(eq.dec, 89)
        XCTAssertLessThan(eq.dec, 90.01)
    }

    func testSkyGuideBeginnerPhrases() {
        XCTAssertEqual(SkyGuide.phrase(alt: 45, az: 45), "Look northeast, halfway up")
        XCTAssertEqual(SkyGuide.phrase(alt: -5, az: 10), "Below the horizon from here right now.")
        XCTAssertEqual(SkyGuide.compassDirection(0), "north")
        XCTAssertEqual(SkyGuide.compassDirection(90), "east")
        XCTAssertEqual(SkyGuide.compassDirection(180), "south")
        XCTAssertEqual(SkyGuide.compassDirection(270), "west")
        XCTAssertEqual(SkyGuide.heightPhrase(8), "near the horizon")
        XCTAssertEqual(SkyGuide.heightPhrase(80), "nearly overhead")
    }

    func testSceneDirectionAxes() {
        let north = HorizontalConvert.sceneDirection(altAz: Horizontal(alt: 0, az: 0))
        XCTAssertEqual(north.x, 0, accuracy: 1e-5)
        XCTAssertEqual(north.y, 0, accuracy: 1e-5)
        XCTAssertEqual(north.z, -1, accuracy: 1e-5) // north = −Z
        let east = HorizontalConvert.sceneDirection(altAz: Horizontal(alt: 0, az: 90))
        XCTAssertEqual(east.x, 1, accuracy: 1e-5)
        let zenith = HorizontalConvert.sceneDirection(altAz: Horizontal(alt: 90, az: 0))
        XCTAssertEqual(zenith.y, 1, accuracy: 1e-5)
    }

    func testCanopusNeverRisesAt40N() {
        // Canopus, Dec ≈ −52.7°. From 40°N it stays below the horizon.
        let canopus = Equatorial(ra: 95.98796, dec: -52.69566)
        let jd = JulianDate.julianDay(year: 2020, month: 1, day: 1.0)
        var maxAlt = -90.0
        for hour in stride(from: 0.0, through: 23.0, by: 1) {
            let h = HorizontalConvert.altAz(
                equatorialJ2000: canopus,
                jd: jd + hour / 24.0,
                latitude: 40.0,
                longitudeEast: -74.0,
                applyNutation: false,
                applyRefraction: false
            )
            maxAlt = max(maxAlt, h.alt)
        }
        XCTAssertLessThan(maxAlt, 0)
    }

    func testPolarisCircumpolarAt40N() {
        let polaris = Equatorial(ra: 37.9546, dec: 89.2641)
        let h = HorizontalConvert.altAz(
            equatorialJ2000: polaris,
            jd: 2451545.0,
            latitude: 40.0,
            longitudeEast: -74.0,
            applyNutation: false,
            applyRefraction: false
        )
        XCTAssertGreaterThan(h.alt, 20)
    }

    func testTLEParseISS() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "iss", withExtension: "tle"))
        let text = try String(contentsOf: url, encoding: .utf8)
        let tles = TLEParser.parse(text)
        XCTAssertEqual(tles.count, 1)
        let tle = try XCTUnwrap(tles.first)
        XCTAssertEqual(tle.norad, 25544)
        XCTAssertEqual(tle.inclinationDeg, 51.6307, accuracy: 1e-3)
        XCTAssertGreaterThan(tle.meanMotionRevPerDay, 15)
        XCTAssertEqual(tle.epochYear, 2026)
    }

    func testSGP4ISSNearEarthRadius() throws {
        let text = """
        ISS (ZARYA)
        1 25544U 98067A   26263.14255447  .00007470  00000+0  14267-3 0  9991
        2 25544  51.6307 190.1401 0004820 160.6694 199.4478 15.49188396586472
        """
        let tle = try XCTUnwrap(TLEParser.parse(text).first)
        let sgp = try XCTUnwrap(SGP4(tle: tle))
        let state = sgp.propagate(minutesSinceEpoch: 0)
        let r = (state.positionKm.x * state.positionKm.x
                 + state.positionKm.y * state.positionKm.y
                 + state.positionKm.z * state.positionKm.z).squareRoot()
        // ISS ~420 km up → geocentric radius ~6800 km.
        XCTAssertEqual(r, 6800, accuracy: 250)
        XCTAssertNil(SGP4(tle: TLE(
            name: "GEO", line1: "", line2: "", norad: 0, epochYear: 2026, epochDay: 1,
            bstar: 0, inclinationDeg: 0, raanDeg: 0, eccentricity: 0,
            argPerigeeDeg: 0, meanAnomalyDeg: 0, meanMotionRevPerDay: 1.0
        )))
    }
}
