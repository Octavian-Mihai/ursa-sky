import Foundation

struct Constellation: Identifiable, Hashable {
    var iau: String
    var name: String
    var genitive: String
    var mythology: String
    var brightest: String
    var season: String
    var funFact: String
    var tips: String
    var raCent: Double
    var decCent: Double

    var id: String { iau }
}

struct ConstellationLine: Hashable {
    var iau: String
    var starA: Int // HR
    var starB: Int
    var seq: Int
}

struct City: Identifiable, Hashable {
    var name: String
    var country: String
    var latitude: Double
    var longitude: Double
    var timeZoneId: String
    var id: String { "\(name)-\(country)" }
}
