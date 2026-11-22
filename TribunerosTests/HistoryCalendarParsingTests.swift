//
//  HistoryCalendarParsingTests.swift
//  TribunerosTests
//
//  History's off-season fallback: finished races from PCS's season calendar (`races.php?year=`).
//  `pcs_races.html` is the real 2027 calendar (no winners yet); the inline rows copy its markup
//  with the winner link filled in, as PCS shows it once a race is over.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class HistoryCalendarParsingTests: XCTestCase {

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func fixture(_ name: String) throws -> Document {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: name, withExtension: "html"))
        return try SwiftSoup.parse(String(contentsOf: url, encoding: .utf8))
    }

    private let seasonHTML = """
    <table class="basic"><thead><tr><th>Date</th><th>Start</th><th>Race</th><th>Winner</th><th>Class</th></tr></thead>
    <tbody>
    <tr class=""><td class="cu500" >19.01 - 24.01</td><td class="hide cs500" >19.01</td><td><span class="flag au"></span> <a  href="race/tour-down-under-2026-gc">Santos Tour Down Under</a></td><td class="cu500" ><span class="flag au"></span> <a  href="rider/jay-vine">VINE Jay</a></td><td>2.UWT</td></tr>
    <tr class=""><td class="cu500" >11.10</td><td class="hide cs500" >11.10</td><td><span class="flag it"></span> <a  href="race/il-lombardia-2026-result">Il Lombardia</a></td><td class="cu500" ><span class="flag si"></span> <a  href="rider/tadej-pogacar">POGAČAR Tadej</a></td><td>1.UWT</td></tr>
    <tr class=""><td class="cu500" >14.10 - 19.10</td><td class="hide cs500" >14.10</td><td><span class="flag cn"></span> <a  href="race/tour-of-guangxi-2026-gc">Gree-Tour of Guangxi</a></td><td class="cu500" ><a  href="rider/paul-magnier">MAGNIER Paul</a></td><td>2.UWT</td></tr>
    <tr class=""><td class="cu500" >28.12 - 03.01</td><td class="hide cs500" >28.12</td><td><span class="flag be"></span> <a  href="race/new-year-race-2026-gc">New Year Race</a></td><td class="cu500" ><a  href="rider/"></a></td><td>2.UWT</td></tr>
    <tr class=""><td class="cu500" >30.12</td><td class="hide cs500" >30.12</td><td><span class="flag be"></span> <a  href="race/future-race-2026-result">Future Race</a></td><td class="cu500" ><a  href="rider/"></a></td><td>1.UWT</td></tr>
    </tbody></table>
    """

    func testFinishedRacesNewestFirstWithTheirWinner() throws {
        let results = Service.parseSeasonCalendarResults(
            try SwiftSoup.parse(seasonHTML),
            year: 2026,
            before: day(2026, 11, 21),
            calendar: calendar()
        )

        XCTAssertEqual(results.map(\.raceName), [
            "Gree-Tour of Guangxi (2.UWT)",
            "Il Lombardia (1.UWT)",
            "Santos Tour Down Under (2.UWT)"
        ])
        XCTAssertEqual(results.first?.raceURL?.absoluteString, "https://www.procyclingstats.com/race/tour-of-guangxi-2026-gc")
        XCTAssertEqual(results.first?.raceCountryCode, "cn")
        XCTAssertEqual(results[1].podium.first?.name, "POGAČAR Tadej")
        XCTAssertEqual(results[1].podium.first?.countryCode, "si")
        XCTAssertEqual(results[1].podium.first?.position, "1")
        XCTAssertNil(results.first?.podium.first?.countryCode, "no flag beside the winner")
    }

    func testRacesEndingOnOrAfterTheCutoffAreLeftOut() throws {
        let results = Service.parseSeasonCalendarResults(
            try SwiftSoup.parse(seasonHTML),
            year: 2026,
            before: day(2026, 10, 19),
            calendar: calendar()
        )
        XCTAssertEqual(results.map(\.raceName), ["Il Lombardia (1.UWT)", "Santos Tour Down Under (2.UWT)"])
    }

    func testTheRealNextSeasonCalendarHasNoFinishedRace() throws {
        let results = Service.parseSeasonCalendarResults(
            try fixture("pcs_races"),
            year: 2027,
            before: day(2027, 12, 31),
            calendar: calendar()
        )
        XCTAssertTrue(results.isEmpty, "rows without a winner are not results")
    }

    func testRaceEndDates() {
        XCTAssertEqual(Service.calendarRaceEnd("19.01 - 24.01", year: 2026, calendar: calendar()), day(2026, 1, 24))
        XCTAssertEqual(Service.calendarRaceEnd("31.01", year: 2026, calendar: calendar()), day(2026, 1, 31))
        XCTAssertEqual(Service.calendarRaceEnd("28.12 - 03.01", year: 2026, calendar: calendar()), day(2027, 1, 3))
        XCTAssertNil(Service.calendarRaceEnd("", year: 2026, calendar: calendar()))
        XCTAssertNil(Service.calendarRaceEnd("TBC", year: 2026, calendar: calendar()))
    }
}
