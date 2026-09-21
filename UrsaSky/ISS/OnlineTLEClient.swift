import Foundation

protocol OnlineEnhancementService {
    var isEnabled: Bool { get }
    func refreshISS_TLE() async throws -> TLE?
}

struct DisabledOnlineEnhancements: OnlineEnhancementService {
    var isEnabled: Bool { false }
    func refreshISS_TLE() async throws -> TLE? { nil }
}

final class CelestrakTLEClient: OnlineEnhancementService {
    var isEnabled: Bool
    private let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=tle")!

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    func refreshISS_TLE() async throws -> TLE? {
        guard isEnabled else { return nil }
        var req = URLRequest(url: url)
        req.setValue("UrsaSky/1.0", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return TLEParser.parse(text).first(where: { $0.norad == 25544 }) ?? TLEParser.parse(text).first
    }
}
