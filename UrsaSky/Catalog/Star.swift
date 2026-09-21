import Foundation

struct Star: Identifiable, Hashable {
    var id: Int
    var hr: Int
    var hip: Int?
    var bayer: String?
    var flamsteed: Int?
    var commonName: String?
    var iau: String?
    var raJ2000: Double
    var decJ2000: Double
    var mag: Double
    var spect: String?
    var distLy: Double?
    var description: String

    var displayName: String {
        if let n = commonName, !n.isEmpty { return n }
        var parts: [String] = []
        if let f = flamsteed { parts.append("\(f)") }
        if let b = bayer { parts.append(greekBayer(b)) }
        if let c = iau { parts.append(c) }
        if parts.isEmpty { return "HR \(hr)" }
        return parts.joined(separator: " ")
    }

    var catalogLabel: String {
        var bits: [String] = ["HR \(hr)"]
        if let hip { bits.append("HIP \(hip)") }
        return bits.joined(separator: " · ")
    }

    var equatorial: Equatorial { Equatorial(ra: raJ2000, dec: decJ2000) }

    /// HR 424 — α UMi, the North Star. Always labeled on the sky overlay.
    static let polarisHR = 424

    var isPolaris: Bool { hr == Self.polarisHR }
}

private func greekBayer(_ code: String) -> String {
    let map: [String: String] = [
        "Alp": "α", "Bet": "β", "Gam": "γ", "Del": "δ", "Eps": "ε",
        "Zet": "ζ", "Eta": "η", "The": "θ", "Iot": "ι", "Kap": "κ",
        "Lam": "λ", "Mu": "μ", "Nu": "ν", "Xi": "ξ", "Omi": "ο",
        "Pi": "π", "Rho": "ρ", "Sig": "σ", "Tau": "τ", "Ups": "υ",
        "Phi": "φ", "Chi": "χ", "Psi": "ψ", "Ome": "ω"
    ]
    let prefix = String(code.prefix(3))
    if let g = map[prefix] {
        return g + code.dropFirst(prefix.count)
    }
    return code
}
