import XCTest
@testable import Tribuneros
import Alfy

final class HomeRacesReloadTests: XCTestCase {
    private func domain(
        withData: Bool = true,
        error: EquatableError? = nil,
        loading: Bool = false
    ) -> HomeRacesDomain {
        HomeRacesDomain(
            nextToFinishRaces: [],
            todayRaces: [],
            yesterdayResults: [],
            historyResults: [],
            tomorrowRaces: [],
            liveStatsRaces: withData ? [
                DTO.LiveStatsRace(
                    status: "live",
                    isLive: true,
                    raceName: "Race",
                    ridersCount: 10,
                    racePath: "race/x/2026/result/live",
                    url: nil
                )
            ] : [],
            error: error,
            loading: loading
        )
    }

    func testFreshCacheWithDataSkipsReload() {
        XCTAssertFalse(HomeRacesInteractorImpl.shouldReload(domain(), isHomepageCacheFresh: true))
    }

    func testStaleCacheReloads() {
        XCTAssertTrue(HomeRacesInteractorImpl.shouldReload(domain(), isHomepageCacheFresh: false))
    }

    func testLoadingReloads() {
        XCTAssertTrue(HomeRacesInteractorImpl.shouldReload(domain(loading: true), isHomepageCacheFresh: true))
    }

    func testErrorReloads() {
        let error = HomeRaces.ErrorReason.emptyResponse.toEquatableError()
        XCTAssertTrue(HomeRacesInteractorImpl.shouldReload(domain(error: error), isHomepageCacheFresh: true))
    }

    func testEmptyReloads() {
        XCTAssertTrue(HomeRacesInteractorImpl.shouldReload(domain(withData: false), isHomepageCacheFresh: true))
    }
}
