import XCTest
import SwiftSoup
@testable import Tribuneros

final class RoadResultsWithoutCxTests: XCTestCase {
    private func document(_ name: String) throws -> Document {
        guard let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "html") else {
            XCTFail("Missing \(name).html fixture in the test bundle")
            throw XCTSkip()
        }
        return try SwiftSoup.parse(String(contentsOf: url, encoding: .utf8))
    }

    func testResultsTodayKeepsOnlyTheRoadRace() throws {
        let results = Service.parseResultsToday(from: try document("pcs_results_cx"))

        XCTAssertEqual(results.map(\.raceName), ["African CC ME - Road Race (CC)"])
    }

    func testResultsYesterdayHasNoCyclocrossRow() throws {
        let results = try Service.parseResultsYesterday(try document("pcs_results_cx"))

        XCTAssertFalse(results.isEmpty)
        for result in results {
            XCTAssertFalse(Service.isCyclocross(title: result.raceName, details: result.raceDetails), result.raceName)
        }
    }

    func testCCIsCyclocrossOnlyWithoutARoute() {
        XCTAssertFalse(Service.isCyclocross(title: "African CC ME - Road Race (CC)", details: "Kisumu - Kisumu (153km)"))
        XCTAssertTrue(Service.isCyclocross(title: "Some Cross (CC)", details: ""))
        XCTAssertTrue(Service.isCyclocross(title: "Some Cross (CC)", details: " "))
    }

    func testClassesAreDecidedByTheTrailingParenthesis() {
        for raceClass in ["C1", "C2", "C3", "CJ", "CU", "CDM", "CM"] {
            XCTAssertTrue(Service.isCyclocross(title: "Cross (\(raceClass))", details: "(10km)"), raceClass)
        }
        for raceClass in ["1.UWT", "2.1", "NC", "WC", "CN"] {
            XCTAssertFalse(Service.isCyclocross(title: "Road (\(raceClass))", details: ""), raceClass)
        }
        XCTAssertFalse(Service.isCyclocross(title: "Race (C1) Stage 2", details: ""))
    }

    func testHistoryDropsACyclocrossClassRowAndKeepsARoadRow() throws {
        let html = """
        <table class="basic"><tbody>
        <tr><td>2026-10-01</td><td><a href="race/cross-a/2026/result">Cross A</a></td><td>C1</td><td><a href="rider/a"> A</a></td><td>1h</td></tr>
        <tr><td>2026-10-01</td><td><a href="race/road-b/2026/result">Road B</a></td><td>1.1</td><td><a href="rider/b"> B</a></td><td>1h</td></tr>
        <tr><td>2026-10-01</td><td><a href="race/cc-c/2026/result">CC Race</a></td><td>CC</td><td><a href="rider/c"> C</a></td><td>1h</td></tr>
        </tbody></table>
        """
        let calendar = Calendar(identifier: .gregorian)
        let cutoff = DateComponents(calendar: calendar, year: 2026, month: 10, day: 5).date!
        let results = Service.parseHistoryResults(try SwiftSoup.parse(html), before: cutoff, calendar: calendar)

        XCTAssertEqual(results.map(\.raceName), ["Road B (1.1)", "CC Race (CC)"])
    }
}
