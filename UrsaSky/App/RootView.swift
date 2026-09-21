import SwiftUI

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            app.theme.background.ignoresSafeArea()
            if !app.onboardingComplete {
                PermissionOnboarding()
            } else {
                TabView(selection: $app.selectedTab) {
                    SkyTab()
                        .tabItem { Label("Sky", systemImage: "sparkles") }
                        .tag(AppTab.sky)
                    BrowseView()
                        .tabItem { Label("Browse", systemImage: "magnifyingglass") }
                        .tag(AppTab.browse)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(AppTab.settings)
                }
                .tint(app.theme.accent)
            }
        }
        .sheet(isPresented: Binding(
            get: { app.infoSheetOpen },
            set: { if !$0 { app.dismissInfo() } }
        )) {
            NavigationStack {
                if let star = app.selectedStar {
                    StarDetailView(star: star)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { app.dismissInfo() } } }
                } else if let con = app.selectedConstellation {
                    ConstellationDetailView(constellation: con)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { app.dismissInfo() } } }
                }
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
                if app.selectedTab == .sky {
                    SkyARRepresentable(app: app)
                        .ignoresSafeArea()
                } else {
                    app.theme.background.ignoresSafeArea()
                }
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
                if app.aimedSky != nil {
                    SkyAimBanner()
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
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

struct SkyAimBanner: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        if let info = aimInfo {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.subheadline.weight(.semibold))
                    Text(info.phrase)
                        .font(.caption)
                }
                Spacer(minLength: 8)
                Button("Clear highlight") {
                    app.clearSkyAim()
                }
                .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.42))
            .padding(10)
            .background(.black.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var aimInfo: (name: String, phrase: String)? {
        guard let target = app.aimedTarget() else { return nil }
        let phrase: String
        if let loc = app.location.current {
            phrase = SkyGuide.phrase(equatorial: target.equatorial, jd: app.clock.julianDay(), location: loc)
        } else {
            phrase = "Set a location to see which way to look."
        }
        return (target.name, phrase)
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
