import Foundation
import SQLite3

struct SearchHit: Identifiable, Hashable {
    enum Kind: Hashable { case star, constellation }
    var kind: Kind
    var star: Star?
    var constellation: Constellation?
    var id: String {
        switch kind {
        case .star: return "s-\(star?.hr ?? 0)"
        case .constellation: return "c-\(constellation?.iau ?? "")"
        }
    }
    var title: String {
        star?.displayName ?? constellation?.name ?? ""
    }
    var subtitle: String {
        if let s = star {
            return [s.catalogLabel, s.iau].compactMap { $0 }.joined(separator: " · ")
        }
        return constellation?.genitive ?? ""
    }
}

enum SearchIndex {
    static func search(query: String, catalog: CatalogStore, limit: Int = 40) -> [SearchHit] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 1 else { return [] }
        var hits: [SearchHit] = []
        hits.append(contentsOf: catalog.searchStars(like: q, limit: limit).map {
            SearchHit(kind: .star, star: $0, constellation: nil)
        })
        hits.append(contentsOf: catalog.searchConstellations(like: q).map {
            SearchHit(kind: .constellation, star: nil, constellation: $0)
        })
        return hits
    }
}

extension CatalogStore {
    func searchStars(like query: String, limit: Int) -> [Star] {
        let pattern = "%\(query)%"
        // Try FTS first, then LIKE.
        let fts = queryStars(
            sql: """
            SELECT s.* FROM stars s
            JOIN star_fts f ON f.rowid = s.id
            WHERE star_fts MATCH ?
            ORDER BY s.mag ASC LIMIT ?
            """,
            bind: {
                sqlite3_bind_text($0, 1, ftsQuery(query), -1, SQLITE_TRANSIENT)
                sqlite3_bind_int($0, 2, Int32(limit))
            }
        )
        if !fts.isEmpty { return fts }
        return queryStars(
            sql: """
            SELECT * FROM stars
            WHERE common_name LIKE ? COLLATE NOCASE
               OR bayer LIKE ? COLLATE NOCASE
               OR iau LIKE ? COLLATE NOCASE
               OR printf('HR %d', hr) LIKE ? COLLATE NOCASE
               OR (hip IS NOT NULL AND printf('HIP %d', hip) LIKE ? COLLATE NOCASE)
            ORDER BY mag ASC LIMIT ?
            """,
            bind: {
                sqlite3_bind_text($0, 1, pattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text($0, 2, pattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text($0, 3, pattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text($0, 4, pattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text($0, 5, pattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int($0, 6, Int32(limit))
            }
        )
    }

    func searchConstellations(like query: String) -> [Constellation] {
        let pattern = "%\(query)%"
        return queryConstellations(
            sql: """
            SELECT * FROM constellations
            WHERE name LIKE ? COLLATE NOCASE
               OR iau LIKE ? COLLATE NOCASE
               OR genitive LIKE ? COLLATE NOCASE
            ORDER BY name
            """,
            bind: {
                sqlite3_bind_text($0, 1, pattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text($0, 2, pattern, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text($0, 3, pattern, -1, SQLITE_TRANSIENT)
            }
        )
    }
}

private func ftsQuery(_ raw: String) -> String {
    let cleaned = raw.replacingOccurrences(of: "\"", with: "")
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
    return "\(cleaned)*"
}
