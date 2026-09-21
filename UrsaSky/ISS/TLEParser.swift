import Foundation

struct TLE: Equatable {
    var name: String
    var line1: String
    var line2: String
    var norad: Int
    var epochYear: Int
    var epochDay: Double
    var bstar: Double
    var inclinationDeg: Double
    var raanDeg: Double
    var eccentricity: Double
    var argPerigeeDeg: Double
    var meanAnomalyDeg: Double
    var meanMotionRevPerDay: Double

    var epoch: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = cal.date(from: DateComponents(year: epochYear, month: 1, day: 1))!
        return start.addingTimeInterval((epochDay - 1.0) * 86400)
    }
}

enum TLEParser {
    static func parse(_ text: String) -> [TLE] {
        let lines = text
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var out: [TLE] = []
        var i = 0
        while i < lines.count {
            var name = "SAT"
            var l1: String?
            var l2: String?
            if lines[i].hasPrefix("1 ") {
                l1 = lines[i]
                if i + 1 < lines.count { l2 = lines[i + 1] }
                i += 2
            } else if i + 1 < lines.count, lines[i + 1].hasPrefix("1 ") {
                name = lines[i]
                l1 = lines[i + 1]
                if i + 2 < lines.count { l2 = lines[i + 2] }
                i += 3
            } else {
                i += 1
                continue
            }
            if let l1, let l2, l2.hasPrefix("2 "), let tle = decode(name: name, l1: l1, l2: l2) {
                out.append(tle)
            }
        }
        return out
    }

    static func decode(name: String, l1: String, l2: String) -> TLE? {
        guard l1.count >= 69, l2.count >= 69 else { return nil }
        let norad = Int(l1.dropFirst(2).prefix(5).trimmingCharacters(in: .whitespaces)) ?? 0
        let year2 = Int(slice(l1, 18, 20)) ?? 0
        let epochYear = year2 < 57 ? 2000 + year2 : 1900 + year2
        let epochDay = Double(slice(l1, 20, 32)) ?? 1
        let bstar = scientific(slice(l1, 53, 61))
        let inc = Double(slice(l2, 8, 16)) ?? 0
        let raan = Double(slice(l2, 17, 25)) ?? 0
        let ecc = Double("0." + slice(l2, 26, 33).trimmingCharacters(in: .whitespaces)) ?? 0
        let argp = Double(slice(l2, 34, 42)) ?? 0
        let m = Double(slice(l2, 43, 51)) ?? 0
        let n = Double(slice(l2, 52, 63)) ?? 0
        return TLE(name: name, line1: l1, line2: l2, norad: norad, epochYear: epochYear, epochDay: epochDay,
                   bstar: bstar, inclinationDeg: inc, raanDeg: raan, eccentricity: ecc,
                   argPerigeeDeg: argp, meanAnomalyDeg: m, meanMotionRevPerDay: n)
    }

    private static func slice(_ s: String, _ a: Int, _ b: Int) -> String {
        let start = s.index(s.startIndex, offsetBy: min(a, s.count))
        let end = s.index(s.startIndex, offsetBy: min(b, s.count))
        return String(s[start..<end])
    }

    /// TLE BSTAR field: ±xxxxx±y meaning mantissa * 10^(exp-5) typically ±12345-3
    private static func scientific(_ field: String) -> Double {
        let t = field.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2 else { return 0 }
        var s = t
        if s.first == " " { s.removeFirst() }
        // Insert missing decimal: " 12345-3" → 0.12345e-3
        if let eIdx = s.lastIndex(where: { $0 == "+" || $0 == "-" }), eIdx != s.startIndex {
            let mant = String(s[s.startIndex..<eIdx])
            let exp = String(s[eIdx...])
            let sign: Double = mant.first == "-" ? -1 : 1
            let digits = mant.filter(\.isNumber)
            let val = (Double(digits) ?? 0) / pow(10.0, Double(digits.count))
            let e = Double(exp) ?? 0
            return sign * val * pow(10.0, e)
        }
        return Double(s) ?? 0
    }
}
