//
//  PerRaceSpoilerTests.swift
//  TribunerosTests
//

import XCTest
import Combine
@testable import Tribuneros

final class PerRaceSpoilerTests: XCTestCase {
    private let raceA = URL(string: "https://www.procyclingstats.com/race/a/2026/result")!
    private let raceB = URL(string: "https://www.procyclingstats.com/race/b/2026/result")!

    private func result(
        _ name: String,
        url: URL?
    ) -> DTO.TodayResult {
        DTO.TodayResult(
            raceName: name,
            raceDetails: "",
            raceURL: url,
            winner: nil,
            podium: [],
            additionalDetails: []
        )
    }

    private func finished(
        _ name: String,
        url: URL?
    ) -> HomeRaces.Representable.RaceFinished {
        HomeRaces.Representable.RaceFinished(
            race: name,
            raceDetails: "",
            winnerImgURL: nil,
            podium: [],
            isCancel: false,
            raceURL: url
        )
    }

    private func next(
        _ name: String,
        finishDate: Date?
    ) -> HomeRaces.Representable.RaceNext {
        HomeRaces.Representable.RaceNext(
            eta: "",
            duration: "",
            name: name,
            category: "ME",
            raceType: "1.1",
            distance: "",
            urlPath: nil,
            flagCode: "",
            finishDate: finishDate
        )
    }

    private final class StubInteractor: InteractorProtocol {
        typealias Domain = HomeRacesDomain
        typealias UseCase = HomeRaces.UseCase

        let subject = CurrentValueSubject<HomeRacesDomain, Never>(.empty)

        var domain: HomeRacesDomain { subject.value }
        var publisher: AnyPublisher<HomeRacesDomain, Never> { subject.eraseToAnyPublisher() }
        func useCase(_ useCase: HomeRaces.UseCase) {}
    }

    private func visibilities(
        _ domain: HomeRacesDomain,
        in keyPath: KeyPath<HomeRaces.Representable.Section, [HomeRaces.Representable.RaceFinished]>
    ) throws -> [HomeRaces.ResultVisibility] {
        let interactor = StubInteractor()
        let viewModel = HomeRacesViewModel(
            interactor: interactor,
            router: Router()
        )
        let settled = expectation(description: "mapped")
        let cancellable = viewModel.$stateView
            .first { state in
                if case .loaded = state { return true }
                return false
            }
            .sink { _ in settled.fulfill() }
        interactor.subject.send(domain)
        wait(for: [settled], timeout: 2)
        cancellable.cancel()
        guard case .loaded(let representable) = viewModel.stateView else {
            throw XCTSkip("not loaded")
        }
        return representable.sections[keyPath: keyPath].map(\.visibility)
    }

    private func domain(
        revealed: Set<String>
    ) -> HomeRacesDomain {
        var domain = HomeRacesDomain(
            nextToFinishRaces: [],
            todayRaces: [result("A", url: raceA), result("B", url: raceB)],
            yesterdayResults: [result("A", url: raceA), result("B", url: raceB)],
            historyResults: [],
            tomorrowRaces: [],
            liveStatsRaces: [],
            error: nil,
            loading: false
        )
        revealed.forEach { domain = domain.togglingReveal($0) }
        return domain
    }

    func testAFreshInteractorStartsWithNothingRevealed() {
        XCTAssertTrue(HomeRacesInteractorImpl().domain.revealedRaces.isEmpty)
    }

    func testTogglingRaceADoesNotChangeRaceB() throws {
        let interactor = HomeRacesInteractorImpl()
        interactor.useCase(.toggleReveal(key: finished("A", url: raceA).revealKey))

        XCTAssertEqual(interactor.domain.revealedRaces, [raceA.absoluteString])
        XCTAssertEqual(
            try visibilities(domain(revealed: interactor.domain.revealedRaces), in: \.racesFinished),
            [.shown, .hidden]
        )
    }

    func testARaceRevealedInTodayIsRevealedInYesterdayToo() throws {
        let revealed = domain(revealed: [finished("A", url: raceA).revealKey])

        XCTAssertEqual(try visibilities(revealed, in: \.racesFinished), [.shown, .hidden])
        XCTAssertEqual(try visibilities(revealed, in: \.yesterdayResults), [.shown, .hidden])
    }

    func testTogglingTwiceHidesTheRaceAgain() throws {
        let interactor = HomeRacesInteractorImpl()
        let key = finished("A", url: raceA).revealKey
        interactor.useCase(.toggleReveal(key: key))
        interactor.useCase(.toggleReveal(key: key))

        XCTAssertTrue(interactor.domain.revealedRaces.isEmpty)
        XCTAssertEqual(try visibilities(domain(revealed: []), in: \.racesFinished), [.hidden, .hidden])
    }

    func testARaceWithoutAURLIsKeyedByItsName() {
        XCTAssertEqual(finished("Tour de Nowhere", url: nil).revealKey, "Tour de Nowhere")
        XCTAssertEqual(finished("A", url: raceA).revealKey, raceA.absoluteString)
    }

    func testTheFirstExpectedFinishIsTheEarliestOne() {
        let calendar = Calendar.current
        let early = calendar.date(bySettingHour: 14, minute: 5, second: 0, of: Date())!
        let late = calendar.date(bySettingHour: 17, minute: 30, second: 0, of: Date())!

        XCTAssertEqual(
            HomeRaces.TodayRaces.firstFinishTime([
                next("Late", finishDate: late),
                next("Early", finishDate: early),
                next("Unknown", finishDate: nil)
            ]),
            "14:05"
        )
    }

    func testNoFinishTimeMeansNoFirstFinishLine() {
        XCTAssertNil(HomeRaces.TodayRaces.firstFinishTime([]))
        XCTAssertNil(HomeRaces.TodayRaces.firstFinishTime([next("Unknown", finishDate: nil)]))
    }
}
