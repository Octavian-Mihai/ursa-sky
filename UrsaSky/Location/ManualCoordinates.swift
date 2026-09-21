import SwiftUI

struct ManualCoordinatesView: View {
    @EnvironmentObject var app: AppState
    @State private var latText = "40.7128"
    @State private var lonText = "-74.0060"
    @State private var tz = TimeZone.current.identifier

    var body: some View {
        Form {
            Section("Latitude") {
                TextField("Degrees north", text: $latText)
                    .keyboardType(.decimalPad)
            }
            Section("Longitude") {
                TextField("Degrees east", text: $lonText)
                    .keyboardType(.decimalPad)
            }
            Section("Time zone") {
                TextField("IANA identifier", text: $tz)
                    .textInputAutocapitalization(.never)
            }
            Button("Use these coordinates") {
                guard let lat = Double(latText), let lon = Double(lonText),
                      lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return }
                app.location.applyManual(latitude: lat, longitude: lon, timeZoneId: tz, label: nil)
                app.clock.timeZoneId = tz
            }
        }
        .scrollContentBackground(.hidden)
        .background(app.theme.background)
        .navigationTitle("Manual location")
        .onAppear {
            if let loc = app.location.current {
                latText = String(format: "%.5f", loc.latitude)
                lonText = String(format: "%.5f", loc.longitude)
                tz = loc.timeZoneId
            }
        }
    }
}
