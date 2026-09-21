import SwiftUI

struct ISSPassList: View {
    @EnvironmentObject var app: AppState
    var latitude: Double
    var longitude: Double
    @State private var passes: [ISSPass] = []
    @State private var loading = true

    var body: some View {
        Group {
            if loading {
                ProgressView("Computing ISS passes…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if passes.isEmpty {
                Text("No passes above 10° in the next 48 hours (bundled TLE).")
                    .font(.caption)
                    .foregroundStyle(app.theme.secondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                List(passes.prefix(8)) { pass in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pass.aos.formatted(date: .abbreviated, time: .shortened))
                        Text(String(format: "Max alt %.0f° · %.0f min", pass.maxAlt, pass.duration / 60))
                            .font(.caption)
                            .foregroundStyle(app.theme.secondaryText)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(app.theme.background)
        .navigationTitle("ISS passes")
        .task(id: recomputeKey) {
            await loadPasses()
        }
    }

    private var recomputeKey: String {
        "\(latitude),\(longitude),\(app.clock.offset),\(app.tleEpochLabel)"
    }

    @MainActor
    private func loadPasses() async {
        loading = true
        let from = app.clock.now()
        let lat = latitude
        let lon = longitude
        let tle = app.iss.tle
        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let predictor = ISSPredictor(tle: tle)
                let passes = predictor.upcomingPasses(
                    from: from,
                    hours: 48,
                    latitude: lat,
                    longitudeEast: lon
                )
                continuation.resume(returning: passes)
            }
        }
        passes = result
        loading = false
    }
}
