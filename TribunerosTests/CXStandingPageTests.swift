//
//  CXStandingPageTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class CXStandingPageTests: XCTestCase {

    private func url(_ string: String) -> URL? {
        URL(string: string)
    }

    // MARK: - Id mapping -

    func testStandingIDFromURL() {
        let kind = Service.CxDetailKind.standing
        XCTAssertEqual(kind.collection, "cxStandings")
        XCTAssertEqual(kind.id(for: url("https://cyclocross24.com/uciranking/2025-2026/ME/")), "uciranking~2025-2026~ME")
        XCTAssertEqual(kind.id(for: url("https://cyclocross24.com/standings/superprestige/")), "standings~superprestige")
        XCTAssertEqual(kind.id(for: url("https://cyclocross24.com/standings/superprestige/men-elite")), "standings~superprestige~men-elite")
        XCTAssertEqual(kind.id(for: url("https://cyclocross24.com/uciranking/")), "uciranking")
        XCTAssertEqual(kind.id(for: url("https://www.cyclocross24.com/uciranking/2025-2026/WE/")), "uciranking~2025-2026~WE")
    }

    func testStandingIDRejects() {
        let kind = Service.CxDetailKind.standing
        XCTAssertNil(kind.id(for: nil))
        XCTAssertNil(kind.id(for: url("https://example.com/uciranking/2025-2026/ME/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/rider/wout-van-aert/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/race/18209/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/uciranking/a/b/c/d/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/uciranking/2025_2026/ME/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/standings/a~b/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/standings/\(String(repeating: "a", count: 61))/")))
        XCTAssertNil(kind.id(for: url("https://cyclocross24.com/Standings/superprestige/")))
    }

    func testStandingURLFromID() {
        typealias Kind = Service.CxDetailKind
        XCTAssertEqual(Kind.standingURL(forID: "uciranking~2025-2026~ME"), url("https://cyclocross24.com/uciranking/2025-2026/ME/"))
        XCTAssertEqual(Kind.standingURL(forID: "standings~superprestige"), url("https://cyclocross24.com/standings/superprestige/"))
        XCTAssertNil(Kind.standingURL(forID: "rider~wout-van-aert"))
        XCTAssertNil(Kind.standingURL(forID: "standings~a~b~c~d"))
        XCTAssertNil(Kind.standingURL(forID: "standings~"))
        XCTAssertNil(Kind.standingURL(forID: "standings~a/b"))
        XCTAssertNil(Kind.standingURL(forID: ""))
    }

    func testStandingIDRoundTrips() {
        for id in ["uciranking", "uciranking~2025-2026~MU23", "standings~x2o-trofee~women-elite"] {
            XCTAssertEqual(Service.CxDetailKind.standing.id(for: Service.CxDetailKind.standingURL(forID: id)), id)
        }
    }

    func testExistingKindsIgnoreStandingPaths() {
        let link = url("https://cyclocross24.com/standings/superprestige/")
        XCTAssertNil(Service.CxDetailKind.rider.id(for: link))
        XCTAssertNil(Service.CxDetailKind.race.id(for: link))
        XCTAssertNil(Service.CxDetailKind.results.id(for: link))
    }

    // MARK: - Freshness -

    func testStandingIsFreshFor12Hours() {
        let now = Date()
        let kind = Service.CxDetailKind.standing
        XCTAssertTrue(kind.isFresh(updatedAt: now.addingTimeInterval(-11 * 3600), now: now))
        XCTAssertFalse(kind.isFresh(updatedAt: now.addingTimeInterval(-13 * 3600), now: now))
        XCTAssertFalse(kind.isFresh(updatedAt: nil, now: now))
    }

    // MARK: - Decoding -

    func testDecodesContractDocument() throws {
        let json = """
        {
          "title": "UCI Ranking",
          "categories": [
            {"title": "Men Elite", "url": "https://cyclocross24.com/uciranking/2025-2026/ME/"},
            {"title": "Women Elite", "url": null}
          ],
          "selectedIndex": 0,
          "rows": [
            {"position": 1, "rider": "Thibau Nys", "riderURL": "https://cyclocross24.com/rider/thibau-nys/",
             "countryFlagURL": "https://cyclocross24.com/flags/be.png", "team": "Baloise Glowi Lions", "points": "2850"},
            {"position": 2, "rider": "Some Rider", "riderURL": null, "countryFlagURL": null, "team": null, "points": "2400"}
          ],
          "updatedAt": "ignored"
        }
        """
        let page = try JSONDecoder().decode(DTO.CXStandingPage.self, from: Data(json.utf8))
        XCTAssertEqual(page.title, "UCI Ranking")
        XCTAssertEqual(page.categories.count, 2)
        XCTAssertNil(page.categories[1].url)
        XCTAssertEqual(page.selectedIndex, 0)
        XCTAssertEqual(page.rows.count, 2)
        XCTAssertEqual(page.rows[0].riderURL, url("https://cyclocross24.com/rider/thibau-nys/"))
        XCTAssertEqual(page.rows[0].team, "Baloise Glowi Lions")
        XCTAssertNil(page.rows[1].team)
        XCTAssertEqual(page.rows[1].points, "2400")
    }

    // MARK: - Mock -

    func testMockStandingPageShape() throws {
        let page = try XCTUnwrap(CxMock.detail(.standing, id: "uciranking~2025-2026~WE") as? DTO.CXStandingPage)
        XCTAssertEqual(page.categories.count, 3)
        XCTAssertEqual(page.rows.count, 30)
        XCTAssertEqual(page.selectedIndex, 1)
        XCTAssertEqual(page.rows.map(\.position), Array(1...30))
        XCTAssertEqual(
            page.categories.compactMap { Service.CxDetailKind.standing.id(for: $0.url) },
            ["uciranking~2025-2026~ME", "uciranking~2025-2026~WE", "uciranking~2025-2026~MU23"]
        )
        XCTAssertNotNil(Service.CxDetailKind.rider.id(for: page.rows[25].riderURL))

        XCTAssertEqual(CxMock.standingPage(id: "standings~superprestige").selectedIndex, 0)
        XCTAssertEqual(CxMock.standingPage(id: "standings~superprestige~men-u23").selectedIndex, 2)
    }

    func testMockRiderPageHasTwoSeasons() {
        let results = CxMock.riderPage(id: "mock-rider-one").results
        XCTAssertEqual(results.count, 25)
        XCTAssertEqual(results.first?.race, "Kleeberg Cross Mechelen")
        XCTAssertEqual(results.first?.position, "2")
        XCTAssertTrue(results.allSatisfy { $0.date.wholeMatch(of: /\d{2}-\d{2}-\d{4}/) != nil })
        XCTAssertTrue(results.contains { $0.date.hasSuffix("-2024") })
    }
}
