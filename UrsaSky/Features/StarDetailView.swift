import SwiftUI

struct StarDetailView: View {
    @EnvironmentObject var app: AppState
    let star: Star

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(star.displayName)
                    .font(.largeTitle.weight(.bold))
                Text(star.catalogLabel)
                    .foregroundStyle(app.theme.secondaryText)
                stats
                Text(star.description)
                if let iau = star.iau, let con = app.catalog.constellation(iau: iau) {
                    Button {
                        app.selectedConstellation = con
                    } label: {
                        Label(con.name, systemImage: "sparkle")
                    }
                }
                if let h = horizontal {
                    Text(String(format: "Now: alt %.1f°  az %.1f°", h.alt, h.az))
                        .font(.body.monospacedDigit())
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(app.theme.background)
        .foregroundStyle(app.theme.primaryText)
        .navigationTitle("Star")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Magnitude", String(format: "%.2f", star.mag))
            row("Spectral type", star.spect ?? "—")
            row("RA J2000", raString)
            row("Dec J2000", decString)
            row("Distance", star.distLy.map { String(format: "%.0f ly", $0) } ?? "—")
            row("Constellation", star.iau ?? "—")
        }
        .padding()
        .background(app.theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(app.theme.secondaryText)
            Spacer()
            Text(v)
        }
    }

    private var raString: String {
        let h = star.raJ2000 / 15
        let hh = Int(h)
        let m = (h - Double(hh)) * 60
        let mm = Int(m)
        let s = (m - Double(mm)) * 60
        return String(format: "%02dh %02dm %04.1fs", hh, mm, s)
    }

    private var decString: String {
        let sign = star.decJ2000 < 0 ? "-" : "+"
        let d = abs(star.decJ2000)
        let dd = Int(d)
        let m = (d - Double(dd)) * 60
        let mm = Int(m)
        let s = (m - Double(mm)) * 60
        return String(format: "%@%02d° %02d′ %02.0f″", sign, dd, mm, s)
    }

    private var horizontal: Horizontal? {
        guard let loc = app.location.current else { return nil }
        return HorizontalConvert.altAz(
            equatorialJ2000: star.equatorial,
            jd: app.clock.julianDay(),
            latitude: loc.latitude,
            longitudeEast: loc.longitude
        )
    }
}
