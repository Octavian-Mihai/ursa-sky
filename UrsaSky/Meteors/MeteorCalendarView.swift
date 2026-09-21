import SwiftUI

struct MeteorCalendarView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ForEach(app.meteors.sortedForCalendar(around: app.clock.now())) { s in
            NavigationLink {
                MeteorDetailView(shower: s)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(s.name)
                        Text("Peak \(s.peak) · ZHR \(s.zhr)")
                            .font(.caption)
                            .foregroundStyle(app.theme.secondaryText)
                    }
                    Spacer()
                    if s.isActive(on: app.clock.now()) {
                        Text("Active")
                            .font(.caption2.weight(.bold))
                            .padding(4)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

struct MeteorDetailView: View {
    @EnvironmentObject var app: AppState
    let shower: MeteorShower

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(shower.name).font(.largeTitle.weight(.bold))
                Text(shower.iauCode).foregroundStyle(app.theme.secondaryText)
                Text(shower.notes)
                Text("Parent: \(shower.parent)")
                Text("Active \(shower.start) – \(shower.end), peak \(shower.peak)")
                Text("ZHR \(shower.zhr) · \(Int(shower.speedKms)) km/s")
                Text(String(format: "Radiant  RA %.1f°  Dec %.1f°", shower.raJ2000, shower.decJ2000))
                if let loc = app.location.current {
                    let h = HorizontalConvert.altAz(
                        equatorialJ2000: shower.equatorial,
                        jd: app.clock.julianDay(),
                        latitude: loc.latitude,
                        longitudeEast: loc.longitude
                    )
                    Text(String(format: "Radiant now  alt %.0f°  az %.0f°", h.alt, h.az))
                }
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
