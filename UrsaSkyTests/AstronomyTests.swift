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
}
