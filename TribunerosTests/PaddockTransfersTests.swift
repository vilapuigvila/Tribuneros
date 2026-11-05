//
//  PaddockTransfersTests.swift
//  TribunerosTests
//
//  The transfers page (`teams/transfers`), parsed from a real page saved with `URLSession`
//  (`pcs_transfers.html`); re-capture it when PCS changes its markup.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class PaddockTransfersTests: XCTestCase {

    private func fixture() throws -> Document {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "pcs_transfers", withExtension: "html"))
        return try SwiftSoup.parse(String(contentsOf: url, encoding: .utf8))
    }

    func testRealTransfersPageParses() throws {
        let transfers = Service.parsePCSTransfers(try fixture())

        XCTAssertFalse(transfers.isEmpty)
        for transfer in transfers {
            XCTAssertFalse(transfer.rider.name.isEmpty)
            XCTAssertTrue(transfer.rider.url?.absoluteString.hasPrefix("https://www.procyclingstats.com/rider/") == true)
            XCTAssertEqual(transfer.rider.countryCode.count, 2, "Unexpected flag: \(transfer.rider.countryCode)")
            XCTAssertFalse(transfer.teamName.isEmpty)
        }
        XCTAssertTrue(transfers.contains { $0.fromTeam != nil })
        XCTAssertTrue(transfers.contains { $0.fromTeam == nil })
    }

    func testFirstRowKeepsPCSNameAndTeams() throws {
        let first = try XCTUnwrap(Service.parsePCSTransfers(try fixture()).first)

        XCTAssertEqual(first.rider.name, "TERADA Yoshiki")
        XCTAssertEqual(first.rider.countryCode, "jp")
        XCTAssertEqual(first.fromTeam, "Team UKYO")
        XCTAssertEqual(first.teamName, "Team Polti VisitMalta")
        XCTAssertEqual(first.season, "2027")
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: first.date)
        XCTAssertEqual([parts.year, parts.month, parts.day], [2026, 11, 5])
    }

    func testMarkupChangeGivesAnEmptyList() throws {
        XCTAssertTrue(Service.parsePCSTransfers(try SwiftSoup.parse("<html><body><p>Just a moment...</p></body></html>")).isEmpty)
    }
}
