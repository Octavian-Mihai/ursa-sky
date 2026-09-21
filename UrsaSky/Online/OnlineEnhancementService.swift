import Foundation

struct EnabledOnlineEnhancements: OnlineEnhancementService {
    var isEnabled: Bool { true }
    private let client: CelestrakTLEClient

    init() {
        client = CelestrakTLEClient(isEnabled: true)
    }

    func refreshISS_TLE() async throws -> TLE? {
        try await client.refreshISS_TLE()
    }
}

enum OnlineToggle {
    static func service(enabled: Bool) -> any OnlineEnhancementService {
        enabled ? EnabledOnlineEnhancements() : DisabledOnlineEnhancements()
    }
}
