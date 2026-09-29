//
//  CXEventDetailTests.swift
//  TribunerosTests
//
//  Created by albert vila on 29/9/26.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class CXEventDetailTests: XCTestCase {

    // MARK: - Race series -

    func testSeriesIsInferredFromNameAndClass() {
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "UCI World Cup Antwerpen", raceClass: "CDM", country: "Belgium"), .worldCup)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Namur", raceClass: "CDM", country: "Belgium"), .worldCup)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Superprestige Ruddervoorde", raceClass: "C1", country: "Belgium"), .superprestige)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "X2O Badkamers Trofee - Koppenbergcross", raceClass: "C1", country: "Belgium"), .x2oTrofee)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Exact Cross Mol", raceClass: "C1", country: "Belgium"), .exactCross)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "UCI World Championships Liévin", raceClass: "CM", country: "France"), .championships)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Belgian National Championships", raceClass: "CN", country: "Belgium"), .championships)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Cyclocross Otegem", raceClass: "C2", country: "Belgium"), .otherBelgian)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Trek USCX #3 - Rochester Cyclocross", raceClass: "C1", country: "United States"), .others)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Cross4Life Copenhagen", raceClass: "C2", country: nil), .others)
    }

    // MARK: - Calendar search -

    func testCalendarSearchMatchesEveryWordAcrossFields() {
        let event = DTO.CXCalendarEvent(
            date: "01-02-2026",
            race: "UCI World Championships Liévin",
            raceClass: "CM",
            flagURL: nil,
            winnerName: "VAN DER POEL Mathieu",
            isCancelled: false,
            raceID: nil,
            raceSlug: nil,
            raceURL: nil,
            resultsURL: nil,
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "France",
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )

        XCTAssertTrue(CXRaces.calendarEvent(event, matches: ""))
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "   "))
        // Case- and accent-insensitive, on the race name.
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "lievin"))
        // Country, winner, class and series.
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "france"))
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "poel"))
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "cm"))
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "championships"))
        // Every word must match, in any field and any order.
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "poel france"))
        XCTAssertFalse(CXRaces.calendarEvent(event, matches: "poel belgium"))
        XCTAssertFalse(CXRaces.calendarEvent(event, matches: "koksijde"))
    }

    // MARK: - Standings search -

    func testStandingsSearchFiltersRankingsCategoriesAndRiders() {
        func leader(_ position: Int, _ rider: String) -> DTO.CXStandings.Leader {
            .init(
                position: position,
                rider: rider,
                riderURL: nil,
                countryFlagURL: nil,
                points: ""
            )
        }
        func category(_ title: String, _ leaders: [DTO.CXStandings.Leader]) -> DTO.CXStandings.Category {
            .init(
                title: title,
                url: nil,
                leaders: leaders,
                leaderImageURL: nil
            )
        }
        func item(_ title: String, _ categories: [DTO.CXStandings.Category]) -> DTO.CXStandings.Item {
            .init(
                title: title,
                url: nil,
                logoURL: nil,
                categories: categories
            )
        }
        let standings = DTO.CXStandings(items: [
            item("UCI Ranking", [
                category("Men Elite", [leader(1, "VANTHOURENHOUT Michael"), leader(2, "VAN DER POEL Mathieu")]),
                category("Women Elite", [leader(1, "VAN EMPEL Fem"), leader(2, "ALVARADO Ceylin")])
            ]),
            item("Superprestige", [
                category("Men Elite", [leader(1, "ISERBYT Eli"), leader(2, "VANTHOURENHOUT Michael")])
            ])
        ])

        XCTAssertEqual(CXRaces.standings(standings, matching: " "), standings)

        // A rider: only their rows stay, in every ranking they appear in.
        let rider = CXRaces.standings(standings, matching: "vanthourenhout")
        XCTAssertEqual(rider.items.map(\.title), ["UCI Ranking", "Superprestige"])
        XCTAssertEqual(rider.items[0].categories.map(\.title), ["Men Elite"])
        XCTAssertEqual(rider.items[0].categories[0].leaders.map(\.position), [1])

        // A ranking keeps everything; a category keeps all its riders.
        XCTAssertEqual(CXRaces.standings(standings, matching: "superprestige").items, [standings.items[1]])
        let women = CXRaces.standings(standings, matching: "women")
        XCTAssertEqual(women.items.map(\.title), ["UCI Ranking"])
        XCTAssertEqual(women.items[0].categories, [standings.items[0].categories[1]])

        // Words combine across levels, ignoring accents.
        let combined = CXRaces.standings(standings, matching: "superprestige iserbyt")
        XCTAssertEqual(combined.items.map(\.title), ["Superprestige"])
        XCTAssertEqual(combined.items[0].categories[0].leaders.map(\.rider), ["ISERBYT Eli"])
        XCTAssertEqual(CXRaces.standings(standings, matching: "émpel").items.count, 1)
        XCTAssertTrue(CXRaces.standings(standings, matching: "nys").items.isEmpty)
    }

    // MARK: - Winner -

    func testPastWinnerBuildsWinnerForItsEdition() {
        let event = DTO.CXCalendarEvent(
            date: "04-01-2026",
            race: "X2O Badkamers Trofee - Middelkerke",
            raceClass: "C1",
            flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
            winnerName: "VAN DER POEL Mathieu",
            isCancelled: false,
            raceID: 18001,
            raceSlug: "middelkerke",
            raceURL: URL(string: "https://cyclocross24.com/race/middelkerke/"),
            resultsURL: URL(string: "https://cyclocross24.com/race/18001/"),
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "Belgium",
            winnerURL: URL(string: "https://cyclocross24.com/rider/mathieu-van-der-poel/"),
            winnerCountry: "Netherlands",
            winnerFlagURL: nil
        )
        let pastWinner = DTO.CXRacePage.PastWinner(
            year: "2024",
            rider: "ISERBYT Eli",
            riderURL: URL(string: "https://cyclocross24.com/rider/eli-iserbyt/"),
            countryFlagURL: nil,
            resultsURL: URL(string: "https://cyclocross24.com/race/17001/")
        )

        let winner = CXRaces.Winner(event: event, pastWinner: pastWinner)

        XCTAssertEqual(winner.name, "ISERBYT Eli")
        XCTAssertEqual(winner.dateText, "2024")
        XCTAssertEqual(winner.race, event.race)
        XCTAssertEqual(winner.series, .x2oTrofee)
        XCTAssertNil(winner.country)
        XCTAssertNil(winner.result)
        // The past edition's results, not this season's.
        XCTAssertEqual(winner.resultsURL, pastWinner.resultsURL)
        XCTAssertEqual(winner.riderURL, pastWinner.riderURL)
        // Opening the race from the winner screen shows that edition, not this season's.
        XCTAssertEqual(winner.raceEvent.date, "2024")
        XCTAssertEqual(winner.raceEvent.winnerName, "ISERBYT Eli")
        XCTAssertEqual(winner.raceEvent.resultsURL, pastWinner.resultsURL)
        XCTAssertEqual(winner.raceEvent.raceID, 17001)
        XCTAssertEqual(winner.raceEvent.raceURL, event.raceURL)
        XCTAssertEqual(
            CXRaces.Winner(event: event, result: nil).raceEvent,
            event
        )
        // The rider screen opened from a "Past winners" row.
        let context = CXRaces.RiderContext.win(winner)
        XCTAssertEqual(context.rider, "ISERBYT Eli")
        XCTAssertEqual(context.riderURL, pastWinner.riderURL)
        XCTAssertEqual(context.position, "1")
        XCTAssertNil(context.team)
        // Its winning row (time, team, age) loads from that edition's results page...
        XCTAssertEqual(context.winResultsURL, pastWinner.resultsURL)
        // ...unless the winner already carries it.
        let loadedRow = DTO.CX24Homepage.CategoryResult(
            position: "1",
            rider: "VAN DER POEL Mathieu",
            age: "31",
            team: "Alpecin - Deceuninck",
            time: "59:36",
            countryFlagURL: nil,
            raceVideosURL: nil
        )
        let loadedWinner = CXRaces.Winner(
            event: event,
            result: loadedRow
        )
        XCTAssertNil(CXRaces.RiderContext.win(loadedWinner).winResultsURL)
    }

    func testRecentResultWinBuildsWinnerForThatRace() {
        let rider = CXRaces.RiderRef(
            name: "Mathieu van der Poel",
            riderURL: URL(string: "https://cyclocross24.com/rider/mathieu-van-der-poel/"),
            flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
            country: "Netherlands"
        )
        let row = DTO.CXRiderPage.Result(
            date: "5/1/2025",
            race: "Zonhoven",
            position: "1",
            raceURL: URL(string: "https://cyclocross24.com/race/16500/")
        )
        // Outside this season's calendar: a minimal race built from the row.
        let raceEvent = CXRaces.calendarEvent(for: row, in: [])

        let winner = CXRaces.Winner(riderResult: row, rider: rider, raceEvent: raceEvent)

        XCTAssertEqual(winner.name, "Mathieu van der Poel")
        XCTAssertEqual(winner.riderURL, rider.riderURL)
        XCTAssertEqual(winner.country, "Netherlands")
        XCTAssertEqual(winner.race, "Zonhoven")
        XCTAssertEqual(winner.dateText, "5 January 2025")
        XCTAssertEqual(winner.resultsURL, row.raceURL)
        XCTAssertNil(winner.result)
        // The built race gets this rider as its winner; everything else is kept.
        XCTAssertEqual(winner.raceEvent.winnerName, "Mathieu van der Poel")
        XCTAssertEqual(winner.raceEvent.winnerURL, rider.riderURL)
        XCTAssertEqual(winner.raceEvent.resultsURL, raceEvent.resultsURL)
        XCTAssertEqual(winner.raceEvent.date, raceEvent.date)
    }

    // MARK: - Rider standing -

    func testRiderStandingCombinesLeaderCategoryAndRanking() {
        let item = DTO.CXStandings.Item(
            title: "UCI Ranking Cyclocross",
            url: URL(string: "https://cyclocross24.com/uciranking/"),
            logoURL: nil,
            categories: []
        )
        let leader = DTO.CXStandings.Leader(
            position: 2,
            rider: "VAN DER POEL Mathieu",
            riderURL: URL(string: "https://cyclocross24.com/rider/mathieu-van-der-poel/"),
            countryFlagURL: nil,
            points: "2040"
        )
        let withURL = DTO.CXStandings.Category(
            title: "Men Elite",
            url: URL(string: "https://cyclocross24.com/uciranking/2025-2026/ME/"),
            leaders: [leader],
            leaderImageURL: nil
        )
        let withoutURL = DTO.CXStandings.Category(
            title: "Men Elite",
            url: nil,
            leaders: [leader],
            leaderImageURL: nil
        )

        let standing = CXRaces.RiderStanding(leader: leader, category: withURL, item: item)

        XCTAssertEqual(standing.rider, "VAN DER POEL Mathieu")
        XCTAssertEqual(standing.riderURL, leader.riderURL)
        XCTAssertEqual(standing.position, 2)
        XCTAssertEqual(standing.points, "2040")
        XCTAssertEqual(standing.rankingTitle, "UCI Ranking Cyclocross")
        XCTAssertEqual(standing.category, "Men Elite")
        XCTAssertEqual(standing.standingsURL, withURL.url)
        // Without a category page, fall back to the ranking's.
        XCTAssertEqual(
            CXRaces.RiderStanding(leader: leader, category: withoutURL, item: item).standingsURL,
            item.url
        )
    }

    func testRiderPodiumAndContextCarryTheRider() {
        let podium = DTO.CX24Homepage.Podium(
            position: 2,
            rider: "DEL GROSSO Tibor",
            riderURL: URL(string: "https://cyclocross24.com/rider/tibor-del-grosso/"),
            country: "Netherlands",
            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
            time: "0:45"
        )
        let category = DTO.CX24Homepage.Category(
            title: "Men Elite",
            categoryURL: nil,
            winnerImageURL: nil,
            podium: [podium]
        )
        let race = DTO.CX24Homepage.Race(
            title: "UCI World Cup Zonhoven (CDM)",
            country: "Belgium",
            countryFlagURL: nil,
            date: "4 January 2026",
            location: "Zonhoven, Belgium",
            raceURL: nil,
            categories: [category]
        )

        let riderPodium = CXRaces.RiderPodium(podium: podium, category: category, race: race)
        let context = CXRaces.RiderContext.podium(riderPodium)

        XCTAssertEqual(riderPodium.time, "0:45")
        XCTAssertEqual(riderPodium.race, race)
        XCTAssertEqual(context.rider, "DEL GROSSO Tibor")
        XCTAssertEqual(context.riderURL, podium.riderURL)
        XCTAssertEqual(context.flagURL, podium.countryFlagURL)
        XCTAssertEqual(context.position, "2")
        XCTAssertEqual(context.category, "Men Elite")
        XCTAssertEqual(context.country, "Netherlands")
    }

    func testRiderResultFromCalendarEventAndWinnerRiderFallback() {
        let row = DTO.CX24Homepage.CategoryResult(
            position: "1",
            rider: "ISERBYT Eli",
            age: "26",
            team: "Pauwels Sauzen",
            time: "1:01:12",
            countryFlagURL: nil,
            raceVideosURL: nil,
            riderURL: URL(string: "https://cyclocross24.com/rider/eli-iserbyt/")
        )
        // A race reached from a rider's recent results: no calendar winner or rider link.
        let event = DTO.CXCalendarEvent(
            date: "05-01-2025",
            race: "Zonhoven",
            raceClass: "",
            flagURL: nil,
            winnerName: "",
            isCancelled: false,
            raceID: 16500,
            raceSlug: nil,
            raceURL: nil,
            resultsURL: URL(string: "https://cyclocross24.com/race/16500/"),
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "Belgium",
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )

        let context = CXRaces.RiderContext.result(CXRaces.RiderResult(result: row, event: event))

        XCTAssertEqual(context.rider, "ISERBYT Eli")
        XCTAssertEqual(context.riderURL, row.riderURL)
        XCTAssertEqual(context.position, "1")
        XCTAssertEqual(context.category, "Men Elite")
        XCTAssertEqual(context.team, "Pauwels Sauzen")
        XCTAssertNil(context.country)
        // The winner screen falls back to the results row's rider link.
        let winner = CXRaces.Winner(event: event, result: row)
        XCTAssertEqual(winner.name, "ISERBYT Eli")
        XCTAssertEqual(winner.riderURL, row.riderURL)
    }

    func testRiderPageFactLookup() {
        let page = DTO.CXRiderPage(
            name: "",
            avatarURL: nil,
            facts: [
                .init(label: "Nationality", value: "Belgium"),
                .init(label: "Current team", value: "Crelan - Corendon")
            ],
            results: []
        )

        XCTAssertEqual(page.nationality, "Belgium")
        XCTAssertEqual(page.team, "Crelan - Corendon")
        XCTAssertNil(page.fact(containing: "height"))
    }

    // MARK: - Rider result → calendar event -

    private func calendarEvent(
        date: String,
        race: String,
        resultsID: Int
    ) -> DTO.CXCalendarEvent {
        .init(
            date: date,
            race: race,
            raceClass: "C1",
            flagURL: nil,
            winnerName: "",
            isCancelled: false,
            raceID: resultsID,
            raceSlug: nil,
            raceURL: nil,
            resultsURL: URL(string: "https://cyclocross24.com/race/\(resultsID)/"),
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "Belgium",
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )
    }

    func testRiderResultMatchesCalendarEventByLinkOrDateAndName() {
        let calendar = [
            calendarEvent(date: "28-12-2025", race: "UCI World Cup Dendermonde", resultsID: 17990),
            calendarEvent(date: "04-01-2026", race: "X2O Badkamers Trofee - Middelkerke", resultsID: 18001)
        ]

        let byLink = CXRaces.calendarEvent(
            for: .init(date: "28-12-2025", race: "Dendermonde", position: "2", raceURL: URL(string: "/race/17990", relativeTo: URL(string: "https://cyclocross24.com"))),
            in: calendar
        )
        XCTAssertEqual(byLink, calendar[0])

        let byDateAndName = CXRaces.calendarEvent(
            for: .init(date: "4.1.2026", race: "Middelkerke", position: "1", raceURL: nil),
            in: calendar
        )
        XCTAssertEqual(byDateAndName, calendar[1])
    }

    func testRiderResultOutsideCalendarBuildsMinimalEvent() {
        let event = CXRaces.calendarEvent(
            for: .init(date: "5/1/2025", race: "Zonhoven", position: "3", raceURL: URL(string: "https://cyclocross24.com/race/16500/")),
            in: []
        )

        XCTAssertEqual(event.date, "05-01-2025")
        XCTAssertEqual(event.race, "Zonhoven")
        XCTAssertEqual(event.raceID, 16500)
        XCTAssertEqual(event.resultsURL?.absoluteString, "https://cyclocross24.com/race/16500/")
        XCTAssertNil(event.raceURL)
        XCTAssertTrue(event.winnerName.isEmpty)
    }

    // MARK: - Race page parsing -

    func testRacePageParsesWinnersByYear() throws {
        let html = """
        <html>
          <head><meta name="description" content="Beach cyclocross in Middelkerke."></head>
          <body>
            <h1 class="main_title">Middelkerke</h1>
            <table>
              <tr><th>Year</th><th>Winner</th></tr>
              <tr class="r1_row">
                <td>2024</td>
                <td><img class="flag" src="/images/flag/32/Belgium.png"><a class="rurl" href="/rider/eli-iserbyt/">ISERBYT Eli</a></td>
                <td><a href="/race/17001/">Results</a></td>
              </tr>
              <tr class="r1_row">
                <td>03-01-2025</td>
                <td><img class="flag" src="/images/flag/32/Netherlands.png"><a class="rurl" href="/rider/mathieu-van-der-poel/">VAN DER POEL Mathieu</a></td>
                <td><a href="/race/middelkerke/">Race</a><a href="/race/18001/">Results</a></td>
              </tr>
            </table>
            <table>
              <tr class="r1_row"><td>1</td><td><a href="/rider/no-year/">NO YEAR Rider</a></td><td>27</td></tr>
            </table>
          </body>
        </html>
        """

        let page = try Service.parseCx24RacePage(SwiftSoup.parse(html))

        XCTAssertEqual(page.title, "Middelkerke")
        XCTAssertEqual(page.summary, "Beach cyclocross in Middelkerke.")
        XCTAssertEqual(page.pastWinners.map(\.year), ["2025", "2024"])
        XCTAssertEqual(page.pastWinners.first?.rider, "VAN DER POEL Mathieu")
        XCTAssertEqual(page.pastWinners.first?.resultsURL?.absoluteString, "https://cyclocross24.com/race/18001/")
        XCTAssertEqual(page.pastWinners.first?.riderURL?.absoluteString, "https://cyclocross24.com/rider/mathieu-van-der-poel/")
        XCTAssertEqual(page.pastWinners.first?.countryFlagURL?.absoluteString, "https://cyclocross24.com/images/flag/32/Netherlands.png")
    }

    func testRacePageWithoutEditionsIsEmpty() throws {
        let page = try Service.parseCx24RacePage(SwiftSoup.parse("<html><body><h1>Race</h1></body></html>"))

        XCTAssertEqual(page.title, "Race")
        XCTAssertTrue(page.summary.isEmpty)
        XCTAssertTrue(page.pastWinners.isEmpty)
    }

    // MARK: - Rider page parsing -

    func testRiderPageParsesAvatarFactsAndResults() throws {
        let html = """
        <html><body>
          <h1 class="main_title">Mathieu van der Poel</h1>
          <img class="rider-avatar__image" src="/images/rider/mathieu-van-der-poel-kL0.png">
          <dl><dt>Date of birth:</dt><dd>19 January 1995</dd></dl>
          <table>
            <tr><td>Team</td><td>Alpecin - Deceuninck</td></tr>
            <tr><td>1</td><td><a href="/rider/other-rider/">OTHER Rider</a></td></tr>
          </table>
          <table>
            <tr><th>Date</th><th>Race</th><th>Pos</th></tr>
            <tr><td>04-01-2026</td><td><a href="/race/18001/">X2O Trofee Middelkerke</a></td><td>1</td></tr>
            <tr><td>28-12-2025</td><td><a href="/race/17990/">UCI World Cup Dendermonde</a></td><td>2.</td></tr>
          </table>
        </body></html>
        """

        let page = try Service.parseCx24RiderPage(SwiftSoup.parse(html))

        XCTAssertEqual(page.name, "Mathieu van der Poel")
        XCTAssertEqual(page.avatarURL?.absoluteString, "https://cyclocross24.com/images/rider/mathieu-van-der-poel-kL0.png")
        XCTAssertEqual(page.facts.map(\.label), ["Date of birth", "Team"])
        XCTAssertEqual(page.facts.last?.value, "Alpecin - Deceuninck")
        XCTAssertEqual(page.results.map(\.position), ["1", "2"])
        XCTAssertEqual(page.results.first?.date, "04-01-2026")
        XCTAssertEqual(page.results.first?.race, "X2O Trofee Middelkerke")
        XCTAssertEqual(page.results.first?.raceURL?.absoluteString, "https://cyclocross24.com/race/18001/")
    }
}
