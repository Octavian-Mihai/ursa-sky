import SwiftUI

struct StarDetailView: View {
    @EnvironmentObject var app: AppState
    let star: Star

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(star.displayName)
                    .font(.largeTitle.weight(.bold))
                TonightCard(equatorial: star.equatorial)
                stats
                Text(star.description)
                if let iau = star.iau, let con = app.catalog.constellation(iau: iau) {
                    Button {
                        app.showConstellation(con)
                    } label: {
                        Label(con.name, systemImage: "sparkle")
                    }
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
        VStack(alignment: .leading, spacing: 12) {
            ExplainedRow(title: "Magnitude", value: String(format: "%.2f", star.mag), meaning: SkyMeaning.magnitude)
            ExplainedRow(title: "Spectral type", value: star.spect ?? "—", meaning: SkyMeaning.spectralType)
            ExplainedRow(title: "RA / Dec", value: "\(raString)  \(decString)", meaning: SkyMeaning.raDec)
            ExplainedRow(title: "HR / HIP", value: star.catalogLabel, meaning: SkyMeaning.hrHip)
            if let bayer = star.bayerLabel {
                ExplainedRow(title: "Bayer", value: bayer, meaning: SkyMeaning.bayer)
            }
            if let iau = star.iau {
                ExplainedRow(title: "IAU", value: iau, meaning: SkyMeaning.iau)
            }
            ExplainedRow(
                title: "Distance",
                value: star.distLy.map { String(format: "%.0f ly", $0) } ?? "—",
                meaning: SkyMeaning.ly
            )
        }
        .padding()
        .background(app.theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
}
