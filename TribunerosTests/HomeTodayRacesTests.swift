//
//  HomeTodayRacesTests.swift
//  TribunerosTests
//
//  What the Today Races screen shows from PCS's "Next to finish": stage titles, finish times,
//  ordering, and which races count as live.
//

import XCTest
import Combine
@testable import Tribuneros

final class HomeTodayRacesTests: XCTestCase {
    private typealias RaceNext = HomeRaces.Representable.RaceNext

    private let calendar = Calendar.current

    private func date(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: hour, minute: minute))!
    }

    private func race(
        _ name: String = "Race",
        eta: String = "16:42",
        duration: String = "2h",
        urlPath: String = ""
    ) -> DTO.NextToFinishResult {
        DTO.NextToFinishResult(
            eta: eta,
            duration: duration,
            name: name,
            category: "ME",
            raceType: "1.1",
            distance: "",
            urlPath: urlPath,
            flagCode: "it"
        )
    }

    private func next(eta: String, duration: String = "2h") -> RaceNext {
        RaceNext(
            eta: eta,
            duration: duration,
            name: "Race",
            category: "ME",
            raceType: "1.1",
            distance: "",
            urlPath: nil,
            flagCode: "it"
        )
    }

    // MARK: - Title and stage

    func testStageSuffixBecomesTheSubtitle() {
        let stage = RaceNext(eta: "", duration: "", name: "Tour of Poyang Lake - S2", category: "", raceType: "", distance: "", urlPath: nil, flagCode: "")
        XCTAssertEqual(stage.title, "Tour of Poyang Lake")
        XCTAssertEqual(stage.stageLabel, "Stage 2")
        XCTAssertEqual(stage.subtitle, "Stage 2")

        let split = RaceNext(eta: "", duration: "", name: "Keizer der Juniores - S2b", category: "", raceType: "", distance: "", urlPath: nil, flagCode: "")
        XCTAssertEqual(split.title, "Keizer der Juniores")
        XCTAssertEqual(split.stageLabel, "Stage 2b")
    }

    func testNamesWithoutAStageStayWhole() {
        let timeTrial = RaceNext(eta: "", duration: "", name: "World Championships WU - ITT", category: "", raceType: "", distance: "", urlPath: nil, flagCode: "")
        XCTAssertEqual(timeTrial.title, "World Championships WU - ITT")
        XCTAssertNil(timeTrial.stageLabel)
        XCTAssertEqual(timeTrial.subtitle, "One-day race")

        let sprint = RaceNext(eta: "", duration: "", name: "Race - Sprint", category: "", raceType: "", distance: "", urlPath: nil, flagCode: "")
        XCTAssertEqual(sprint.title, "Race - Sprint")
        XCTAssertNil(sprint.stageLabel)
    }

    // MARK: - Finish time

    func testRemainingTimeCountsDownToTheEta() {
        let now = date(14, 28)
        XCTAssertEqual(next(eta: "16:42").remainingTimeDescription(now: now), "2h 14m")
        XCTAssertEqual(next(eta: "15:28").remainingTimeDescription(now: now), "1h")
        XCTAssertEqual(next(eta: "14:58").remainingTimeDescription(now: now), "30m")
    }

    func testRemainingTimeIsAbsentOnceTheEtaPassedOrCannotBeRead() {
        let now = date(14, 28)
        XCTAssertNil(next(eta: "14:00", duration: "-").remainingTimeDescription(now: now))
        XCTAssertNil(next(eta: "-", duration: "-").remainingTimeDescription(now: now))
        XCTAssertNil(next(eta: "25:99").remainingTimeDescription(now: now))
    }

    func testAFinishAfterMidnightRollsToTomorrowWhilePcsStillCountsHours() {
        let now = date(22, 0)
        let afterMidnight = next(eta: "00:40", duration: "3h")
        XCTAssertEqual(afterMidnight.remainingTimeDescription(now: now), "2h 40m")
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date(0, 40))
        XCTAssertEqual(afterMidnight.finishDate(now: now), tomorrow)
    }

    func testAnEtaThatPassedStaysTodayWhenPcsShowsADash() {
        let now = date(22, 0)
        let passed = next(eta: "05:30", duration: "-")
        XCTAssertEqual(passed.finishDate(now: now), date(5, 30))
        XCTAssertNil(passed.remainingTimeDescription(now: now))
    }

    // MARK: - Order

    func testRacesAreOrderedByFinishTimeAndTiesKeepThePageOrder() {
        let races = HomeRaces.TodayRaces.build(
            nextToFinish: [
                race("C", eta: "17:05"),
                race("A", eta: "16:42"),
                race("B", eta: "16:42"),
                race("D", eta: "-", duration: "-")
            ],
            liveStats: [],
            now: date(14, 28)
        )
        XCTAssertEqual(races.map(\.name), ["A", "B", "C", "D"])
    }

    func testWorldTourRacesNoLongerJumpTheQueue() {
        let races = HomeRaces.TodayRaces.build(
            nextToFinish: [
                DTO.NextToFinishResult(eta: "21:35", duration: "7h", name: "Late UWT", category: "ME", raceType: "1.UWT", distance: "", urlPath: "", flagCode: "ca"),
                race("Early", eta: "16:42")
            ],
            liveStats: [],
            now: date(14, 28)
        )
        XCTAssertEqual(races.map(\.name), ["Early", "Late UWT"])
    }

    // MARK: - Live

    func testARaceIsLiveWhenLiveStatsListsItsLivePage() {
        let races = HomeRaces.TodayRaces.build(
            nextToFinish: [
                race("X - S1", urlPath: "https://www.procyclingstats.com/race/x/2026/stage-1"),
                race("Y", eta: "17:00", urlPath: "https://www.procyclingstats.com/race/y/2026/result"),
                race("W", eta: "18:00", urlPath: "https://www.procyclingstats.com/race/w/2026/result")
            ],
            liveStats: [
                DTO.LiveStatsRace(status: "live", isLive: true, raceName: "Other title", ridersCount: 141, racePath: "race/x/2026/stage-1/live", url: nil),
                DTO.LiveStatsRace(status: "soon", isLive: false, raceName: "Y", ridersCount: nil, racePath: "race/y/2026/result/live", url: nil)
            ],
            now: date(14, 28)
        )
        XCTAssertEqual(races.map(\.isLive), [true, false, false])
    }

    func testTheSharedTitleMarksARaceLiveWhenAPathIsMissing() {
        let races = HomeRaces.TodayRaces.build(
            nextToFinish: [race("World Championships MU - ITT", urlPath: "")],
            liveStats: [
                DTO.LiveStatsRace(status: "live", isLive: true, raceName: "world championships mu - itt", ridersCount: 63, racePath: "race/world-championships-itt-u23/2026/result/live", url: nil)
            ],
            now: date(14, 28)
        )
        XCTAssertEqual(races.map(\.isLive), [true])
    }

    func testNothingIsLiveWithoutLiveStats() {
        let races = HomeRaces.TodayRaces.build(
            nextToFinish: [race("X - S1", urlPath: "https://www.procyclingstats.com/race/x/2026/stage-1")],
            liveStats: [],
            now: date(14, 28)
        )
        XCTAssertEqual(races.map(\.isLive), [false])
    }

    // MARK: - View model

    private final class StubInteractor: InteractorProtocol {
        typealias Domain = HomeRacesDomain
        typealias UseCase = HomeRaces.UseCase

        let subject = CurrentValueSubject<HomeRacesDomain, Never>(.empty)
        var domain: HomeRacesDomain { subject.value }
        var publisher: AnyPublisher<HomeRacesDomain, Never> { subject.eraseToAnyPublisher() }
        func useCase(_ useCase: HomeRaces.UseCase) {}
    }

    private func state(after domain: HomeRacesDomain) -> HomeRaces.ViewState {
        let interactor = StubInteractor()
        let viewModel = HomeRacesViewModel(interactor: interactor, router: Router())
        let settled = expectation(description: "the view model mapped the domain")
        let cancellable = viewModel.$stateView.dropFirst().first().sink { _ in settled.fulfill() }
        interactor.subject.send(domain)
        wait(for: [settled], timeout: 2)
        cancellable.cancel()
        return viewModel.stateView
    }

    func testTheViewModelStartsIdleSoThePageDrawsPlaceholders() {
        let viewModel = HomeRacesViewModel(interactor: StubInteractor(), router: Router())
        let settled = expectation(description: "the initial domain was mapped")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2)

        guard case .idle = viewModel.stateView else {
            return XCTFail("Expected .idle before the first request, got \(viewModel.stateView)")
        }
    }

    func testTheViewModelMapsRacesInFinishOrderWithTheLiveFlag() throws {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let soon = formatter.string(from: now.addingTimeInterval(60 * 60))
        let later = formatter.string(from: now.addingTimeInterval(3 * 60 * 60))

        let domain = HomeRacesDomain(
            nextToFinishRaces: [
                race("Later", eta: later, duration: "3h", urlPath: "https://www.procyclingstats.com/race/later/2026/result"),
                race("Soon", eta: soon, duration: "1h", urlPath: "https://www.procyclingstats.com/race/soon/2026/result")
            ],
            todayRaces: [],
            yesterdayResults: [],
            tomorrowRaces: [],
            liveStatsRaces: [
                DTO.LiveStatsRace(status: "live", isLive: true, raceName: "Soon", ridersCount: 10, racePath: "race/soon/2026/result/live", url: nil)
            ],
            isOnSpoilerModeResultsToday: false,
            isOnSpoilerModeResultsYesterday: false,
            error: nil,
            loading: false
        )

        guard case .loaded(let representable) = state(after: domain) else {
            return XCTFail("Expected a loaded state")
        }
        XCTAssertEqual(representable.sections.nextToFinish.map(\.name), ["Soon", "Later"])
        XCTAssertEqual(representable.sections.nextToFinish.map(\.isLive), [true, false])
    }
}
