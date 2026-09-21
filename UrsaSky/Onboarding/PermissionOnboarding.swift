import SwiftUI

struct PermissionOnboarding: View {
    @EnvironmentObject var app: AppState
    @State private var page = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: icons[page])
                .font(.system(size: 56))
                .foregroundStyle(app.theme.accent)
            Text(titles[page])
                .font(.largeTitle.weight(.bold))
            Text(bodies[page])
                .multilineTextAlignment(.center)
                .foregroundStyle(app.theme.secondaryText)
                .padding(.horizontal, 28)
            Spacer()
            HStack {
                if page == 2 {
                    Button("Skip location") {
                        app.finishOnboarding()
                    }
                    .foregroundStyle(app.theme.secondaryText)
                }
                Spacer()
                Button(page == 2 ? "Continue" : "Allow") {
                    switch page {
                    case 0:
                        page = 1
                    case 1:
                        page = 2
                    default:
                        app.location.requestWhenInUse()
                        app.finishOnboarding()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
        .background(app.theme.background.ignoresSafeArea())
        .foregroundStyle(app.theme.primaryText)
    }

    private var titles: [String] { ["Camera", "Motion", "Location"] }
    private var icons: [String] { ["camera", "gyroscope", "location"] }
    private var bodies: [String] {
        [
            "Ursa Sky overlays the catalog on a live camera view. The camera is used only to show the sky behind the stars — nothing is uploaded.",
            "Device motion aims the star sphere. A figure-8 motion calibrates the compass if the overlay looks twisted.",
            "A position on Earth turns right ascension into altitude. GPS works offline; you can skip and pick a city later."
        ]
    }
}
