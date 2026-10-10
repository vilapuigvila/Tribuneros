//
//  LocalizationCXTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

/// The CX Zone display strings in Catalan, and the scraped English text they still have to match.
final class LocalizationCXTests: XCTestCase {

    override func setUp() {
        super.setUp()
        L10n.setLanguage("ca")
    }

    override func tearDown() {
        L10n.setLanguage("en")
        super.tearDown()
    }

    // MARK: - Series and classes -

    func testSeriesTitlesTranslateButProperNamesStay() {
        XCTAssertEqual(CXRaces.RaceSeries.worldCup.title, "Copa del Món")
        XCTAssertEqual(CXRaces.RaceSeries.championships.title, "Campionats")
        XCTAssertEqual(CXRaces.RaceSeries.otherBelgian.title, "Altres belgues")
        XCTAssertEqual(CXRaces.RaceSeries.others.title, "Altres")
        XCTAssertEqual(CXRaces.RaceSeries.superprestige.title, "Superprestige")
        XCTAssertEqual(CXRaces.RaceSeries.x2oTrofee.title, "X2O Trofee")
        XCTAssertEqual(CXRaces.RaceSeries.exactCross.title, "Exact Cross")
    }

    func testRaceClassDescriptionsTranslate() {
        XCTAssertEqual(CXRaces.raceClassDescription("CDM"), "Copa del Món UCI")
        XCTAssertEqual(CXRaces.raceClassDescription(" cm "), "Campionats del món UCI")
        XCTAssertEqual(CXRaces.raceClassDescription("C1"), "Classe 1 de l’UCI")
        XCTAssertNil(CXRaces.raceClassDescription("C4"))
    }

    /// The series is inferred from the scraped English race name and class, not the display title,
    /// so it keeps working in every language.
    func testSeriesInferenceStillReadsScrapedEnglish() {
        XCTAssertEqual(
            CXRaces.RaceSeries.of(race: "Belgian National Championships", raceClass: "CN", country: "Belgium"),
            .championships
        )
        XCTAssertEqual(
            CXRaces.RaceSeries.of(race: "UCI World Cup Antwerpen", raceClass: "CDM", country: "Belgium"),
            .worldCup
        )
        XCTAssertEqual(
            CXRaces.RaceSeries.of(race: "Cyclocross Otegem", raceClass: "C2", country: "Belgium"),
            .otherBelgian
        )
        // The ids behind the filter chips stay English.
        XCTAssertEqual(
            CXRaces.RaceSeries.allCases.map(\.rawValue),
            ["worldCup", "superprestige", "x2oTrofee", "exactCross", "championships", "otherBelgian", "others"]
        )
    }

    // MARK: - Search -

    /// The calendar search also reads the translated series title, so a Catalan word finds the race.
    func testCalendarSearchMatchesTheTranslatedSeries() {
        let event = calendarEvent(
            race: "UCI World Championships Liévin",
            raceClass: "CM",
            country: "France"
        )

        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "campionats"))
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "lievin"))
        XCTAssertTrue(CXRaces.calendarEvent(event, matches: "cm campionats"))
        XCTAssertFalse(CXRaces.calendarEvent(event, matches: "copa"))
    }

    func testStandingsSearchStillMatchesScrapedNames() {
        let standings = DTO.CXStandings(items: [
            .init(
                title: "UCI Ranking Cyclocross", // l10n:ignore
                url: nil,
                logoURL: nil,
                categories: [
                    .init(
                        title: "Men Elite", // l10n:ignore
                        url: nil,
                        leaders: [
                            .init(
                                position: 1,
                                rider: "VANTHOURENHOUT Michael",
                                riderURL: nil,
                                countryFlagURL: nil,
                                points: "2058"
                            )
                        ],
                        leaderImageURL: nil
                    )
                ]
            )
        ])

        XCTAssertEqual(CXRaces.standings(standings, matching: "vanthourenhout").items.count, 1)
        XCTAssertTrue(CXRaces.standings(standings, matching: "nys").items.isEmpty)
    }

    // MARK: - Dates and labels -

    func testDisplayDateFollowsTheActiveLanguage() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 4)))

        // Catalan grammar comes from the locale ("4 de gener de 2026"); assert the parts only.
        let short = CXRaces.displayDate(date)
        XCTAssertTrue(short.hasPrefix("4 de gener"), short)
        XCTAssertTrue(short.contains("2026"), short)
        let long = CXRaces.displayDate(date, pattern: "EEEE d MMMM yyyy")
        XCTAssertTrue(long.contains("diumenge"), long)
        XCTAssertTrue(long.contains("4 de gener"), long)
    }

    func testWinnerAndRiderContextUseTheTranslatedLabels() {
        let event = calendarEvent(
            date: "04-01-2026",
            race: "X2O Badkamers Trofee - Middelkerke",
            raceClass: "C1",
            country: "Belgium",
            winnerName: "VAN DER POEL Mathieu"
        )
        let winner = CXRaces.Winner(event: event, result: nil)

        XCTAssertTrue(winner.dateText.hasPrefix("4 de gener"), winner.dateText)
        XCTAssertEqual(CXRaces.RiderContext.win(winner).category, "Elit masculina")
        // Parsing the scraped date is unchanged by the display formatting.
        XCTAssertNotNil(event.eventDate)
    }

    func testErrorMessageIsFriendlyAndTranslated() {
        XCTAssertEqual(
            CXRaces.ErrorView.unknown.message,
            "No s’han pogut carregar les curses de ciclocròs. Comprova la connexió i torna-ho a provar."
        )
    }

    func testCountdownAndCategoryCountPluralise() {
        XCTAssertEqual(L10n.tr("In %lld days", 3), "D’aquí a 3 dies")
        XCTAssertEqual(L10n.tr("In %lld days", 1), "D’aquí a 1 dia")
        XCTAssertEqual(L10n.tr("%lld categories", 1), "1 categoria")
        XCTAssertEqual(L10n.tr("%lld categories", 2), "2 categories")
    }

    func testCalendarAndStatusLabelsTranslate() {
        XCTAssertEqual(L10n.tr("Cancelled"), "Cancel·lada")
        XCTAssertEqual(L10n.tr("No races in this series."), "No hi ha curses en aquesta sèrie.")
        XCTAssertEqual(L10n.tr("No races match “%@”.", "poel"), "No hi ha curses que coincideixin amb “poel”.")
        XCTAssertEqual(L10n.tr("CX ZONE"), "ZONA CX")
        XCTAssertEqual(L10n.tr("MEN ELITE · TOP %lld", 10), "ELIT MASCULINA · TOP 10")
    }

    // MARK: - Helpers -

    private func calendarEvent(
        date: String = "04-01-2026",
        race: String,
        raceClass: String,
        country: String?,
        winnerName: String = ""
    ) -> DTO.CXCalendarEvent {
        .init(
            date: date,
            race: race,
            raceClass: raceClass,
            flagURL: nil,
            winnerName: winnerName,
            isCancelled: false,
            raceID: nil,
            raceSlug: nil,
            raceURL: nil,
            resultsURL: nil,
            videoURL: nil,
            websiteURL: nil,
            raceCountry: country,
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )
    }
}
