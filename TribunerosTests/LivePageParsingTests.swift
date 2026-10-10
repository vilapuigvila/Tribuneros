//
//  LivePageParsingTests.swift
//  TribunerosTests
//
//  Pins the PCS live page parser: the pre-race state saved in pcs_preview.html, plus synthetic
//  HTML for a running race (its groups on the road are not in the fixture).
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class LivePageParsingTests: XCTestCase {
    private func loadPage() throws -> DTO.LivePage {
        guard let url = Bundle(for: type(of: self)).url(forResource: "pcs_preview", withExtension: "html") else {
            XCTFail("Missing pcs_preview.html fixture in the test bundle")
            throw XCTSkip()
        }
        let html = try String(contentsOf: url, encoding: .utf8)
        let document = try SwiftSoup.parse(html)
        return try XCTUnwrap(Service.parseLivePage(document))
    }

    func testParsesPreRaceStatusAndStats() throws {
        let page = try loadPage()

        XCTAssertEqual(page.status, "prerace")
        XCTAssertTrue(page.stats.contains { $0.label == "KM to go" && $0.value == "121.2" })
        XCTAssertTrue(page.stats.contains { $0.key == "kmtogo" })
        XCTAssertFalse(
            page.stats.contains { $0.label == "Finish+" },
            "Finish+ reads 0:00:00 before the start, so it is skipped"
        )
    }

    func testParsesProfile() throws {
        let page = try loadPage()
        let profile = try XCTUnwrap(page.profile)

        XCTAssertGreaterThan(profile.points.count, 100)
        XCTAssertTrue(profile.points.allSatisfy { $0.x >= 0 && $0.x <= 1 && $0.y >= 0 && $0.y <= 1 })
        XCTAssertFalse(
            zip(profile.points, profile.points.dropFirst()).contains { previous, next in next.x < previous.x },
            "The profile runs left to right"
        )
        XCTAssertEqual(profile.progress, 0)
        XCTAssertEqual(profile.elevationLabels, ["0", "250"])

        let first = try XCTUnwrap(profile.keypoints.first)
        XCTAssertEqual(first.name, "Ampang")
        XCTAssertEqual(first.type, "1")
        XCTAssertEqual(first.x, 0.042, accuracy: 0.001)
    }

    func testParsesEmptySituationAndTimeline() throws {
        let page = try loadPage()

        XCTAssertTrue(page.groups.isEmpty, "The groups on the road are empty before the start")
        XCTAssertFalse(page.events.isEmpty)

        let first = try XCTUnwrap(page.events.first)
        XCTAssertEqual(first.id, "904976")
        XCTAssertEqual(first.badge, "P")
        XCTAssertTrue(first.text.hasPrefix("Which rider has worn"))
        XCTAssertEqual(first.timestamp, Date(timeIntervalSince1970: 1790851933))
        XCTAssertTrue(first.header.contains("Rider"))
        XCTAssertEqual(first.rows.first, ["1", "GUARDINI Andrea", "9", "27"])
    }

    func testParsesGroupsOnTheRoad() throws {
        let html = """
        <html><body>
        <ul class="ls5b-kpi" data-status="racing">
        <li><span>KM to go</span><div class="kmtogo" data-value="100.0">100.0</div></li>
        <li class="since_finish"><span>Finish+</span><div class="time_since_finish" data-value="0:00:00">0:00:00</div></li>
        </ul>
        <ul class="situ5b">
        <li class="group" data-groupid="1">
        <div class="bol">1</div><h3>BREAK</h3>
        <div class="time">+1:45</div>
        <div class="rider"><span class="bib">101</span><span class="flag it"></span> <a href="rider/luca-rossi">ROSSI Luca</a></div>
        <div class="rider"><span class="bib">117</span><span class="flag nl"></span> <a href="rider/max-de-vries">DE VRIES Max</a></div>
        </li>
        <li class="group" data-groupid="2">
        <div class="bol">P</div>
        <div class="rider"><span class="bib">1</span><span class="flag be"></span> <a href="rider/wout-van-aert">VAN AERT Wout</a></div>
        </li>
        </ul>
        </body></html>
        """
        let document = try SwiftSoup.parse(html)
        let page = try XCTUnwrap(Service.parseLivePage(document))

        XCTAssertEqual(page.status, "racing")
        XCTAssertNil(page.profile)
        XCTAssertEqual(page.groups.count, 2)

        let breakaway = page.groups[0]
        XCTAssertEqual(breakaway.badge, "1")
        XCTAssertEqual(breakaway.name, "BREAK")
        XCTAssertEqual(breakaway.gap, "+1:45")
        XCTAssertEqual(
            breakaway.riders,
            [
                DTO.LivePage.Group.Rider(bib: "101", name: "ROSSI Luca", countryCode: "it"),
                DTO.LivePage.Group.Rider(bib: "117", name: "DE VRIES Max", countryCode: "nl")
            ]
        )

        let peloton = page.groups[1]
        XCTAssertEqual(peloton.badge, "P")
        XCTAssertEqual(peloton.name, "PELOTON")
        XCTAssertEqual(peloton.gap, "")
        XCTAssertEqual(
            peloton.riders,
            [DTO.LivePage.Group.Rider(bib: "1", name: "VAN AERT Wout", countryCode: "be")]
        )
    }

    func testPageWithoutAnchorsParsesToNil() throws {
        let document = try SwiftSoup.parse("<html><body><h1>Nothing here</h1></body></html>")

        XCTAssertNil(Service.parseLivePage(document))
    }
}
