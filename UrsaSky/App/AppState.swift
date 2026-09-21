import Foundation
import Combine
import SwiftUI

enum AppTab: Int, Hashable {
    case sky = 0
    case browse = 1
    case settings = 2
}

/// Target the Sky tab should highlight after “Show on Sky”.
enum SkyAim: Equatable {
    case star(hr: Int)
    case constellation(iau: String)
}

@MainActor
final class AppState: ObservableObject {
    let catalog = CatalogStore.shared
    let location = LocationService()
    let clock = SkyClock()
    let attitude = AttitudeFusion()
    let meteors = MeteorCatalog.shared

    @Published var magLimit: Double = 6.0
    @Published var nightVision = false
    @Published var redFilter = false
    @Published var redIntensity: Double = 0.45
    @Published var onlineEnabled = false
    @Published var onboardingComplete: Bool
    @Published var selectedStar: Star?
    @Published var selectedConstellation: Constellation?
    @Published var aimedSky: SkyAim?
    @Published var selectedTab: AppTab = .sky
    @Published var sceneActive = true
    @Published var iss: ISSPredictor
    @Published var tleEpochLabel: String = "bundled"

    private var cancellables = Set<AnyCancellable>()

    var arPaused: Bool { !sceneActive || infoSheetOpen || selectedTab != .sky }

    var infoSheetOpen: Bool { selectedStar != nil || selectedConstellation != nil }

    func showStar(_ star: Star) {
        selectedConstellation = nil
        selectedStar = star
    }

    func showConstellation(_ constellation: Constellation) {
        selectedStar = nil
        selectedConstellation = constellation
    }

    func dismissInfo() {
        selectedStar = nil
        selectedConstellation = nil
    }

    func showOnSky() {
        if let star = selectedStar {
            showOnSky(star: star)
        } else if let constellation = selectedConstellation {
            showOnSky(constellation: constellation)
        } else {
            selectedTab = .sky
        }
    }

    func showOnSky(star: Star) {
        aimedSky = .star(hr: star.hr)
        dismissInfo()
        selectedTab = .sky
    }

    func showOnSky(constellation: Constellation) {
        aimedSky = .constellation(iau: constellation.iau)
        dismissInfo()
        selectedTab = .sky
    }

    func clearSkyAim() {
        aimedSky = nil
    }

    /// Stick-figure IAU to paint in the highlight color (the aimed constellation, or the star’s home).
    var aimedConstellationIAU: String? {
        switch aimedSky {
        case .constellation(let iau):
            return iau
        case .star(let hr):
            return catalog.star(hr: hr)?.iau
        case nil:
            return nil
        }
    }

    func aimedTarget() -> (name: String, equatorial: Equatorial)? {
        switch aimedSky {
        case .star(let hr):
            guard let star = catalog.star(hr: hr) else { return nil }
            return (star.displayName, star.equatorial)
        case .constellation(let iau):
            guard let constellation = catalog.constellation(iau: iau) else { return nil }
            return (constellation.name, constellation.equatorial)
        case nil:
            return nil
        }
    }

    var theme: NightPalette { nightVision ? NightMode.night : NightMode.dark }

    var hasLocation: Bool { location.current != nil }

    var onlineService: any OnlineEnhancementService {
        OnlineToggle.service(enabled: onlineEnabled)
    }

    init() {
        onboardingComplete = UserDefaults.standard.bool(forKey: "ursa.onboarded")
        magLimit = UserDefaults.standard.object(forKey: "ursa.mag") as? Double ?? 6.0
        nightVision = UserDefaults.standard.bool(forKey: "ursa.night")
        redFilter = UserDefaults.standard.bool(forKey: "ursa.red")
        redIntensity = UserDefaults.standard.object(forKey: "ursa.redI") as? Double ?? 0.45
        onlineEnabled = UserDefaults.standard.bool(forKey: "ursa.online")
        let tle = Self.loadBundledTLE() ?? TLEParser.parse(Self.fallbackTLE).first
        iss = ISSPredictor(tle: tle)
        if let tle { tleEpochLabel = tle.epoch.formatted(date: .abbreviated, time: .shortened) }

        // Nested ObservableObjects do not invalidate SwiftUI otherwise, so location
        // and time-travel never rebuilt the sky.
        location.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        clock.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        attitude.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func persist() {
        UserDefaults.standard.set(onboardingComplete, forKey: "ursa.onboarded")
        UserDefaults.standard.set(magLimit, forKey: "ursa.mag")
        UserDefaults.standard.set(nightVision, forKey: "ursa.night")
        UserDefaults.standard.set(redFilter, forKey: "ursa.red")
        UserDefaults.standard.set(redIntensity, forKey: "ursa.redI")
        UserDefaults.standard.set(onlineEnabled, forKey: "ursa.online")
    }

    func finishOnboarding() {
        onboardingComplete = true
        persist()
    }

    func refreshTLEIfOnline() async {
        guard onlineEnabled else { return }
        do {
            if let tle = try await onlineService.refreshISS_TLE() {
                iss.update(tle: tle)
                tleEpochLabel = tle.epoch.formatted(date: .abbreviated, time: .shortened) + " (online)"
            }
        } catch {
            // Keep bundled / last TLE.
        }
    }

    private static func loadBundledTLE() -> TLE? {
        guard let url = Bundle.main.url(forResource: "iss", withExtension: "tle"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return TLEParser.parse(text).first
    }

    static let fallbackTLE = """
    ISS (ZARYA)
    1 25544U 98067A   26263.14255447  .00007470  00000+0  14267-3 0  9991
    2 25544  51.6307 190.1401 0004820 160.6694 199.4478 15.49188396586472
    """
}
