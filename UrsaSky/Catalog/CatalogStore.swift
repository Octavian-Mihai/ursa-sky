import Foundation
import SQLite3

final class CatalogStore {
    static let shared = CatalogStore()

    private var db: OpaquePointer?
    private(set) var isLoaded = false
    private(set) var loadError: String?

    private init() {
        open()
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    private func open() {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "sqlite") else {
            loadError = "catalog.sqlite missing from app bundle"
            return
        }
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
            loadError = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            db = nil
            return
        }
        isLoaded = true
    }

    func star(hr: Int) -> Star? {
        queryStars(sql: "SELECT * FROM stars WHERE hr = ? LIMIT 1", bind: { sqlite3_bind_int($0, 1, Int32(hr)) }).first
    }

    func star(id: Int) -> Star? {
        queryStars(sql: "SELECT * FROM stars WHERE id = ? LIMIT 1", bind: { sqlite3_bind_int($0, 1, Int32(id)) }).first
    }

    func stars(brighterThan mag: Double) -> [Star] {
        queryStars(sql: "SELECT * FROM stars WHERE mag IS NOT NULL AND mag <= ? ORDER BY mag ASC", bind: {
            sqlite3_bind_double($0, 1, mag)
        })
    }

    func constellation(iau: String) -> Constellation? {
        queryConstellations(sql: "SELECT * FROM constellations WHERE iau = ? LIMIT 1", bind: {
            sqlite3_bind_text($0, 1, iau, -1, SQLITE_TRANSIENT)
        }).first
    }

    func allConstellations() -> [Constellation] {
        queryConstellations(sql: "SELECT * FROM constellations ORDER BY name")
    }

    func lines(for iau: String? = nil) -> [ConstellationLine] {
        guard let db else { return [] }
        let sql: String
        if iau == nil {
            sql = "SELECT iau, star_a, star_b, seq FROM constellation_lines ORDER BY iau, seq"
        } else {
            sql = "SELECT iau, star_a, star_b, seq FROM constellation_lines WHERE iau = ? ORDER BY seq"
        }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        if let iau {
            sqlite3_bind_text(stmt, 1, iau, -1, SQLITE_TRANSIENT)
        }
        var rows: [ConstellationLine] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(ConstellationLine(
                iau: stringCol(stmt, 0),
                starA: Int(sqlite3_column_int(stmt, 1)),
                starB: Int(sqlite3_column_int(stmt, 2)),
                seq: Int(sqlite3_column_int(stmt, 3))
            ))
        }
        return rows
    }

    func stars(inConstellation iau: String, limit: Int = 40) -> [Star] {
        queryStars(sql: "SELECT * FROM stars WHERE iau = ? AND mag IS NOT NULL ORDER BY mag ASC LIMIT ?", bind: {
            sqlite3_bind_text($0, 1, iau, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int($0, 2, Int32(limit))
        })
    }
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

extension CatalogStore {
    func queryStars(sql: String, bind: ((OpaquePointer) -> Void)? = nil) -> [Star] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        if let bind, let stmt { bind(stmt) }
        var out: [Star] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(starRow(stmt))
        }
        return out
    }

    func queryConstellations(sql: String, bind: ((OpaquePointer) -> Void)? = nil) -> [Constellation] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        if let bind, let stmt { bind(stmt) }
        var out: [Constellation] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append(Constellation(
                iau: stringCol(stmt, 0),
                name: stringCol(stmt, 1),
                genitive: stringCol(stmt, 2),
                mythology: stringCol(stmt, 3),
                brightest: stringCol(stmt, 4),
                season: stringCol(stmt, 5),
                funFact: stringCol(stmt, 6),
                tips: stringCol(stmt, 7),
                raCent: sqlite3_column_double(stmt, 8),
                decCent: sqlite3_column_double(stmt, 9)
            ))
        }
        return out
    }

    func starRow(_ stmt: OpaquePointer?) -> Star {
        func optInt(_ i: Int32) -> Int? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, i))
        }
        func optStr(_ i: Int32) -> String? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : stringCol(stmt, i)
        }
        func optDbl(_ i: Int32) -> Double? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, i)
        }
        return Star(
            id: Int(sqlite3_column_int(stmt, 0)),
            hr: Int(sqlite3_column_int(stmt, 1)),
            hip: optInt(2),
            bayer: optStr(3),
            flamsteed: optInt(4),
            commonName: optStr(5),
            iau: optStr(6),
            raJ2000: sqlite3_column_double(stmt, 7),
            decJ2000: sqlite3_column_double(stmt, 8),
            mag: optDbl(9) ?? 99,
            spect: optStr(10),
            distLy: optDbl(11),
            description: optStr(12) ?? ""
        )
    }
}

func stringCol(_ stmt: OpaquePointer?, _ i: Int32) -> String {
    guard let c = sqlite3_column_text(stmt, i) else { return "" }
    return String(cString: c)
}
