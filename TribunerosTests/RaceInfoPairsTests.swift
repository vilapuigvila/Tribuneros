//
//  RaceInfoPairsTests.swift
//  TribunerosTests
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class RaceInfoPairsTests: XCTestCase {
    func testReadsTheLineh16Layout() throws {
        let html = """
        <div class="lineh16"><div class="bold mr5">Date</div><div class="">8 October 2026</div><br />\
        <div class="bold mr5">Start time: </div><div class="">12:10:00</div><br />\
        <div class="bold mr5">Distance:</div><div class="mr3">185</div><div class="">km</div><br />\
        <div class="bold mr5">Race category: </div><div class="">ME</div><br /></div>
        """
        let pairs = try Service.raceInfoPairs(SwiftSoup.parse(html))

        XCTAssertEqual(pairs.first { $0.key.hasPrefix("Start time") }?.value, "12:10:00")
        XCTAssertEqual(pairs.first { $0.key.hasPrefix("Distance") }?.value, "185 km")
        XCTAssertEqual(pairs.first { $0.key.hasPrefix("Race category") }?.value, "ME")
        XCTAssertEqual(pairs.first { $0.key == "Date" }?.value, "8 October 2026")
    }

    func testReadsTheListLayout() throws {
        let html = """
        <ul class="infolist"><li><div>Start time:</div><div>13:05 (13:05 CEST)</div></li>\
        <li><div>Departure:</div><div>Zagreb</div></li></ul>
        """
        let pairs = try Service.raceInfoPairs(SwiftSoup.parse(html))

        XCTAssertEqual(pairs.first { $0.key.hasPrefix("Start time") }?.value, "13:05 (13:05 CEST)")
        XCTAssertEqual(pairs.first { $0.key.hasPrefix("Departure") }?.value, "Zagreb")
    }

    func testSiteStartTimeDropsSeconds() {
        XCTAssertEqual(HomeRaces.TodayRaces.siteStartTime("12:10:00"), "12:10")
    }
}
