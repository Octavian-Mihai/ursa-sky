import SwiftUI

/// A simple polar sketch of the radiant relative to the local horizon.
struct RadiantOverlay: View {
    @EnvironmentObject var app: AppState
    var shower: MeteorShower

    var body: some View {
        GeometryReader { geo in
            let h = altaz
            ZStack {
                Circle().stroke(app.theme.secondaryText.opacity(0.4))
                Circle().stroke(app.theme.secondaryText.opacity(0.2)).padding(geo.size.width * 0.18)
                Text("N").font(.caption2).offset(y: -(geo.size.height / 2) + 8)
                if let h, h.alt > 0 {
                    let span = min(geo.size.width, geo.size.height)
                    let r = CGFloat((90.0 - h.alt) / 90.0) * (span / 2 - 12)
                    let az = Angle.deg(h.az)
                    let x = CGFloat(sin(az)) * r
                    let y = CGFloat(-cos(az)) * r
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 14, height: 14)
                        .offset(x: x, y: y)
                    Text(shower.name)
                        .font(.caption2)
                        .offset(x: x, y: y + 16)
                } else {
                    Text("Radiant below horizon")
                        .font(.caption)
                        .foregroundStyle(app.theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .background(app.theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var altaz: Horizontal? {
        guard let loc = app.location.current else { return nil }
        return HorizontalConvert.altAz(
            equatorialJ2000: shower.equatorial,
            jd: app.clock.julianDay(),
            latitude: loc.latitude,
            longitudeEast: loc.longitude
        )
    }
}
