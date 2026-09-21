import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        NavigationStack {
            Form {
                Section("Sky") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Magnitude limit  \(app.magLimit, specifier: "%.1f")")
                        Slider(value: $app.magLimit, in: 3...7, step: 0.5)
                        Text(SkyMeaning.magnitude)
                            .font(.caption)
                            .foregroundStyle(app.theme.secondaryText)
                    }
                }

                Section("Night vision") {
                    Toggle("Night palette (red chrome)", isOn: $app.nightVision)
                    Toggle("Red filter overlay", isOn: $app.redFilter)
                    if app.redFilter {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dim  \(Int(app.redIntensity * 100))%")
                            Slider(value: $app.redIntensity, in: 0...1)
                        }
                    }
                }

                Section("Location") {
                    if let loc = app.location.current {
                        Text(loc.label)
                        Text(String(format: "%.4f, %.4f · %@", loc.latitude, loc.longitude, loc.source.rawValue))
                            .font(.caption)
                            .foregroundStyle(app.theme.secondaryText)
                    } else {
                        Text("No location set")
                    }
                    if let err = app.location.lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button("Refresh GPS") {
                        app.location.requestWhenInUse()
                        app.location.start()
                    }
                    NavigationLink("City picker") {
                        CityPickerView()
                    }
                    NavigationLink("Manual coordinates") {
                        ManualCoordinatesView()
                    }
                }

                Section("ISS") {
                    if let loc = app.location.current {
                        NavigationLink("ISS passes") {
                            ISSPassList(latitude: loc.latitude, longitude: loc.longitude)
                        }
                    } else {
                        Text("Set a location to predict ISS passes.")
                    }
                    Text(SkyMeaning.tle)
                        .font(.caption)
                        .foregroundStyle(app.theme.secondaryText)
                }

                Section("Online") {
                    Toggle("Online enhancements (ISS TLE refresh)", isOn: $app.onlineEnabled)
                    Text("Core sky, search, and details never need a network. A-GPS assist and fresh TLEs run only when this is on.")
                        .font(.caption)
                    Text("ISS TLE epoch: \(app.tleEpochLabel)")
                        .font(.caption)
                }

                Section("About") {
                    Text("Ursa Sky is an offline AR planetarium. Catalog: Yale BSC5 (public domain). Stick figures authored as HR/HIP pairs (not Stellarium). Cities: GeoNames CC-BY. SGP4 after Vallado. No analytics.")
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(app.theme.background)
            .navigationTitle("Settings")
        }
    }
}
