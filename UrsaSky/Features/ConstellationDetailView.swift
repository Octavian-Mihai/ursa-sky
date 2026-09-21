import SwiftUI

struct ConstellationDetailView: View {
    @EnvironmentObject var app: AppState
    let constellation: Constellation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(constellation.name)
                    .font(.largeTitle.weight(.bold))
                Text("\(constellation.genitive) · \(constellation.season)")
                    .foregroundStyle(app.theme.secondaryText)
                ExplainedRow(title: "IAU", value: constellation.iau, meaning: SkyMeaning.iau)
                    .padding()
                    .background(app.theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                TonightCard(equatorial: constellation.equatorial)
                group("How to find it", constellation.tips)
                Text(constellation.mythology)
                group("Brightest", constellation.brightest)
                group("Aside", constellation.funFact)
                Text("Bright members")
                    .font(.headline)
                ForEach(app.catalog.stars(inConstellation: constellation.iau, limit: 12)) { star in
                    Button {
                        app.showStar(star)
                    } label: {
                        HStack {
                            Text(star.displayName)
                            Spacer()
                            Text(String(format: "mag %.2f", star.mag))
                                .foregroundStyle(app.theme.secondaryText)
                        }
                    }
                    .foregroundStyle(app.theme.primaryText)
                }
            }
            .padding()
        }
        .background(app.theme.background)
        .foregroundStyle(app.theme.primaryText)
        .navigationTitle("Constellation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(app.theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
