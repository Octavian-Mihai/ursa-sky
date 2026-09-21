import XCTest
@testable import UrsaSky

final class CatalogTests: XCTestCase {

    func testCatalogLoadsFromBundle() {
        XCTAssertTrue(CatalogStore.shared.isLoaded, CatalogStore.shared.loadError ?? "catalog missing")
        let vega = CatalogStore.shared.star(hr: 7001)
        XCTAssertNotNil(vega)
        XCTAssertEqual(vega?.commonName?.lowercased(), "vega")
        XCTAssertEqual(vega?.raJ2000 ?? 0, 279.23, accuracy: 0.05)
    }

    func testPolarisIsNamedAndIdentifiable() {
        let polaris = CatalogStore.shared.star(hr: Star.polarisHR)
        XCTAssertNotNil(polaris)
        XCTAssertTrue(polaris?.isPolaris == true)
        XCTAssertEqual(polaris?.commonName, "Polaris")
        XCTAssertEqual(polaris?.iau, "UMi")
    }

    func testSearchFindsNamedStarAndConstellation() {
        let hits = SearchIndex.search(query: "vega", catalog: CatalogStore.shared)
        XCTAssertTrue(hits.contains { $0.star?.hr == 7001 }, "expected Vega in \(hits.map(\.title))")

        let orion = SearchIndex.search(query: "orion", catalog: CatalogStore.shared)
        XCTAssertTrue(orion.contains { $0.constellation?.iau == "Ori" })
    }

    func testSearchSurvivesFTSSpecialCharacters() {
        let hits = SearchIndex.search(query: "HR 7001", catalog: CatalogStore.shared)
        XCTAssertTrue(hits.contains { $0.star?.hr == 7001 })
        // Must not crash or throw on FTS operators; LIKE fallback should still find Vega.
        let junk = SearchIndex.search(query: "AND OR * \"vega\"", catalog: CatalogStore.shared)
        XCTAssertTrue(junk.contains { $0.star?.commonName?.lowercased() == "vega" } || junk.contains { $0.star?.hr == 7001 })
    }

    func testLacertaStickFigureComplete() {
        let lines = CatalogStore.shared.lines(for: "Lac")
        XCTAssertEqual(lines.count, 5)
        let hrs = Set(lines.flatMap { [$0.starA, $0.starB] })
        XCTAssertTrue(hrs.contains(8585)) // α Lac
        XCTAssertTrue(hrs.contains(8538)) // β Lac
        XCTAssertTrue(hrs.contains(8541)) // 4 Lac (was unmatched γ)
    }

    func testCitiesLoad() {
        let cities = CityStore.load()
        XCTAssertGreaterThan(cities.count, 50)
        XCTAssertTrue(cities.contains { $0.name == "Boston" })
    }
}
