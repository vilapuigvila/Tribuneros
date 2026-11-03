//
//  PaddockDirectoryTests.swift
//  TribunerosTests
//
//  Paddock's Races | Teams section. The HTML below is synthetic, shaped like PCS's `races.php`
//  (the same table as the saved "latest results" page) and `teams.php` (headings, then team
//  links): replace it with real captures (taken with `URLSession`, not curl) when possible.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class PaddockDirectoryTests: XCTestCase {

    private let racesHTML = """
    <table class="basic"><tbody>
    <tr><td>2027-01-20</td><td><span class="flag au"></span> <a href="race/tour-down-under/2027/stage-1">Tour Down Under | Stage 1</a></td><td>2.UWT</td></tr>
    <tr><td>2027-01-21</td><td><span class="flag au"></span> <a href="race/tour-down-under/2027/stage-2">Tour Down Under | Stage 2</a></td><td>2.UWT</td></tr>
    <tr><td>2027-02-04</td><td><span class="flag es"></span> <a href="race/vuelta-a-murcia/2027/result">Vuelta a Murcia</a></td><td>1.1</td></tr>
    <tr><td>no link</td><td>nothing</td></tr>
    </tbody></table>
    """

    private let teamsHTML = """
    <h3>WorldTour</h3>
    <ul><li><span class="flag ae"></span> <a href="team/uae-team-emirates-xrg-2026">UAE Team Emirates - XRG</a></li>
    <li><a href="team/visma-lease-a-bike-2026">Visma | Lease a Bike</a></li></ul>
    <h3>ProTeams</h3>
    <ul><li><a href="team/tudor-pro-cycling-team-2026">Tudor Pro Cycling Team</a></li>
    <li><a href="team/tudor-pro-cycling-team-2026">Tudor Pro Cycling Team</a></li></ul>
    """

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Parsing

    func testRacesParseRowsAndKeepOneRowPerRace() throws {
        let races = Service.parsePCSRaces(try SwiftSoup.parse(racesHTML))
        XCTAssertEqual(races.map(\.name), ["Tour Down Under | Stage 1", "Vuelta a Murcia"])
        XCTAssertEqual(races[0].path, "race/tour-down-under/2027")
        XCTAssertEqual(races[0].raceClass, "2.UWT")
        XCTAssertEqual(races[0].countryCode, "au")
        XCTAssertEqual(races[1].dateText, "2027-02-04")
    }

    func testTeamsTakeTheDivisionFromTheHeadingAndSkipDuplicates() throws {
        let teams = Service.parsePCSTeams(try SwiftSoup.parse(teamsHTML))
        XCTAssertEqual(
            teams.map(\.name),
            ["UAE Team Emirates - XRG", "Visma | Lease a Bike", "Tudor Pro Cycling Team"]
        )
        XCTAssertEqual(teams.map(\.division), ["WorldTour", "WorldTour", "ProTeams"])
        XCTAssertEqual(teams[0].countryCode, "ae")
        XCTAssertEqual(teams[1].countryCode, "")
    }

    func testEmptyPagesParseToNothing() throws {
        let document = try SwiftSoup.parse("<html><body></body></html>")
        XCTAssertTrue(Service.parsePCSRaces(document).isEmpty)
        XCTAssertTrue(Service.parsePCSTeams(document).isEmpty)
    }

    // MARK: - Dates and preview

    func testRaceStartReadsIsoDayMonthAndRanges() {
        let now = day(2027, 1, 10)
        let calendar = calendar()
        XCTAssertEqual(Paddock.raceStart(from: "2027-01-20", now: now, calendar: calendar), day(2027, 1, 20))
        XCTAssertEqual(Paddock.raceStart(from: "20.01", now: now, calendar: calendar), day(2027, 1, 20))
        XCTAssertEqual(Paddock.raceStart(from: "20.01 - 25.01", now: now, calendar: calendar), day(2027, 1, 20))
        XCTAssertNil(Paddock.raceStart(from: "soon", now: now, calendar: calendar))
    }

    func testPreviewShowsTheNextThreeRacesAndFallsBackToTheFirstThree() {
        let calendar = calendar()
        func item(_ n: Int, _ date: Date?) -> Paddock.RaceItem {
            .init(path: "race/\(n)", name: "Race \(n)", dateLabel: "", raceClass: "", countryCode: "", startDate: date)
        }
        let races = [
            item(1, day(2027, 1, 1)),
            item(2, day(2027, 1, 20)),
            item(3, day(2027, 1, 21)),
            item(4, day(2027, 1, 22)),
            item(5, day(2027, 1, 23))
        ]
        XCTAssertEqual(
            Paddock.previewRaces(races, now: day(2027, 1, 10), calendar: calendar).map(\.name),
            ["Race 2", "Race 3", "Race 4"]
        )
        XCTAssertEqual(
            Paddock.previewRaces(races, now: day(2028, 1, 1), calendar: calendar).map(\.name),
            ["Race 1", "Race 2", "Race 3"]
        )
    }

    func testTeamMonogramUsesTheFirstTwoWords() {
        let team = Paddock.TeamItem(path: "team/x", name: "UAE Team Emirates - XRG", division: "", countryCode: "")
        XCTAssertEqual(team.monogram, "UT")
    }

    // MARK: - View model

    func testViewStateMapsLoadingFailedAndLoaded() {
        var domain = Paddock.Domain.empty
        var state = Paddock.ViewModel<Paddock.InteractorImpl>.mapToViewState(from: domain, now: Date())
        XCTAssertEqual(state.races, .loading)
        XCTAssertEqual(state.teams, .loading)

        domain.races = []
        domain.racesFailed = true
        domain.teams = [DTO.PCSTeam(path: "team/a", name: "A Team", division: "WorldTour", countryCode: "")]
        state = Paddock.ViewModel<Paddock.InteractorImpl>.mapToViewState(from: domain, now: Date())
        XCTAssertEqual(state.races, .failed)
        XCTAssertEqual(state.teams.items.map(\.name), ["A Team"])
    }

    func testMockScenarioServesTheDirectory() {
        XCTAssertGreaterThan(PaddockMock.races().count, Paddock.directoryPreviewLimit)
        XCTAssertGreaterThan(PaddockMock.teams().count, Paddock.directoryPreviewLimit)
    }
}
