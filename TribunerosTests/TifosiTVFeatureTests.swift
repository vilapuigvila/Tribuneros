//
//  TifosiTVFeatureTests.swift
//  TribunerosTests
//
//  The TV guide's featured race: the use case behind "Where to watch" on Race info, and the deck order.
//

import XCTest
@testable import Tribuneros

@MainActor
final class TifosiTVFeatureTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func race(
        _ name: String,
        startsIn minutes: Double
    ) -> DTO.CourseDuJourPage.Race {
        DTO.CourseDuJourPage.Race(
            name: name,
            stage: nil,
            category: "1.1 (Men)",
            location: "",
            start: now.addingTimeInterval(minutes * 60),
            end: now.addingTimeInterval((minutes + 180) * 60),
            broadcasters: []
        )
    }

    private func page(
        date: String,
        races: [DTO.CourseDuJourPage.Race]
    ) -> DTO.CourseDuJourPage {
        DTO.CourseDuJourPage(
            date: date,
            heading: "",
            updatedAt: nil,
            days: [],
            sections: [DTO.CourseDuJourPage.Section(discipline: "Road", caption: "", races: races)]
        )
    }

    private func interactor() -> Tifosi.InteractorImpl {
        Tifosi.InteractorImpl { day in
            self.page(
                date: day ?? "2026-10-27",
                races: [self.race("Race \(day ?? "today")", startsIn: 60)]
            )
        }
    }

    private func settle(_ interactor: Tifosi.InteractorImpl) async {
        for _ in 0..<50 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 10_000_000)
            let domain = interactor.domain
            if case .loaded = domain.tv, case .loaded = domain.tvSelectedLoad { return }
        }
    }

    // MARK: - Use case -

    func testFeatureSelectsTVChipDayAndRaceID() async {
        let interactor = interactor()
        interactor.useCase(.appear)
        await settle(interactor)

        interactor.useCase(.feature(raceID: "abc", day: "2026-10-29"))
        await settle(interactor)

        XCTAssertEqual(interactor.domain.filter, .tv)
        XCTAssertEqual(interactor.domain.tvDay, "2026-10-29")
        XCTAssertEqual(interactor.domain.featuredRaceID, "abc")
        guard case .loaded(let loaded) = interactor.domain.tvSelectedLoad else {
            return XCTFail("The featured day should load")
        }
        XCTAssertEqual(loaded.date, "2026-10-29")
    }

    func testFeatureOnTodayMapsToNilDay() async {
        let interactor = interactor()
        interactor.useCase(.appear)
        await settle(interactor)

        interactor.useCase(.feature(raceID: "abc", day: "2026-10-27"))

        XCTAssertNil(interactor.domain.tvDay)
        XCTAssertEqual(interactor.domain.featuredRaceID, "abc")
    }

    func testFeatureBeforeTodayLoadedNormalisesTodayToNilDay() async {
        let interactor = interactor()

        interactor.useCase(.feature(raceID: nil, day: "2026-10-27"))
        await settle(interactor)

        XCTAssertNil(interactor.domain.tvDay)
        XCTAssertNil(interactor.domain.featuredRaceID)
        XCTAssertEqual(interactor.domain.filter, .tv)
    }

    func testManualDayChangeClearsTheFeature() async {
        let interactor = interactor()
        interactor.useCase(.feature(raceID: "abc", day: "2026-10-29"))
        await settle(interactor)

        interactor.useCase(.selectTVDay("2026-10-30"))

        XCTAssertNil(interactor.domain.featuredRaceID)
        XCTAssertEqual(interactor.domain.tvDay, "2026-10-30")
    }

    func testUnavailableChipKeepsTheFeature() async {
        let interactor = interactor()
        interactor.useCase(.feature(raceID: "abc", day: "2026-10-29"))
        await settle(interactor)

        interactor.useCase(.selectChannel(.radio))
        XCTAssertEqual(interactor.domain.featuredRaceID, "abc", "Radio isn't available, so nothing changed")
    }

    func testViewModelMapsTheFeaturedID() {
        var domain = Tifosi.InteractorImpl().domain
        domain.featuredRaceID = "abc"

        let state = Tifosi.ViewModel<Tifosi.InteractorImpl>.mapToViewState(from: domain)

        XCTAssertEqual(state.tv.featuredRaceID, "abc")
    }

    // MARK: - Deck -

    private func guide() -> Tifosi.TVGuide {
        func tvRace(
            _ id: String,
            _ minutes: Double
        ) -> Tifosi.TVRace {
            Tifosi.TVRace(
                id: id,
                title: id,
                meta: "",
                discipline: "Road",
                start: now.addingTimeInterval(minutes * 60),
                end: now.addingTimeInterval((minutes + 180) * 60),
                startText: "",
                channels: []
            )
        }
        return Tifosi.TVGuide(races: [tvRace("a", 10), tvRace("b", 60), tvRace("c", 120)])
    }

    func testDeckPutsTheFeaturedCardFirstAndKeepsTheRestInOrder() {
        let deck = guide().deck(
            now: now,
            featured: "c"
        )

        XCTAssertEqual(deck.map(\.id), ["c", "a", "b"])
    }

    func testDeckIgnoresAMissingOrNilFeaturedID() {
        let plain = guide().deck(now: now).map(\.id)

        XCTAssertEqual(plain, ["a", "b", "c"])
        XCTAssertEqual(guide().deck(now: now, featured: nil).map(\.id), plain)
        XCTAssertEqual(guide().deck(now: now, featured: "zzz").map(\.id), plain)
    }
}
