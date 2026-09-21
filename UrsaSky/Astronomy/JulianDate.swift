import Foundation

/// Julian Day numbers from *Astronomical Algorithms* (Meeus), chapter 7.
enum JulianDate {
    /// Julian Day for a calendar date. `day` may be fractional (0h = midnight).
    /// Gregorian proleptic for dates on or after 1582 Oct 15.
    static func julianDay(year: Int, month: Int, day: Double) -> Double {
        var y = Double(year)
        var m = Double(month)
        if m <= 2 {
            y -= 1
            m += 12
        }
        let gregorian = year > 1582 || (year == 1582 && (month > 10 || (month == 10 && day >= 15)))
        var b = 0.0
        if gregorian {
            let a = floor(y / 100.0)
            b = 2 - a + floor(a / 4.0)
        }
        return floor(365.25 * (y + 4716.0)) + floor(30.6001 * (m + 1.0)) + day + b - 1524.5
    }

    /// Julian Day from a Foundation `Date`, interpreted in UTC.
    static func julianDay(from date: Date) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        let day = Double(c.day ?? 1)
            + Double(c.hour ?? 0) / 24.0
            + Double(c.minute ?? 0) / 1440.0
            + Double(c.second ?? 0) / 86400.0
            + Double(c.nanosecond ?? 0) / 8.64e13
        return julianDay(year: c.year ?? 2000, month: c.month ?? 1, day: day)
    }

    static func date(fromJulianDay jd: Double) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var z = Int(floor(jd + 0.5))
        let f = jd + 0.5 - Double(z)
        var a = z
        if z >= 2299161 {
            let alpha = Int(floor((Double(z) - 1867216.25) / 36524.25))
            a = z + 1 + alpha - alpha / 4
        }
        let b = a + 1524
        let c = Int(floor((Double(b) - 122.1) / 365.25))
        let d = Int(floor(365.25 * Double(c)))
        let e = Int(floor(Double(b - d) / 30.6001))
        let dayFrac = Double(b - d - Int(floor(30.6001 * Double(e)))) + f
        let month = e < 14 ? e - 1 : e - 13
        let year = month > 2 ? c - 4716 : c - 4715
        let day = Int(floor(dayFrac))
        let rem = (dayFrac - Double(day)) * 24
        let hour = Int(floor(rem))
        let remM = (rem - Double(hour)) * 60
        let minute = Int(floor(remM))
        let second = (remM - Double(minute)) * 60
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = Int(floor(second))
        comps.nanosecond = Int((second - floor(second)) * 1e9)
        return cal.date(from: comps) ?? Date(timeIntervalSince1970: (jd - 2440587.5) * 86400)
    }

    /// Julian centuries from J2000.0 TT ≈ UTC for our purposes.
    static func centuriesSinceJ2000(jd: Double) -> Double {
        (jd - 2451545.0) / 36525.0
    }
}
