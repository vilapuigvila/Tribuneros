//
//  PaddockTransfersPagingTests.swift
//  TribunerosTests
//
//  The Moves sheet reveals the PCS transfer rows 25 at a time from one download.
//

import XCTest
@testable import Tribuneros

@MainActor
final class PaddockTransfersPagingTests: XCTestCase {

    private func rows(_ count: Int) -> [String] {
        (0..<count).map { index in
            "<tr class=\"\"><td>2026-11-05</td><td><span class=\"flag it\"></span> <a href=\"rider/rider-\(index)\">RIDER \(index)</a></td><td><a href=\"team//transfers\"></a></td><td><a href=\"team/team-a-2027/transfers\">Team A</a></td><td>2027</td></tr>"
        }
    }

    private func transferCount(_ interactor: Paddock.InteractorImpl) -> Int {
        interactor.domain.events.filter { Paddock.Filter.transfers.includes($0.kind) }.count
    }

    func testSplitterKeepsOneStringPerRow() throws {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "pcs_transfers", withExtension: "html"))
        let html = try String(contentsOf: url, encoding: .utf8)
        let rows = Service.splitTransferRows(html)

        XCTAssertEqual(rows.count, 310)
        let parsed = Service.parseTransferRows(rows, in: 0..<1)
        XCTAssertEqual(parsed.first?.rider.name, "TERADA Yoshiki")
        XCTAssertEqual(parsed.first?.fromTeam, "Team UKYO")
    }

    func testSixtyRowsRevealAs25_25_10WithOneRequest() async throws {
        var requests = 0
        let allRows = rows(60)
        let interactor = Paddock.InteractorImpl {
            requests += 1
            return DTO.Paddock(
                transfers: [],
                transferRows: allRows,
                programUpdates: [],
                birthdays: []
            )
        }
        interactor.useCase(.request)
        try await waitUntil { interactor.domain.lastUpdated != nil }

        XCTAssertEqual(transferCount(interactor), 25)
        interactor.useCase(.revealMoreTransfers)
        XCTAssertEqual(transferCount(interactor), 50)
        interactor.useCase(.revealMoreTransfers)
        XCTAssertEqual(transferCount(interactor), 60)
        interactor.useCase(.revealMoreTransfers)
        XCTAssertEqual(transferCount(interactor), 60)
        XCTAssertEqual(requests, 1, "Reaching the end of the list must not hit the network again")

        let state = Paddock.ViewModel<Paddock.InteractorImpl>.mapToViewState(from: interactor.domain, now: Date())
        XCTAssertEqual(state.transferCount, 60)
    }

    private func waitUntil(_ condition: @escaping () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(condition())
    }
}
