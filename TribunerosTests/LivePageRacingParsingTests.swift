//
//  LivePageRacingParsingTests.swift
//  TribunerosTests
//
//  Pins the PCS live page parser on a real racing page (Il Lombardia 2026, captured 2026-10-10 at
//  about 25% done): the profile, the km axis, the keypoints, the KPI strip and the groups on the road.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class LivePageRacingParsingTests: XCTestCase {
    private func loadPage() throws -> DTO.LivePage {
        guard let url = Bundle(for: type(of: self)).url(forResource: "pcs_live_racing", withExtension: "html") else {
            XCTFail("Missing pcs_live_racing.html fixture in the test bundle")
            throw XCTSkip()
        }
        let html = try String(contentsOf: url, encoding: .utf8)
        let document = try SwiftSoup.parse(html)
        return try XCTUnwrap(Service.parseLivePage(document))
    }

    func testParsesRacingStatusAndKpis() throws {
        let page = try loadPage()

        XCTAssertEqual(page.status, "racing")
        XCTAssertEqual(page.stats.first { $0.label == "KM to go" }?.value, "179.0")
        XCTAssertEqual(page.stats.first { $0.label == "KM done" }?.value, "60.4")
        XCTAssertEqual(page.stats.first { $0.label == "Racetime" }?.value, "1:25:00")
        XCTAssertEqual(page.stats.first { $0.label == "Status" }?.key, "race_status")
    }

    func testParsesRacingProfile() throws {
        let profile = try XCTUnwrap(try loadPage().profile)

        XCTAssertGreaterThan(profile.points.count, 100)
        XCTAssertEqual(profile.progress, 0.252, accuracy: 0.001)
        XCTAssertEqual(profile.routeKm ?? 0, 239.4, accuracy: 0.05)
        XCTAssertEqual(profile.elevationLabels.first, "200")
    }

    func testParsesKeypointsWithClimbs() throws {
        let profile = try XCTUnwrap(try loadPage().profile)

        XCTAssertEqual(profile.keypoints.count, 14)
        XCTAssertEqual(profile.keypoints.first?.name, "Bocche del Gavarno")
        let valcava = try XCTUnwrap(profile.keypoints.first { $0.name == "Passo di Valcava" })
        XCTAssertTrue(valcava.isClimb)
        XCTAssertEqual(valcava.x, 0.36, accuracy: 0.001)
        XCTAssertFalse(profile.keypoints.first { $0.name == "Zogno" }?.isClimb ?? true)
    }

    func testParsesTheKmAxisOnTheRoute() throws {
        let profile = try XCTUnwrap(try loadPage().profile)

        XCTAssertEqual(profile.kmLabels.first?.km, 0)
        XCTAssertEqual(profile.kmLabels.map(\.km).last, 240)
        XCTAssertEqual(profile.kmLabels.count, 25)
        XCTAssertEqual(profile.kmLabels.first { $0.km == 100 }?.x ?? 0, 100 / 239.4, accuracy: 0.001)
    }

    func testParsesTwoGroupsOnTheRoad() throws {
        let page = try loadPage()

        XCTAssertEqual(page.groups.count, 2)

        let breakaway = page.groups[0]
        XCTAssertEqual(breakaway.badge, "1")
        XCTAssertEqual(breakaway.name, "break")
        XCTAssertFalse(breakaway.isPeloton)
        XCTAssertEqual(breakaway.riders.count, 14)
        let leader = try XCTUnwrap(breakaway.riders.first)
        XCTAssertEqual(leader.name, "TIBERI Antonio")
        XCTAssertEqual(leader.bib, "26")
        XCTAssertEqual(leader.countryCode, "it")
        XCTAssertEqual(leader.position, 1)

        let peloton = page.groups[1]
        XCTAssertEqual(peloton.badge, "P")
        XCTAssertEqual(peloton.name, "Peloton")
        XCTAssertTrue(peloton.isPeloton)
        XCTAssertEqual(peloton.gap, "+1:25", "The `??` font is not part of the gap")
        XCTAssertEqual(peloton.gapSeconds, 85)
    }
}
