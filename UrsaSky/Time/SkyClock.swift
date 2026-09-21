import Foundation
import Combine

@MainActor
final class SkyClock: ObservableObject {
    /// Seconds added to the live device clock. Zero means “now”.
    @Published var offset: TimeInterval = 0
    @Published var isLive: Bool = true
    @Published var timeZoneId: String = TimeZone.current.identifier
    /// 0 = hours, 1 = days for the scrubber scale.
    @Published var scrubberUnit: Int = 0

    func now() -> Date {
        Date().addingTimeInterval(offset)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneId) ?? .current
    }

    func resetToNow() {
        offset = 0
        isLive = true
    }

    func julianDay() -> Double {
        JulianDate.julianDay(from: now())
    }
}
