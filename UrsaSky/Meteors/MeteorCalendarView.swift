import SwiftUI

struct MeteorDetailView: View {
    @EnvironmentObject var app: AppState
    let shower: MeteorShower

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(shower.name).font(.largeTitle.weight(.bold))
                Text(shower.iauCode).foregroundStyle(app.theme.secondaryText)
                TonightCard(equatorial: shower.equatorial)
                Text(shower.notes)
                Text("Parent: \(shower.parent)")
                Text("Active \(shower.start) – \(shower.end), peak \(shower.peak)")
                ExplainedRow(title: "ZHR", value: "\(shower.zhr)", meaning: SkyMeaning.zhr)
                    .padding()
                    .background(app.theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("\(Int(shower.speedKms)) km/s")
                    .foregroundStyle(app.theme.secondaryText)
                ExplainedRow(
                    title: "RA / Dec",
                    value: String(format: "%.1f°  %.1f°", shower.raJ2000, shower.decJ2000),
                    meaning: SkyMeaning.raDec
                )
                .padding()
                .background(app.theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                RadiantOverlay(shower: shower)
                    .frame(height: 180)
            }
            .padding()
        }
        .background(app.theme.background)
        .foregroundStyle(app.theme.primaryText)
        .navigationTitle("Shower")
    }
}
