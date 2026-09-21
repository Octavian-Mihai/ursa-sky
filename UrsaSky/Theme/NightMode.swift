import SwiftUI

struct NightPalette {
    var background: Color
    var card: Color
    var primaryText: Color
    var secondaryText: Color
    var accent: Color
    var badge: Color
}

enum NightMode {
    static let dark = NightPalette(
        background: Color(red: 0.04, green: 0.05, blue: 0.08),
        card: Color(red: 0.10, green: 0.11, blue: 0.16),
        primaryText: Color(red: 0.92, green: 0.94, blue: 0.98),
        secondaryText: Color(red: 0.62, green: 0.68, blue: 0.78),
        accent: Color(red: 0.45, green: 0.72, blue: 1.0),
        badge: Color(red: 0.20, green: 0.75, blue: 0.55)
    )
    static let night = NightPalette(
        background: Color(red: 0.08, green: 0.01, blue: 0.01),
        card: Color(red: 0.16, green: 0.04, blue: 0.03),
        primaryText: Color(red: 1.0, green: 0.45, blue: 0.32),
        secondaryText: Color(red: 0.78, green: 0.28, blue: 0.18),
        accent: Color(red: 1.0, green: 0.35, blue: 0.15),
        badge: Color(red: 0.85, green: 0.22, blue: 0.12)
    )
}

struct RedFilterOverlay: View {
    var intensity: Double
    var enabled: Bool

    var body: some View {
        if enabled {
            Rectangle()
                .fill(Color.red)
                .opacity(0.25 + 0.55 * intensity)
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            Rectangle()
                .fill(Color.black.opacity(0.15 + 0.45 * intensity))
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
    }
}
