import SwiftUI

struct CalendarHubView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Meteor showers") {
                    MeteorCalendarView()
                }
                Section("ISS passes") {
                    if let loc = app.location.current {
                        ISSPassList(latitude: loc.latitude, longitude: loc.longitude)
                    } else {
                        Text("Set a location to predict ISS passes.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(app.theme.background)
            .navigationTitle("Calendar")
        }
    }
}

struct ISSPassList: View {
    @EnvironmentObject var app: AppState
    var latitude: Double
    var longitude: Double
    @State private var passes: [ISSPass] = []

    var body: some View {
        Group {
            if passes.isEmpty {
                Text("No passes above 10° in the next 48 hours (bundled TLE).")
                    .font(.caption)
            } else {
                ForEach(passes.prefix(8)) { p in
                    VStack(alignment: .leading) {
                        Text(p.aos.formatted(date: .abbreviated, time: .shortened))
                        Text(String(format: "Max alt %.0f° · %.0f min", p.maxAlt, p.duration / 60))
                            .font(.caption)
                            .foregroundStyle(app.theme.secondaryText)
                    }
                }
            }
        }
        .onAppear(perform: recompute)
        .onChange(of: latitude) { _, _ in recompute() }
        .onChange(of: longitude) { _, _ in recompute() }
        .onChange(of: app.clock.offset) { _, _ in recompute() }
        .onChange(of: app.tleEpochLabel) { _, _ in recompute() }
    }

    private func recompute() {
        passes = app.iss.upcomingPasses(from: app.clock.now(), hours: 48, latitude: latitude, longitudeEast: longitude)
    }
}
