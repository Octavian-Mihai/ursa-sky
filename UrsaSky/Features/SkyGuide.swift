import SwiftUI

/// Beginner-facing “where to look” copy from local altitude and azimuth.
enum SkyGuide {
    static func phrase(alt: Double, az: Double) -> String {
        if alt < 0 {
            return "Below the horizon from here right now."
        }
        return "Look \(compassDirection(az)), \(heightPhrase(alt))"
    }

    static func phrase(equatorial: Equatorial, jd: Double, location: ObserverLocation) -> String {
        let h = horizontal(equatorial: equatorial, jd: jd, location: location)
        return phrase(alt: h.alt, az: h.az)
    }

    static func horizontal(equatorial: Equatorial, jd: Double, location: ObserverLocation) -> Horizontal {
        HorizontalConvert.altAz(
            equatorialJ2000: equatorial,
            jd: jd,
            latitude: location.latitude,
            longitudeEast: location.longitude
        )
    }

    static func compassDirection(_ az: Double) -> String {
        let names = ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
        let wrapped = Angle.wrap360(az)
        let idx = Int((wrapped + 22.5) / 45.0) % 8
        return names[idx]
    }

    static func heightPhrase(_ alt: Double) -> String {
        switch alt {
        case ..<15: return "near the horizon"
        case ..<35: return "a third of the way up"
        case ..<55: return "halfway up"
        case ..<75: return "high in the sky"
        default: return "nearly overhead"
        }
    }

    static func formattedAltAz(_ h: Horizontal) -> String {
        String(format: "%.0f° / %.0f°", h.alt, h.az)
    }
}

/// Live compass/height card plus a control that jumps to the Sky tab.
struct TonightCard: View {
    @EnvironmentObject var app: AppState
    var equatorial: Equatorial

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tonight")
                .font(.headline)
            if let loc = app.location.current {
                let h = SkyGuide.horizontal(equatorial: equatorial, jd: app.clock.julianDay(), location: loc)
                Text(SkyGuide.phrase(alt: h.alt, az: h.az))
                    .font(.body.weight(.semibold))
                ExplainedRow(title: "Alt / Az", value: SkyGuide.formattedAltAz(h), meaning: SkyMeaning.altAz)
            } else {
                Text("Set a location to see which way to look.")
                    .foregroundStyle(app.theme.secondaryText)
            }
            Button {
                app.showOnSky()
            } label: {
                Label("Show on Sky", systemImage: "sparkles")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(app.theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
