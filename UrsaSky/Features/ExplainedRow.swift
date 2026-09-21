import SwiftUI

enum SkyMeaning {
    static let magnitude = "How bright it looks; smaller is brighter (Sirius is about −1.5; 6 is barely visible)."
    static let spectralType = "Color/heat code (blue-hot O/B, Sun-like G, red-cool M)."
    static let raDec = "The star’s map address on the sky (year 2000)."
    static let hrHip = "ID numbers in the Yale Bright Star and Hipparcos catalogs."
    static let bayer = "Nickname in its constellation; Alpha is usually the brightest."
    static let iau = "Official 3-letter short name (UMa = Ursa Major)."
    static let ly = "Light-years, how far the light has traveled."
    static let altAz = "How high it is, and which compass way to face."
    static let zhr = "Meteors per hour in a perfect dark sky if the shower were overhead; you will see fewer."
    static let tle = "A snapshot of the ISS orbit."
}

struct ExplainedRow: View {
    @EnvironmentObject var app: AppState
    var title: String
    var value: String
    var meaning: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(app.theme.secondaryText)
                Spacer(minLength: 12)
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
            Text(meaning)
                .font(.caption)
                .foregroundStyle(app.theme.secondaryText)
        }
    }
}
