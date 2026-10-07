//
//  HomeTodayRacesTests.swift
//  TribunerosTests
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

    private func next(eta: String, duration: String = "2h", now: Date) -> RaceNext {
        HomeRaces.TodayRaces.build(
            nextToFinish: [race(eta: eta, duration: duration)],
            liveStats: [],
            now: now
        )[0]
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
        XCTAssertEqual(next(eta: "16:42", now: now).remainingTimeDescription(now: now), "2h 14m")
        XCTAssertEqual(next(eta: "15:28", now: now).remainingTimeDescription(now: now), "1h")
        XCTAssertEqual(next(eta: "14:58", now: now).remainingTimeDescription(now: now), "30m")
    }

    func testRemainingTimeIsAbsentOnceTheEtaPassedOrCannotBeRead() {
        let now = date(14, 28)
        XCTAssertNil(next(eta: "14:00", duration: "-", now: now).remainingTimeDescription(now: now))
        XCTAssertNil(next(eta: "-", duration: "-", now: now).remainingTimeDescription(now: now))
        XCTAssertNil(next(eta: "25:99", now: now).remainingTimeDescription(now: now))
    }

    func testAFinishAfterMidnightRollsToTomorrowWhilePcsStillCountsHours() {
        let now = date(22, 0)
        let afterMidnight = next(eta: "00:40", duration: "3h", now: now)
        XCTAssertEqual(afterMidnight.remainingTimeDescription(now: now), "2h 40m")
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date(0, 40))
        XCTAssertEqual(afterMidnight.finishDate, tomorrow)
    }

    func testAFinishFromLateYesterdayIsNotCountedDownAfterMidnight() {
        let now = date(0, 10)
        let yesterdaysFinish = next(eta: "23:50", duration: "-", now: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date(23, 50))
        XCTAssertEqual(yesterdaysFinish.finishDate, yesterday)
        XCTAssertNil(yesterdaysFinish.remainingTimeDescription(now: now))

        let races = HomeRaces.TodayRaces.build(
            nextToFinish: [race("Next", eta: "01:30", duration: "1h"), race("Old", eta: "23:50", duration: "-")],
            liveStats: [],
            now: now
        )
        XCTAssertEqual(races.map(\.name), ["Old", "Next"])
    }

    func testAnEtaThatPassedStaysTodayWhenPcsShowsADash() {
        let now = date(22, 0)
        let passed = next(eta: "05:30", duration: "-", now: now)
        XCTAssertEqual(passed.finishDate, date(5, 30))
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

    // MARK: - Images

    func testPCSImageHeadersAreOnlyAddedForPCSHosts() {
        var pcs = URLRequest(url: URL(string: "https://www.procyclingstats.com/images/riders/a.jpg")!)
        Service.addPCSImageHeaders(to: &pcs)
        XCTAssertEqual(pcs.value(forHTTPHeaderField: "Referer"), "https://www.procyclingstats.com/")
        XCTAssertNotNil(pcs.value(forHTTPHeaderField: "User-Agent"))

        for other in ["https://flagcdn.com/w40/it.png", "https://evilprocyclingstats.com/a.jpg"] {
            var request = URLRequest(url: URL(string: other)!)
            Service.addPCSImageHeaders(to: &request)
            XCTAssertNil(request.value(forHTTPHeaderField: "Referer"), other)
        }
    }

    // MARK: - View model

    private final class StubInteractor: InteractorProtocol {
        typealias Domain = HomeRacesDomain
        typealias UseCase = HomeRaces.UseCase

        let subject: CurrentValueSubject<HomeRacesDomain, Never>

        init(initial: HomeRacesDomain = .empty) {
            subject = CurrentValueSubject(initial)
        }

        var domain: HomeRacesDomain { subject.value }
        var publisher: AnyPublisher<HomeRacesDomain, Never> { subject.eraseToAnyPublisher() }
        func useCase(_ useCase: HomeRaces.UseCase) {}
    }

    private func state(after domain: HomeRacesDomain) -> HomeRaces.ViewState {
        let interactor = StubInteractor()
        let viewModel = HomeRacesViewModel(interactor: interactor, router: Router())
        let settled = expectation(description: "the view model mapped the domain")
        let cancellable = viewModel.$stateView
            .first { state in
                if case .idle = state { return false }
                return true
            }
            .sink { _ in settled.fulfill() }
        interactor.subject.send(domain)
        wait(for: [settled], timeout: 2)
        cancellable.cancel()
        return viewModel.stateView
    }

    func testTheViewModelStartsLoadingSoThePageDrawsPlaceholders() {
        let viewModel = HomeRacesViewModel(interactor: StubInteractor(initial: .empty.copy(loading: true)), router: Router())
        let settled = expectation(description: "the initial domain was mapped")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2)

        guard case .loading = viewModel.stateView else {
            return XCTFail("Expected .loading before the first response, got \(viewModel.stateView)")
        }
    }

    func testTheViewModelMapsRacesInFinishOrderWithTheLiveFlag() throws {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
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
            historyResults: [],
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

    private func response(_ headers: [String: String]) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://www.procyclingstats.com/index.php")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    func testAStaleCachedCopyReportsWhenItWasFetched() {
        let now = date(12, 0)
        let savedAt = Service.staleCopySavedAt(
            response(["X-Cache": "STALE", "Age": "10800"]),
            now: now
        )
        XCTAssertEqual(savedAt, date(9, 0))
    }

    func testAFreshOrNetworkResponseIsNotAStaleCopy() {
        let now = date(12, 0)
        XCTAssertNil(Service.staleCopySavedAt(response(["X-Cache": "HIT", "Age": "120"]), now: now))
        XCTAssertNil(Service.staleCopySavedAt(response(["X-Cache": "MISS"]), now: now))
        XCTAssertNil(Service.staleCopySavedAt(response(["X-Cache": "STALE"]), now: now))
    }

    func testTheViewModelPassesTheStaleCopyToTheView() throws {
        let staleCopy = HomeRaces.StaleCopy(
            savedAt: date(9, 0),
            isOffline: true
        )
        let domain = HomeRacesDomain(
            nextToFinishRaces: [race("Soon")],
            todayRaces: [],
            yesterdayResults: [],
            historyResults: [],
            tomorrowRaces: [],
            liveStatsRaces: [],
            isOnSpoilerModeResultsToday: false,
            isOnSpoilerModeResultsYesterday: false,
            error: nil,
            loading: false,
            staleCopy: staleCopy
        )

        guard case .loaded(let representable) = state(after: domain) else {
            return XCTFail("Expected a loaded state")
        }
        XCTAssertEqual(representable.staleCopy, staleCopy)
    }

    func testStartTimeUsesTheSiteTimeInParentheses() {
        XCTAssertEqual(HomeRaces.TodayRaces.siteStartTime("08:00  (16:00 CET)"), "16:00")
        XCTAssertEqual(HomeRaces.TodayRaces.siteStartTime("11:09  (05:09 CET)"), "05:09")
        XCTAssertEqual(HomeRaces.TodayRaces.siteStartTime("12:00"), "12:00")
        XCTAssertNil(HomeRaces.TodayRaces.siteStartTime("-"))
    }

    func testGenderLabelComesFromTheCategoryCode() {
        func race(_ category: String) -> HomeRaces.Representable.RaceNext {
            HomeRaces.Representable.RaceNext(
                eta: "16:00",
                duration: "2H",
                name: "Race",
                category: category,
                raceType: "1.1",
                distance: "",
                urlPath: nil,
                flagCode: ""
            )
        }
        XCTAssertEqual(race("ME").genderLabel, "MEN")
        XCTAssertEqual(race("WU").genderLabel, "WOMEN")
        XCTAssertNil(race("").genderLabel)
    }

    func testHasStartedComparesTheStartTimeOnTheFinishDay() {
        let calendar = Calendar.current
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!
        func race(start: String?) -> HomeRaces.Representable.RaceNext {
            HomeRaces.Representable.RaceNext(
                eta: "16:00",
                duration: "4H",
                name: "Race",
                category: "ME",
                raceType: "1.1",
                distance: "",
                urlPath: nil,
                flagCode: "",
                finishDate: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: noon),
                startTime: start
            )
        }
        XCTAssertTrue(race(start: "11:30").hasStarted(now: noon))
        XCTAssertFalse(race(start: "12:30").hasStarted(now: noon))
        XCTAssertFalse(race(start: nil).hasStarted(now: noon))
    }

    func testHasStartedBetweenTheStartAndTheFinish() {
        let calendar = Calendar.current
        let now = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: Date())!
        func race(start: String, finishIn minutes: Double) -> HomeRaces.Representable.RaceNext {
            HomeRaces.Representable.RaceNext(
                eta: "",
                duration: "",
                name: "Race",
                category: "ME",
                raceType: "1.1",
                distance: "",
                urlPath: nil,
                flagCode: "",
                finishDate: now.addingTimeInterval(minutes * 60),
                startTime: start
            )
        }
        XCTAssertTrue(race(start: "20:00", finishIn: 60).hasStarted(now: now))
        XCTAssertFalse(race(start: "23:45", finishIn: 60).hasStarted(now: now))
        XCTAssertFalse(race(start: "-", finishIn: 60).hasStarted(now: now))
    }
}
