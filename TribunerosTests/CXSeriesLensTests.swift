//
//  CXSeriesLensTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

/// What the CX Zone screen derives for a series: its rounds, next and last round, leaders and podium.
final class CXSeriesLensTests: XCTestCase {

    private let now = Date()

    // MARK: - Fixtures -

    private func event(
        daysFromNow days: Int,
        race: String,
        raceClass: String = "C1",
        winner: String = "",
        isCancelled: Bool = false
    ) -> DTO.CXCalendarEvent {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: now
        )!
        return .init(
            date: formatter.string(from: date),
            race: race,
            raceClass: raceClass,
            flagURL: nil,
            winnerName: winner,
            isCancelled: isCancelled,
            raceID: nil,
            raceSlug: nil,
            raceURL: nil,
            resultsURL: nil,
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "Belgium",
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )
    }

    private func leaders(_ points: [String]) -> [DTO.CXStandings.Leader] {
        points.enumerated().map { index, points in
            .init(
                position: index + 1,
                rider: "RIDER \(index + 1)",
                riderURL: nil,
                countryFlagURL: nil,
                points: points
            )
        }
    }

    private func representable(
        events: [DTO.CXCalendarEvent],
        races: [DTO.CX24Homepage.Race] = [],
        standings: [DTO.CXStandings.Item] = []
    ) -> CXRaces.Representable {
        .init(
            calendarEvents: events,
            races: .init(sections: [.init(title: "Latest results", races: races)]),
            standings: .init(items: standings)
        )
    }

    private var worldCupEvents: [DTO.CXCalendarEvent] {
        [
            event(daysFromNow: 20, race: "World Cup Namur", raceClass: "CDM"),
            event(daysFromNow: -30, race: "World Cup Zonhoven", raceClass: "CDM", winner: "Winner One"),
            event(daysFromNow: 3, race: "World Cup Tabor", raceClass: "CDM"),
            event(daysFromNow: -1, race: "World Cup Maasmechelen", raceClass: "CDM", winner: "Winner Two"),
            event(daysFromNow: 10, race: "World Cup Flamanville", raceClass: "CDM"),
            event(daysFromNow: 40, race: "World Cup Hoogerheide", raceClass: "CDM"),
            event(daysFromNow: 5, race: "Superprestige Niel", raceClass: "C1"),
            event(daysFromNow: 6, race: "World Cup Cancelled", raceClass: "CDM", isCancelled: true)
        ]
    }

    // MARK: - Rounds -

    func testRoundsAreOrderedByDateAndSkipCancelledOnes() {
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(events: worldCupEvents),
            now: now
        )
        XCTAssertEqual(
            lens.rounds.map(\.event.race),
            [
                "World Cup Zonhoven",
                "World Cup Maasmechelen",
                "World Cup Tabor",
                "World Cup Flamanville",
                "World Cup Namur",
                "World Cup Hoogerheide"
            ]
        )
        XCTAssertEqual(lens.rounds.map(\.number), Array(1...6))
    }

    func testNextLastAndRoundsLeft() {
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(events: worldCupEvents),
            now: now
        )
        XCTAssertEqual(lens.doneCount, 2)
        XCTAssertEqual(lens.nextRound?.event.race, "World Cup Tabor")
        XCTAssertEqual(lens.lastRound?.event.race, "World Cup Maasmechelen")
        XCTAssertEqual(
            lens.roundsLeft.map(\.number),
            [4, 5],
            "The rounds after the next one, numbered by their place in the season."
        )
        XCTAssertEqual(lens.days(to: lens.nextRound!, now: now), 3)
    }

    func testRoundsLeftStopAtTheLimit() {
        let events = (1...6).map { event(daysFromNow: $0, race: "World Cup \($0)", raceClass: "CDM") }
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(events: events),
            now: now
        )
        XCTAssertEqual(lens.roundsLeft.count, CXRaces.SeriesLens.roundsLeftLimit)
    }

    func testTodayCountsAsTheNextRound() {
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(
                events: [event(daysFromNow: 0, race: "World Cup Today", raceClass: "CDM")]
            ),
            now: now
        )
        XCTAssertEqual(lens.nextRound?.event.race, "World Cup Today")
        XCTAssertEqual(lens.days(to: lens.nextRound!, now: now), 0)
        XCTAssertNil(lens.lastRound)
    }

    func testFinishedSeasonHasNoNextRound() {
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(
                events: [event(daysFromNow: -3, race: "World Cup Last", raceClass: "CDM")]
            ),
            now: now
        )
        XCTAssertNil(lens.nextRound)
        XCTAssertTrue(lens.roundsLeft.isEmpty)
        XCTAssertEqual(lens.doneCount, 1)
    }

    func testAvailableSeriesFollowTheChipOrderAndSkipEmptyOnes() {
        XCTAssertEqual(
            CXRaces.SeriesLens.availableSeries(in: worldCupEvents),
            [.worldCup, .superprestige]
        )
        XCTAssertEqual(
            CXRaces.SeriesLens.availableSeries(
                in: [event(daysFromNow: 1, race: "Cancelled", isCancelled: true)]
            ),
            []
        )
    }

    // MARK: - Leaders -

    func testLeadersComeFromTheSeriesStandingsWithTheGapToSecond() {
        let standings: [DTO.CXStandings.Item] = [
            .init(
                title: "UCI Ranking Cyclocross",
                url: nil,
                logoURL: nil,
                categories: [.init(title: "Men Elite", url: nil, leaders: leaders(["999", "1"]), leaderImageURL: nil)]
            ),
            .init(
                title: "UCI World Cup",
                url: nil,
                logoURL: nil,
                categories: [
                    .init(title: "Men Elite", url: nil, leaders: leaders(["240", "198"]), leaderImageURL: nil),
                    .init(title: "Women Elite", url: nil, leaders: leaders(["215", "197"]), leaderImageURL: nil),
                    .init(title: "Men Junior", url: nil, leaders: leaders(["100", "90"]), leaderImageURL: nil)
                ]
            )
        ]
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(events: worldCupEvents, standings: standings),
            now: now
        )
        XCTAssertEqual(lens.leaders.map(\.standing.category), ["Men Elite", "Women Elite"])
        XCTAssertEqual(lens.leaders.map(\.gap), ["+42", "+18"])
        XCTAssertEqual(lens.leaders.first?.standing.points, "240")
    }

    func testLeaderGapIsHiddenWhenThePointsAreNotNumbers() {
        let standings: [DTO.CXStandings.Item] = [
            .init(
                title: "X2O Badkamers Trofee",
                url: nil,
                logoURL: nil,
                categories: [.init(title: "Men Elite", url: nil, leaders: leaders(["58:40", "59:18"]), leaderImageURL: nil)]
            )
        ]
        let lens = CXRaces.SeriesLens(
            series: .x2oTrofee,
            representable: representable(
                events: [event(daysFromNow: 4, race: "X2O Trofee Baal")],
                standings: standings
            ),
            now: now
        )
        XCTAssertEqual(lens.leaders.count, 1)
        XCTAssertNil(lens.leaders[0].gap)
    }

    func testSeriesWithoutStandingsHaveNoLeaders() {
        let lens = CXRaces.SeriesLens(
            series: .others,
            representable: representable(
                events: [event(daysFromNow: 4, race: "Local cross")],
                standings: [
                    .init(
                        title: "UCI World Cup",
                        url: nil,
                        logoURL: nil,
                        categories: [.init(title: "Men Elite", url: nil, leaders: leaders(["1"]), leaderImageURL: nil)]
                    )
                ]
            ),
            now: now
        )
        XCTAssertTrue(lens.leaders.isEmpty)
    }

    // MARK: - Last podium -

    private func latestRace(title: String) -> DTO.CX24Homepage.Race {
        .init(
            title: title,
            country: "Belgium",
            countryFlagURL: nil,
            date: "",
            location: "",
            raceURL: nil,
            categories: [
                .init(
                    title: "Women Elite",
                    categoryURL: nil,
                    winnerImageURL: nil,
                    podium: [.init(position: 1, rider: "WOMAN", riderURL: nil, country: "", countryFlagURL: nil, time: "50:00")]
                ),
                .init(
                    title: "Men Elite",
                    categoryURL: nil,
                    winnerImageURL: nil,
                    podium: (1...4).map {
                        .init(position: $0, rider: "MAN \($0)", riderURL: nil, country: "", countryFlagURL: nil, time: "0:0\($0)")
                    }
                )
            ]
        )
    }

    func testLastPodiumIsTheMatchingRaceMenEliteTopThree() {
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(
                events: worldCupEvents,
                races: [
                    latestRace(title: "Some other race"),
                    latestRace(title: "UCI World Cup Maasmechelen (CDM)")
                ]
            ),
            now: now
        )
        XCTAssertEqual(lens.lastPodium?.race.title, "UCI World Cup Maasmechelen (CDM)")
        XCTAssertEqual(lens.lastPodium?.category.title, "Men Elite")
        XCTAssertEqual(lens.lastPodium?.podium.map(\.rider), ["MAN 1", "MAN 2", "MAN 3"])
    }

    func testNoLastPodiumWithoutAMatchingLatestRace() {
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: representable(
                events: worldCupEvents,
                races: [latestRace(title: "Unrelated")]
            ),
            now: now
        )
        XCTAssertNil(lens.lastPodium)
        XCTAssertEqual(lens.lastRound?.event.winnerName, "Winner Two")
    }

    // MARK: - Latest result -

    func testLatestRaceIsTheFirstOfTheFirstNonEmptySection() {
        let homepage = DTO.CX24Homepage(sections: [
            .init(title: "Empty", races: []),
            .init(title: "Latest", races: [latestRace(title: "Newest"), latestRace(title: "Older")])
        ])
        XCTAssertEqual(CXRaces.SeriesLens.latestRace(in: homepage)?.title, "Newest")
        XCTAssertEqual(CXRaces.SeriesLens.otherLatestResultCount(in: homepage), 1)
    }

    func testNoLatestRaceWithoutResults() {
        let homepage = DTO.CX24Homepage(sections: [.init(title: "Empty", races: [])])
        XCTAssertNil(CXRaces.SeriesLens.latestRace(in: homepage))
        XCTAssertEqual(CXRaces.SeriesLens.otherLatestResultCount(in: homepage), 0)
    }

    func testWinnerIsTheMenEliteFirstPlace() {
        XCTAssertEqual(CXRaces.SeriesLens.winner(of: latestRace(title: "Race"))?.rider, "MAN 1")
    }

    // MARK: - Helpers -

    func testRiderInitialsTakeGivenNameThenSurname() {
        XCTAssertEqual(CXRaces.riderInitials("VAN DER POEL Mathieu"), "MV")
        XCTAssertEqual(CXRaces.riderInitials("NYS Thibau"), "TN")
        XCTAssertEqual(CXRaces.riderInitials("Pieterse"), "PP")
        XCTAssertEqual(CXRaces.riderInitials(""), "")
    }

    func testSeasonStartsInJuly() {
        func label(_ year: Int, _ month: Int) -> String {
            let date = Calendar.current.date(from: DateComponents(year: year, month: month, day: 15))!
            return CXRaces.SeriesLens.seasonLabel(now: date)
        }
        XCTAssertEqual(label(2026, 10), "2026–27")
        XCTAssertEqual(label(2027, 3), "2026–27")
        XCTAssertEqual(label(2027, 7), "2027–28")
        XCTAssertEqual(label(2099, 12), "2099–00")
    }

    func testPlaceholdersDrawTheFullLayout() {
        let lens = CXRaces.SeriesLens(
            series: .worldCup,
            representable: .placeholders,
            now: now
        )
        XCTAssertNotNil(lens.nextRound)
        XCTAssertNotNil(lens.lastRound)
        XCTAssertNotNil(lens.lastPodium)
        XCTAssertEqual(lens.leaders.count, 2)
        XCTAssertEqual(lens.roundsLeft.count, 2)
    }
}
