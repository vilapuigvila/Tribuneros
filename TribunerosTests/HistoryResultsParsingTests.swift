//
//  HistoryResultsParsingTests.swift
//  TribunerosTests
//
//  Pins the PCS "Latest race results" table (captured in pcs_latest_results.html, 2026-09-30)
//  that feeds the History section.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class HistoryResultsParsingTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func document(_ name: String = "pcs_latest_results") throws -> Document {
        guard let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "html") else {
            XCTFail("Missing \(name).html fixture in the test bundle")
            throw XCTSkip()
        }
        return try SwiftSoup.parse(String(contentsOf: url, encoding: .utf8))
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }

    func testParsesRowsBeforeTheCutoff() throws {
        let results = Service.parseHistoryResults(try document(), before: date("2026-09-29"), calendar: calendar)

        XCTAssertFalse(results.isEmpty)
        XCTAssertLessThanOrEqual(results.count, 30)
        // The first row on 28 September, the newest one left once 29 and 30 September are cut.
        XCTAssertEqual(results.first?.raceName, "Petronas Le Tour de Langkawi | Stage 2 (2.Pro)")
        XCTAssertEqual(results.first?.raceURL?.absoluteString, "https://www.procyclingstats.com/race/tour-de-langkawi/2026/stage-2")
        XCTAssertEqual(results.first?.podium.first?.name, "JASCH Lennart")
        XCTAssertEqual(results.first?.podium.first?.countryCode, "de")
        XCTAssertEqual(results.first?.podium.first?.position, "1")
        XCTAssertEqual(results.first?.raceCountryCode, "my")
    }

    func testCutoffExcludesNewerDays() throws {
        let results = Service.parseHistoryResults(try document(), before: date("2026-09-27"), calendar: calendar)

        let urls = results.compactMap { $0.raceURL?.absoluteString }
        XCTAssertFalse(urls.contains("https://www.procyclingstats.com/race/world-championship/2026/result"))
        XCTAssertFalse(urls.contains("https://www.procyclingstats.com/race/tour-de-langkawi/2026/stage-2"))
    }

    func testCutoffBeforeEverythingIsEmpty() throws {
        let results = Service.parseHistoryResults(try document(), before: date("2000-01-01"), calendar: calendar)
        XCTAssertTrue(results.isEmpty)
    }

    /// Captured with URLSession on 2026-10-08.
    func testStageRaceRowsLinkToTheStagePageAndOneDayRowsStayUnchanged() throws {
        let results = Service.parseHistoryResults(
            try document("pcs_latest_results_stages"),
            before: date("2026-10-08"),
            calendar: calendar
        )
        let venezuela = results.first { $0.raceName.hasPrefix("Vuelta Ciclista a Venezuela | Stage 3") }
        XCTAssertEqual(venezuela?.raceURL?.absoluteString, "https://www.procyclingstats.com/race/vuelta-ciclista-a-venezuela/2026/stage-3")

        let oneDay = results.first { $0.raceURL?.absoluteString.hasSuffix("-result") == true }
        XCTAssertNotNil(oneDay, "a one-day -result row is in the fixture")
        XCTAssertTrue(oneDay?.raceURL?.absoluteString.hasPrefix("https://www.procyclingstats.com/race/") == true)
        XCTAssertFalse(results.contains { $0.raceName.contains("Stage") && $0.raceURL?.absoluteString.hasSuffix("-gc") == true })
    }

    func testGeneralClassificationRowsKeepTheirLink() throws {
        let results = Service.parseHistoryResults(
            try document("pcs_latest_results_stages"),
            before: date("2026-10-08"),
            calendar: calendar
        )
        let gc = results.first { $0.raceName.contains("General classification") }
        XCTAssertEqual(gc?.raceURL?.absoluteString, "https://www.procyclingstats.com/race/grand-prix-el-djazair-2026-gc")
    }
}
