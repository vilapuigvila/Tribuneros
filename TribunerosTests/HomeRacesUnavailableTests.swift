//
//  HomeRacesUnavailableTests.swift
//  TribunerosTests
//

import XCTest
import Alfy
@testable import Tribuneros

final class HomeRacesUnavailableTests: XCTestCase {
    private typealias ViewModel = HomeRacesViewModel<HomeRacesInteractorImpl>

    private func emptyDomain(
        error: EquatableError?,
        retriesLeft: Int = 3,
        lastLoaded: Date? = nil
    ) -> HomeRacesDomain {
        var domain = HomeRacesDomain(
            nextToFinishRaces: [],
            todayRaces: [],
            yesterdayResults: [],
            historyResults: [],
            tomorrowRaces: [],
            liveStatsRaces: [],
            error: error,
            loading: false
        )
        domain.retriesLeft = retriesLeft
        domain.lastLoaded = lastLoaded
        return domain
    }

    // MARK: - Retry budget

    func testBudgetAllowsThreeTriesThenLocks() {
        var budget = HomeRaces.RetryBudget()
        XCTAssertEqual(budget.left, 3)
        XCTAssertTrue(budget.consume())
        XCTAssertTrue(budget.consume())
        XCTAssertEqual(budget.left, 1)
        XCTAssertTrue(budget.consume())
        XCTAssertEqual(budget.left, 0)
        XCTAssertFalse(budget.consume())
        XCTAssertEqual(budget.left, 0)
    }

    func testBudgetResetRestoresAllTries() {
        var budget = HomeRaces.RetryBudget()
        _ = budget.consume()
        _ = budget.consume()
        _ = budget.consume()
        budget.reset()
        XCTAssertEqual(budget.left, HomeRaces.RetryBudget.maxTries)
    }

    // MARK: - Last load

    func testLastLoadedMovesOnlyOnALoadWithData() {
        let previous = Date(timeIntervalSince1970: 1_000)
        let now = Date(timeIntervalSince1970: 5_000)
        XCTAssertEqual(
            HomeRacesInteractorImpl.lastLoaded(
                afterLoadAt: now,
                isEmpty: false,
                previous: previous
            ),
            now
        )
        XCTAssertEqual(
            HomeRacesInteractorImpl.lastLoaded(
                afterLoadAt: now,
                isEmpty: true,
                previous: previous
            ),
            previous
        )
        XCTAssertNil(
            HomeRacesInteractorImpl.lastLoaded(
                afterLoadAt: now,
                isEmpty: true,
                previous: nil
            )
        )
    }

    // MARK: - View state

    func testEmptyResponseMapsToUnavailableScreen() {
        let lastLoaded = Date(timeIntervalSince1970: 2_000)
        let error = HomeRaces.ErrorReason.emptyResponse.toEquatableError()
        let state = ViewModel.errorState(
            error,
            domain: emptyDomain(
                error: error,
                retriesLeft: 1,
                lastLoaded: lastLoaded
            )
        )
        guard case .unavailable(let unavailable) = state else {
            return XCTFail("Expected the no-data screen, got \(state)")
        }
        XCTAssertEqual(
            unavailable,
            HomeRaces.Unavailable(
                triesLeft: 1,
                lastLoaded: lastLoaded
            )
        )
        XCTAssertFalse(unavailable.isLocked)
    }

    func testNoTriesLeftIsLocked() {
        XCTAssertTrue(HomeRaces.Unavailable(triesLeft: 0, lastLoaded: nil).isLocked)
    }

    func testOtherErrorsKeepTheGenericCard() {
        let error = NSError(domain: "test", code: 1).toEquatableError()
        let state = ViewModel.errorState(
            error,
            domain: emptyDomain(error: error)
        )
        guard case .error(.networkFailure) = state else {
            return XCTFail("Expected the generic error card, got \(state)")
        }
    }

    func testUnavailableMockScenarioIsAnEmptyResponseLoadedThreeHoursAgo() {
        let now = Date(timeIntervalSince1970: 100_000)
        let domain = HomeRaces.MockScenario.unavailable.domain(now: now)
        XCTAssertEqual(domain.error?.asError(type: HomeRaces.ErrorReason.self), .emptyResponse)
        XCTAssertEqual(domain.lastLoaded, now.addingTimeInterval(-3 * 3600))
        XCTAssertTrue(domain.nextToFinishRaces.isEmpty)
    }
}
