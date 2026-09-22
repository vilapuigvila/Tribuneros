//
//  RequesterHomeParsingTests.swift
//  TribunerosTests
//
//  Pins the ProCyclingStats homepage markup (as captured in pcs_real.html) so a future
//  redesign of that page fails these tests loudly instead of silently returning empty sections.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class RequesterHomeParsingTests: XCTestCase {
    private func loadFixtureDocument() throws -> Document {
        guard let url = Bundle(for: type(of: self)).url(forResource: "pcs_real", withExtension: "html") else {
            XCTFail("Missing pcs_real.html fixture in the test bundle")
            throw XCTSkip()
        }
        let html = try String(contentsOf: url, encoding: .utf8)
        return try SwiftSoup.parse(html)
    }

    private func matchesTime(_ value: String) -> Bool {
        value.range(of: "^([01]\\d|2[0-3]):[0-5]\\d$", options: .regularExpression) != nil
    }

    private func matchesTwoLetterCode(_ value: String) -> Bool {
        value.range(of: "^[a-z]{2}$", options: .regularExpression) != nil
    }

    // MARK: - Next to finish

    func testNextToFinishParsesRealMarkup() throws {
        let document = try loadFixtureDocument()
        let results = Service.parseNextToFinishResults(document)

        XCTAssertFalse(results.isEmpty, "Expected at least one 'next to finish' race")

        let match = results.first { result in
            matchesTime(result.eta)
                && !result.name.isEmpty
                && matchesTwoLetterCode(result.flagCode)
                && result.urlPath.hasPrefix("https://www.procyclingstats.com/race/")
                && result.distance.isEmpty
        }
        XCTAssertNotNil(match, "Expected a row matching eta/name/flagCode/urlPath/distance shape. Got: \(results)")
    }

    // MARK: - Results yesterday

    func testResultsYesterdayParsesRealMarkup() throws {
        let document = try loadFixtureDocument()
        let results = try Service.parseResultsYesterday(document)

        XCTAssertFalse(results.isEmpty, "Expected at least one 'results yesterday' race")

        let match = results.first { result in
            !result.raceName.isEmpty
                && result.winner != nil
                && result.podium.count == 3
                && result.podium.allSatisfy { !$0.name.isEmpty && !$0.time.isEmpty }
        }
        XCTAssertNotNil(match, "Expected a race with non-empty name, winner image and a 3-entry podium. Got: \(results)")
    }

    // MARK: - Races tomorrow

    func testRacesTomorrowParsesRealMarkup() throws {
        let document = try loadFixtureDocument()
        let results = Service.parseRacesTomorrow(from: document)

        XCTAssertFalse(results.isEmpty, "Expected at least one 'races tomorrow' entry")

        let match = results.first { result in
            matchesTime(result.startTime) && matchesTime(result.eta) && !result.raceName.isEmpty
        }
        XCTAssertNotNil(match, "Expected a row with HH:mm startTime/eta and a race name. Got: \(results)")
    }

    // MARK: - Results today

    func testResultsTodayReturnsEmptyWithoutThrowingOnRealMarkup() throws {
        // The fixture was captured on a day with "No results (yet)." for today. The markup leaves
        // the today <ul class="hp2-results"> unclosed in that case, nesting "Results yesterday"'s
        // heading and list inside it — parseResultsToday must not mistake those for today's races.
        let document = try loadFixtureDocument()
        let results = Service.parseResultsToday(from: document)

        XCTAssertTrue(results.isEmpty, "The captured fixture has 'No results (yet).' for today")
    }

    func testResultsTodayParsesPopulatedSnippet() throws {
        // The real fixture never exercises a populated "Results today" list, so this inline
        // snippet (well-formed, unlike the empty-state markup above) covers that path directly.
        let snippet = """
        <html><body>
        <div class="">
        <div class="h4bar mb5 mt20"><h4>Results today</h4></div><ul class="hp2-results">
        <li class="race">
        <a href="rider/test-rider"><div class="winner-img" style=" background: url(images/riders/xx/yy/test-rider-2026.jpg); background-size: 85px; background-repeat: no-repeat;  "></div></a><div style="width: calc(100% - 95px);  float: left; font-size: 14px; "><a href="race/test-race/2026/result"><b>Test Race (1.1)</b><br /><span style="color: #1f8acc; ">Test City - Test City (100km)</span></a></div>
        <div class="resultsCont"><div class="top3Cont "><table class="top3">
        <tr><td class="w4">1</td><td class="w70"><span class="flag fr" title="France"></span> <a href="rider/test-rider">TEST Rider</a></td><td class="w10"></td><td class="ar w16">3:45:00</td></tr>
        <tr><td class="w4">2</td><td class="w70"><span class="flag be" title="Belgium"></span> <a href="rider/test-rider2">TEST Rider2</a></td><td class="w10"></td><td class="ar w16">0:05</td></tr>
        <tr><td class="w4">3</td><td class="w70"><span class="flag it" title="Italy"></span> <a href="rider/test-rider3">TEST Rider3</a></td><td class="w10"></td><td class="ar w16">0:10</td></tr>
        </table>
        </div><div class="clear"></div></div>
        </li>
        </ul>
        </div>
        </body></html>
        """
        let document = try SwiftSoup.parse(snippet)
        let results = Service.parseResultsToday(from: document)

        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertFalse(result.raceName.isEmpty)
        XCTAssertNotNil(result.winner)
        XCTAssertEqual(result.podium.count, 3)
        XCTAssertTrue(result.podium.allSatisfy { !$0.name.isEmpty && !$0.time.isEmpty })
    }

    // MARK: - LiveStats

    func testLiveStatsReturnsEmptyWithoutThrowingOnRealMarkup() throws {
        // The captured fixture has PCS's normal "nothing live right now" state:
        // an empty <ul class="hp3-livestats">. That must parse to an empty
        // array, not throw and not report a non-fatal.
        let document = try loadFixtureDocument()
        let results = Service.parseLiveStats(document)

        XCTAssertTrue(results.isEmpty, "The captured fixture has an empty <ul class=\"hp3-livestats\">")
    }

    func testLiveStatsParsesPopulatedSnippet() throws {
        // The real fixture never exercises a populated LiveStats list (see above), so this
        // inline snippet — the verified live markup from the brief — covers that path directly.
        let snippet = """
        <html><body>
        <div class="mt10"><h4>LiveStats</h4><div class="fs14"></div></div>
        <div class="">
        <ul class="hp3-livestats">
          <li><a href="race/world-championships-itt-u23/2026/result/live">
            <span class="status live">live</span>
            <span class="title">World Championships MU - ITT</span>
            <div class="togo"><span>63</span>riders</div>
            <div style="background: linear-gradient(90deg, red, blue)">
              <div class="inverse" style="clip-path: polygon(0 0%,0.00% 38.61%,100% 40%)"></div>
            </div>
          </a></li>
        </ul>
        </div>
        </body></html>
        """
        let document = try SwiftSoup.parse(snippet)
        let results = Service.parseLiveStats(document)

        XCTAssertEqual(results.count, 1)
        let result = try XCTUnwrap(results.first)
        XCTAssertEqual(result.raceName, "World Championships MU - ITT")
        XCTAssertEqual(result.ridersCount, 63)
        XCTAssertTrue(result.isLive)
        XCTAssertEqual(result.racePath, "race/world-championships-itt-u23/2026/result/live")
    }

    // MARK: - Live network (hits the real procyclingstats.com site)

    /// Hits https://www.procyclingstats.com/index.php directly through the same
    /// `Service.getLatestResults()` path the app uses in production, instead of the
    /// pinned `pcs_real.html` fixture — catches a live markup change even before the
    /// fixture is re-captured. Live content varies by time of day (any one section can
    /// legitimately be empty), so this only checks structural shape, never exact values.
    func testGetLatestResultsParsesRealWebsite() async throws {
        let result = try await Service.getLatestResults()

        XCTAssertFalse(
            result.nextToFinish.isEmpty
                && result.today.isEmpty
                && result.yesterdayResults.isEmpty
                && result.tomorrowRaces.isEmpty
                && result.liveStats.isEmpty,
            "Expected at least one non-empty section from the live homepage"
        )

        for race in result.nextToFinish {
            XCTAssertFalse(race.name.isEmpty)
            XCTAssertTrue(matchesTime(race.eta), "Unexpected eta shape: \(race.eta)")
            XCTAssertTrue(race.urlPath.hasPrefix("https://www.procyclingstats.com/"))
        }
        for race in result.yesterdayResults {
            XCTAssertFalse(race.raceName.isEmpty)
            XCTAssertEqual(race.podium.count, 3, "Expected a 3-entry podium for a finished race")
        }
        for race in result.tomorrowRaces {
            XCTAssertFalse(race.raceName.isEmpty)
            XCTAssertTrue(matchesTime(race.startTime), "Unexpected startTime shape: \(race.startTime)")
        }
        for race in result.liveStats {
            XCTAssertFalse(race.raceName.isEmpty)
            XCTAssertFalse(race.racePath.isEmpty)
        }
    }
}
