import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            app.theme.background.ignoresSafeArea()
            if !app.onboardingComplete {
                PermissionOnboarding()
            } else {
                TabView {
                    SkyTab()
                        .tabItem { Label("Sky", systemImage: "sparkles") }
                    BrowseView()
                        .tabItem { Label("Browse", systemImage: "magnifyingglass") }
                    CalendarHubView()
                        .tabItem { Label("Calendar", systemImage: "calendar") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
                .tint(app.theme.accent)
            }
        }
        .sheet(item: $app.selectedStar) { star in
            NavigationStack {
                StarDetailView(star: star)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { app.selectedStar = nil } } }
            }
            .environmentObject(app)
            .preferredColorScheme(.dark)
        }
        .sheet(item: $app.selectedConstellation) { con in
            NavigationStack {
                ConstellationDetailView(constellation: con)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { app.selectedConstellation = nil } } }
            }
            .environmentObject(app)
            .preferredColorScheme(.dark)
        }
        .onChange(of: app.nightVision) { _, _ in app.persist() }
        .onChange(of: app.redFilter) { _, _ in app.persist() }
        .onChange(of: app.redIntensity) { _, _ in app.persist() }
        .onChange(of: app.magLimit) { _, _ in app.persist() }
        .onChange(of: app.onlineEnabled) { _, _ in
            app.persist()
            Task { await app.refreshTLEIfOnline() }
        }
    }
}

struct SkyTab: View {
    @EnvironmentObject var app: AppState
    @State private var dismissedCompassHint = false

    var body: some View {
        ZStack(alignment: .top) {
            if app.hasLocation {
                SkyARRepresentable(app: app)
                    .ignoresSafeArea()
                // Filter the sky only so tab bar / settings stay readable and tappable.
                RedFilterOverlay(intensity: app.redIntensity, enabled: app.redFilter)
            } else {
                LocationRequiredView()
            }
            VStack {
                HStack {
                    OfflineBadge(online: app.onlineEnabled)
                    Spacer()
                    if app.attitude.compassNeedsCalibration, !dismissedCompassHint {
                        Button {
                            dismissedCompassHint = true
                        } label: {
                            Text("Figure-8 the phone to calibrate compass")
                                .font(.caption2)
                                .padding(6)
                                .background(.black.opacity(0.55))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                if let err = app.catalog.loadError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(8)
                }
                Spacer()
                if app.hasLocation {
                    TimeTravelScrubber()
                }
            }
        }
        .onChange(of: app.attitude.magneticAccuracy) { _, acc in
            if acc == .high || acc == .medium {
                dismissedCompassHint = false
            }
        }
    }
}

struct OfflineBadge: View {
    var online: Bool
    var body: some View {
        Text(online ? "Online enhancements" : "Offline Mode")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(online ? Color.orange.opacity(0.85) : Color.green.opacity(0.85))
            .foregroundStyle(.black)
            .clipShape(Capsule())
    }
}

struct LocationRequiredView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.largeTitle)
            Text("Set location")
                .font(.title2.weight(.semibold))
            Text("Sky pointing needs a place on Earth. Use GPS, pick a city, or enter coordinates. GPS itself does not need a network.")
                .multilineTextAlignment(.center)
                .foregroundStyle(app.theme.secondaryText)
                .padding(.horizontal)
            if let err = app.location.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            NavigationStack {
                List {
                    Button("Use GPS") { app.location.requestWhenInUse(); app.location.start() }
                    NavigationLink("Choose a city") { CityPickerView() }
                    NavigationLink("Enter coordinates") { ManualCoordinatesView() }
                }
            }
            .frame(height: 220)
        }
        .padding()
        .foregroundStyle(app.theme.primaryText)
    }
}
