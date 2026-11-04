//
//  PaddockDirectoryTests.swift
//  TribunerosTests
//
//  Paddock's Races | Teams section, parsed from real `races.php` / `teams.php` pages saved with
//  `URLSession` (`pcs_races.html`, `pcs_teams.html`); re-capture them when PCS changes its markup.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class PaddockDirectoryTests: XCTestCase {

    private func fixture(_ name: String) throws -> Document {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: name, withExtension: "html"))
        return try SwiftSoup.parse(String(contentsOf: url, encoding: .utf8))
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar().date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - Parsing

    func testRealRacesPageParsesTheFullList() throws {
        let races = Service.parsePCSRaces(try fixture("pcs_races"))
        XCTAssertEqual(races.count, 36)
        XCTAssertEqual(
            races[0],
            DTO.PCSRace(
                path: "race/tour-down-under-2027",
                name: "Santos Tour Down Under",
                dateText: "19.01 - 24.01",
                raceClass: "2.UWT",
                countryCode: "au"
            )
        )
        XCTAssertEqual(races[1].path, "race/great-ocean-road-race-2027")
        XCTAssertEqual(races[1].dateText, "31.01")
        XCTAssertEqual(races.last?.name, "Tour of Guangxi")
        XCTAssertTrue(races.allSatisfy { !$0.name.isEmpty && !$0.raceClass.isEmpty && !$0.countryCode.isEmpty })
        XCTAssertTrue(races.allSatisfy { $0.path.hasPrefix("race/") && !$0.path.hasSuffix("-gc") && !$0.path.hasSuffix("-result") })
        XCTAssertEqual(Set(races.map(\.path)).count, races.count)
    }

    func testRealTeamsPageParsesBothDivisionsWithoutMenuLinks() throws {
        let teams = Service.parsePCSTeams(try fixture("pcs_teams"))
        let world = teams.filter { $0.division == "UCI WorldTeams" }
        let pro = teams.filter { $0.division == "UCI ProTeams" }
        XCTAssertEqual(world.count, 18)
        XCTAssertEqual(pro.count, 14)
        XCTAssertEqual(teams.count, 32)
        XCTAssertEqual(world.first?.name, "Alpecin - Premier Tech")
        XCTAssertEqual(world.first?.path, "team/alpecin-premier-tech-2027")
        XCTAssertEqual(world.first?.countryCode, "be")
        XCTAssertEqual(pro.first?.name, "Bardiani CSF 7 Saber")
        XCTAssertEqual(pro.first?.countryCode, "it")
        XCTAssertTrue(teams.allSatisfy { $0.path.hasSuffix("-2027") && !$0.countryCode.isEmpty })
    }

    func testRealWomenRacesPageParsesTheWomensWorldTour() throws {
        let races = Service.parsePCSRaces(try fixture("pcs_races_women"))
        XCTAssertEqual(races.count, 22)
        XCTAssertEqual(
            races[0],
            DTO.PCSRace(
                path: "race/santos-women-s-tour-2027",
                name: "Santos Women's Tour Down Under",
                dateText: "22.01 - 24.01",
                raceClass: "2.WWT",
                countryCode: "au"
            )
        )
        XCTAssertEqual(races[1].path, "race/cadel-evans-great-ocean-we-2027")
        XCTAssertEqual(races[1].dateText, "30.01")
        XCTAssertEqual(races.last?.name, "Tour de France Femmes avec Zwift")
        XCTAssertTrue(races.allSatisfy { $0.raceClass.hasSuffix(".WWT") && !$0.name.isEmpty && !$0.countryCode.isEmpty })
        XCTAssertTrue(races.allSatisfy { $0.path.hasPrefix("race/") && !$0.path.hasSuffix("-gc") && !$0.path.hasSuffix("-result") })
        XCTAssertEqual(Set(races.map(\.path)).count, races.count)
    }

    func testRealTeamPageFindsItsWomensTeam() throws {
        let page = Service.parsePCSTeamPage(try fixture("pcs_team"))
        XCTAssertEqual(
            page.womensTeam,
            DTO.PCSRelatedTeam(
                path: "team/fenix-premier-tech-2027",
                name: "Fenix-Premier Tech",
                classCode: "WTW",
                relation: "women's team"
            )
        )
        XCTAssertEqual(
            page.relatedTeams.last,
            DTO.PCSRelatedTeam(
                path: "team/alpecin-premier-tech-development-team-2027",
                name: "Alpecin-Premier Tech Development Team",
                classCode: "CT",
                relation: "devo"
            )
        )
        XCTAssertEqual(page.relatedTeams.count, 2)
    }

    func testRealTeamPageWithOnlyAClubHasNoWomensTeam() throws {
        let page = Service.parsePCSTeamPage(try fixture("pcs_team_club"))
        XCTAssertEqual(page.relatedTeams.map(\.path), ["team/caja-rural-alea-2027"])
        XCTAssertEqual(page.relatedTeams.first?.classCode, "CLUB")
        XCTAssertEqual(page.relatedTeams.first?.relation, "other")
        XCTAssertNil(page.womensTeam)
    }

    func testRealTeamPageWithoutRelatedTeamsParsesToNothing() throws {
        let page = Service.parsePCSTeamPage(try fixture("pcs_team_no_related"))
        XCTAssertTrue(page.relatedTeams.isEmpty)
        XCTAssertNil(page.womensTeam)
        XCTAssertTrue(Service.parsePCSTeamPage(try SwiftSoup.parse("<html><body></body></html>")).relatedTeams.isEmpty)
    }

    func testRealFullTeamPageParsesEverySection() throws {
        let page = Service.parsePCSTeamPage(try fixture("pcs_team_2026"))
        XCTAssertEqual(page.name, "Alpecin - Premier Tech")
        XCTAssertEqual(page.classCode, "WT")
        XCTAssertEqual(page.season, 2026)
        XCTAssertEqual(
            page.kpis,
            DTO.PCSTeamKPIs(
                victories: 21,
                points: 6223,
                pcsRank: 11,
                uciRank: 11,
                incoming: 12,
                outgoing: 11
            )
        )
        XCTAssertEqual(
            page.info,
            DTO.PCSTeamInfo(
                status: "WT",
                abbreviation: "APT",
                licenseCountry: "Belgium",
                bike: "Canyon",
                jerseyURL: URL(string: "https://www.procyclingstats.com/images/shirts/bx/eb/alpecin-premier-tech-2026.png")
            )
        )
        XCTAssertEqual(page.links.map(\.kind), ["FACEBOOK", "SITE", "TWITTER", "INSTAGRAM"])
        XCTAssertEqual(page.links.first?.url, URL(string: "https://www.facebook.com/alpecinpremiertech"))
        XCTAssertEqual(page.riders.count, 30)
        XCTAssertEqual(
            page.riders.first,
            DTO.PCSTeamRider(
                path: "rider/jasper-philipsen",
                name: "PHILIPSEN Jasper",
                countryCode: "be",
                rank: 6,
                points: 1985,
                photoURL: URL(string: "https://www.procyclingstats.com/images/riders/iq/em/jasper-philipsen-2026.jpg")
            )
        )
        XCTAssertEqual(
            page.victories.first,
            DTO.PCSTeamVictory(
                racePath: "race/tour-de-luxembourg-2026-stage-5",
                raceName: "Skoda Tour de Luxembourg | Stage 5",
                raceClass: "2.Pro",
                countryCode: "lu",
                riderPath: "rider/mathieu-van-der-poel",
                riderName: "VAN DER POEL Mathieu"
            )
        )
        XCTAssertEqual(
            page.topResults.first,
            DTO.PCSTeamResult(
                position: 1,
                racePath: "race/renewi-tour-2026-gc",
                raceName: "Renewi Tour | General classification",
                raceClass: "2.UWT",
                countryCode: "be",
                riderPath: "rider/jasper-philipsen",
                riderName: "PHILIPSEN Jasper",
                points: 250
            )
        )
        XCTAssertEqual(
            page.staff.first,
            DTO.PCSTeamStaff(
                path: "staff/philip-roodhooft",
                name: "Philip Roodhooft",
                function: "General manager",
                countryCode: "be"
            )
        )
        XCTAssertEqual(page.relatedTeams.count, 3)
    }

    func testRealSparseTeamPageHasNilKPIsAndNoLists() throws {
        let page = Service.parsePCSTeamPage(try fixture("pcs_team"))
        XCTAssertEqual(page.name, "Alpecin - Premier Tech")
        XCTAssertEqual(page.classCode, "WT")
        XCTAssertEqual(page.season, 2027)
        XCTAssertEqual(page.kpis.victories, 0)
        XCTAssertNil(page.kpis.points)
        XCTAssertNil(page.kpis.pcsRank)
        XCTAssertNil(page.kpis.uciRank)
        XCTAssertEqual(page.kpis.incoming, 5)
        XCTAssertEqual(page.kpis.outgoing, 7)
        XCTAssertNil(page.info.jerseyURL)
        XCTAssertTrue(page.victories.isEmpty)
        XCTAssertTrue(page.topResults.isEmpty)
        XCTAssertTrue(page.staff.isEmpty)
    }

    func testEmptyDocumentGivesAnEmptyTeamPage() throws {
        let page = Service.parsePCSTeamPage(try SwiftSoup.parse("<html><body></body></html>"))
        XCTAssertEqual(page, DTO.PCSTeamPage(relatedTeams: []))
    }

    func testMockTeamPageFillsEverySection() {
        let page = PaddockMock.teamPage(path: "team/uae-team-emirates-xrg-2027")
        XCTAssertFalse(page.name.isEmpty)
        XCTAssertNotNil(page.season)
        XCTAssertNotNil(page.kpis.points)
        XCTAssertNotNil(page.info.jerseyURL)
        XCTAssertFalse(page.links.isEmpty)
        XCTAssertFalse(page.riders.isEmpty)
        XCTAssertFalse(page.victories.isEmpty)
        XCTAssertFalse(page.topResults.isEmpty)
        XCTAssertFalse(page.staff.isEmpty)
        XCTAssertFalse(page.relatedTeams.isEmpty)
    }

    func testMockTeamPageHasAWomensTeam() {
        let page = PaddockMock.teamPage(path: "team/uae-team-emirates-xrg-2027")
        XCTAssertEqual(page.womensTeam?.classCode, "WTW")
        XCTAssertEqual(page.relatedTeams.count, 2)
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
        XCTAssertEqual(
            Paddock.raceStart(from: "19.01 - 24.01", now: day(2026, 11, 3), calendar: calendar, year: 2027),
            day(2027, 1, 19)
        )
        XCTAssertEqual(Paddock.pathYear("race/tour-down-under-2027"), 2027)
        XCTAssertNil(Paddock.pathYear("race/gp-quebec"))
        XCTAssertEqual(Paddock.pathYear("race/tour-de-france-femmes-20271"), 2027)
        XCTAssertEqual(Paddock.pathYear("race/tour-de-france-femmes-20272"), 2027)
        XCTAssertNil(Paddock.raceStart(from: "soon", now: now, calendar: calendar))
    }

    func testRealRacesPreviewIsTheNextSeasonsFirstThreeInNovember() throws {
        let items = Service.parsePCSRaces(try fixture("pcs_races")).map {
            Paddock.raceItem(from: $0, now: day(2026, 11, 3), calendar: calendar())
        }
        XCTAssertTrue(items.allSatisfy { $0.startDate != nil })
        XCTAssertEqual(
            Paddock.previewRaces(items, now: day(2026, 11, 3), calendar: calendar()).map(\.name),
            ["Santos Tour Down Under", "Mapei Cadel Evans Great Ocean Road Race ME", "UAE Tour"]
        )
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

    // MARK: - Races list (end date, season, Men | Women)

    func testRaceEndReadsTheSecondDateOfARange() {
        let now = day(2026, 11, 3)
        let calendar = calendar()
        XCTAssertEqual(Paddock.raceEnd(from: "19.01 - 24.01", now: now, calendar: calendar, year: 2027), day(2027, 1, 24))
        XCTAssertNil(Paddock.raceEnd(from: "31.01", now: now, calendar: calendar, year: 2027))
        XCTAssertNil(Paddock.raceEnd(from: "2027-01-20", now: now, calendar: calendar))
        XCTAssertNil(Paddock.raceEnd(from: "soon - later", now: now, calendar: calendar))
        // A range over New Year ends in the following year.
        XCTAssertEqual(Paddock.raceEnd(from: "28.12 - 03.01", now: now, calendar: calendar, year: 2027), day(2028, 1, 3))
    }

    func testRaceItemCarriesEndDateAndSeason() {
        let calendar = calendar()
        let stage = Paddock.raceItem(
            from: DTO.PCSRace(path: "race/tour-down-under-2027", name: "TDU", dateText: "19.01 - 24.01", raceClass: "2.UWT", countryCode: "au"),
            now: day(2026, 11, 3),
            calendar: calendar
        )
        XCTAssertEqual(stage.startDate, day(2027, 1, 19))
        XCTAssertEqual(stage.endDate, day(2027, 1, 24))
        XCTAssertNotNil(stage.endLabel)
        XCTAssertEqual(stage.season, 2027)

        let oneDay = Paddock.raceItem(
            from: DTO.PCSRace(path: "race/gp-quebec", name: "GP", dateText: "2027-09-10", raceClass: "1.UWT", countryCode: "ca"),
            now: day(2026, 11, 3),
            calendar: calendar
        )
        XCTAssertNil(oneDay.endDate)
        XCTAssertNil(oneDay.endLabel)
        XCTAssertEqual(oneDay.season, 2027, "no year in the path: the start date's year")
    }

    func testRealRacesPagesGiveEndDatesOnlyToStageRaces() throws {
        let calendar = calendar()
        for name in ["pcs_races", "pcs_races_women"] {
            let items = Service.parsePCSRaces(try fixture(name)).map {
                Paddock.raceItem(from: $0, now: day(2026, 11, 3), calendar: calendar)
            }
            XCTAssertTrue(items.allSatisfy { $0.season == 2027 }, name)
            XCTAssertTrue(items.allSatisfy { $0.endDate == nil || $0.endDate! >= $0.startDate! }, name)
            XCTAssertTrue(items.contains { $0.endDate != nil }, name)
            XCTAssertTrue(items.contains { $0.endDate == nil }, name)
        }
    }

    @MainActor
    func testRacesListLoadsWomenOnlyWhenSelectedAndOnlyOnce() async {
        var calls = 0
        let model = Paddock.RacesListModel(fetchWomen: {
            calls += 1
            return PaddockMock.womenRaces()
        })
        XCTAssertEqual(model.circuit, .men)
        XCTAssertEqual(model.women, .loading)
        XCTAssertEqual(calls, 0)

        model.select(.women)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.circuit, .women)
        XCTAssertEqual(model.women.items.count, PaddockMock.womenRaces().count)
        XCTAssertEqual(calls, 1)

        model.select(.men)
        model.select(.women)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(calls, 1)
    }

    @MainActor
    func testRacesListWomenFailureCanBeRetried() async {
        var results: [[DTO.PCSRace]?] = [nil, PaddockMock.womenRaces()]
        let model = Paddock.RacesListModel(fetchWomen: { results.removeFirst() })
        model.select(.women)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.women, .failed)

        model.loadWomen()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.women.items.count, PaddockMock.womenRaces().count)
    }

    func testTeamRidersFromTheRealPageKeepAllRidersRankedFirst() throws {
        let page = Service.parsePCSTeamPage(try fixture("pcs_team_2026"))
        let riders = Paddock.teamRiders(from: page)
        XCTAssertEqual(riders.count, page.riders.count)
        XCTAssertEqual(Set(riders.map(\.path)), Set(page.riders.map(\.path)))
        let ranks = riders.compactMap(\.rank)
        XCTAssertEqual(ranks, ranks.sorted())
        // Riders without a rank come after every ranked one.
        let firstUnranked = riders.firstIndex { $0.rank == nil } ?? riders.count
        XCTAssertTrue(riders[firstUnranked...].allSatisfy { $0.rank == nil })
        XCTAssertEqual(riders.first?.name, "PHILIPSEN Jasper")
    }

    func testTeamRidersOfAnEmptyPageIsEmpty() {
        XCTAssertTrue(Paddock.teamRiders(from: DTO.PCSTeamPage(relatedTeams: [])).isEmpty)
    }

    @MainActor
    func testTeamDetailModelLoadsTheRosterOnce() async {
        var paths: [String] = []
        let team = Paddock.TeamItem(path: "team/mock-2027", name: "Mock", division: "", countryCode: "")
        let model = Paddock.TeamDetailModel(team: team, fetch: {
            paths.append($0)
            return PaddockMock.teamPage(path: $0)
        })
        XCTAssertEqual(model.riders, .loading)

        model.load()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.riders.items.map(\.name), ["LEADER Mock", "SPRINTER Mock"])
        model.load()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(paths, ["team/mock-2027", "team/mock-2026"])
    }

    @MainActor
    func testTeamDetailModelFailureCanBeRetried() async {
        var results: [DTO.PCSTeamPage?] = [nil, PaddockMock.teamPage(path: "team/mock-2027")]
        let team = Paddock.TeamItem(path: "team/mock-2027", name: "Mock", division: "", countryCode: "")
        let model = Paddock.TeamDetailModel(team: team, fetch: { _ in results.removeFirst() })
        model.load()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(model.riders, .failed)

        model.load()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(model.riders.items.isEmpty)
    }

    func testPreviousSeasonPath() {
        XCTAssertEqual(Paddock.previousSeasonPath("team/lidl-trek-2027"), "team/lidl-trek-2026")
        XCTAssertNil(Paddock.previousSeasonPath("team/lidl-trek"))
    }

    func testSparseTeamPageGetsItsPhotosFromThePreviousSeason() throws {
        let current = Service.parsePCSTeamPage(try fixture("pcs_team"))
        let previous = Service.parsePCSTeamPage(try fixture("pcs_team_2026"))
        let riders = Paddock.teamRiders(from: current)
        XCTAssertTrue(riders.allSatisfy { $0.photoURL == nil })

        let filled = Paddock.fillingPhotos(riders, from: previous)
        XCTAssertEqual(
            filled.first { $0.path == "rider/jasper-philipsen" }?.photoURL,
            URL(string: "https://www.procyclingstats.com/images/riders/iq/em/jasper-philipsen-2026.jpg")
        )
        XCTAssertEqual(filled.map(\.path), riders.map(\.path))
        XCTAssertEqual(Paddock.fillingPhotos(riders, from: nil), riders)
    }

    @MainActor
    func testTeamDetailModelAsksThePreviousSeasonOnlyForMissingPhotos() async {
        var paths: [String] = []
        let team = Paddock.TeamItem(path: "team/mock-2027", name: "Mock", division: "", countryCode: "")
        let model = Paddock.TeamDetailModel(team: team, fetch: {
            paths.append($0)
            return PaddockMock.teamPage(path: $0)
        })
        model.load()
        try? await Task.sleep(nanoseconds: 100_000_000)
        // The mock's sprinter has no photo, so the 2026 page is asked too.
        XCTAssertEqual(paths, ["team/mock-2027", "team/mock-2026"])
    }

    func testTeamRiderOpensTheRiderScreenOnItsPCSPage() {
        let item = Paddock.TeamRiderItem(
            path: "rider/jasper-philipsen",
            name: "PHILIPSEN Jasper",
            countryCode: "be",
            rank: 6,
            points: 1985,
            photoURL: nil
        )
        let context = Paddock.RiderContext.teamRider(item.asRider)
        XCTAssertEqual(context.rider.name, "PHILIPSEN Jasper")
        XCTAssertEqual(context.rider.url, URL(string: "https://www.procyclingstats.com/rider/jasper-philipsen"))

        let router = Router()
        router.routeTo(.paddockRider(context))
        XCTAssertEqual(router.lastPushed, .paddockRider(context))
    }

    func testTappingATeamPushesItsScreen() {
        let team = Paddock.TeamItem(path: "team/mock-2027", name: "Mock", division: "", countryCode: "")
        let router = Router()
        router.routeTo(.paddockTeam(team))
        XCTAssertEqual(router.lastPushed, .paddockTeam(team))
        XCTAssertEqual(router.navPath.count, 1)
    }

    func testTeamGroupsSplitByDivisionKeepingOrder() throws {
        let items = Service.parsePCSTeams(try fixture("pcs_teams")).map(Paddock.teamItem(from:))
        let groups = Paddock.teamGroups(items)
        XCTAssertEqual(groups.map(\.division), ["UCI WorldTeams", "UCI ProTeams"])
        XCTAssertEqual(groups.map(\.teams.count), [18, 14])
        XCTAssertEqual(groups.first?.teams.first?.name, "Alpecin - Premier Tech")
        XCTAssertEqual(groups.flatMap(\.teams), items)
    }

    func testTeamGroupsKeepUnheadedTeamsInTheirOwnGroup() {
        let item = Paddock.TeamItem(path: "team/x-2026", name: "X", division: "", countryCode: "")
        XCTAssertEqual(Paddock.teamGroups([item]), [Paddock.TeamGroup(division: "", teams: [item])])
        XCTAssertTrue(Paddock.teamGroups([]).isEmpty)
    }

    func testTeamsSeasonIsTheMostCommonPathYear() throws {
        let items = Service.parsePCSTeams(try fixture("pcs_teams")).map(Paddock.teamItem(from:))
        XCTAssertEqual(Paddock.teamsSeason(items), Paddock.pathYear(items[0].path))
        XCTAssertNotNil(Paddock.teamsSeason(items))
        let mixed = ["team/a-2026", "team/b-2027", "team/c-2027", "team/d"].map {
            Paddock.TeamItem(path: $0, name: "T", division: "", countryCode: "")
        }
        XCTAssertEqual(Paddock.teamsSeason(mixed), 2027)
        XCTAssertNil(Paddock.teamsSeason([]))
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
        domain.teams = [DTO.PCSTeam(path: "team/a", name: "A Team", division: "UCI WorldTeams", countryCode: "")]
        state = Paddock.ViewModel<Paddock.InteractorImpl>.mapToViewState(from: domain, now: Date())
        XCTAssertEqual(state.races, .failed)
        XCTAssertEqual(state.teams.items.map(\.name), ["A Team"])
    }

    func testMockScenarioServesTheDirectory() {
        XCTAssertGreaterThan(PaddockMock.races().count, Paddock.directoryPreviewLimit)
        XCTAssertGreaterThan(PaddockMock.teams().count, Paddock.directoryPreviewLimit)
    }

    func testMockScenarioServesWomensWorldTourRaces() {
        let races = PaddockMock.womenRaces()
        XCTAssertGreaterThan(races.count, Paddock.directoryPreviewLimit)
        XCTAssertTrue(races.allSatisfy { $0.raceClass.hasSuffix(".WWT") })
        XCTAssertEqual(Set(races.map(\.path)).count, races.count)
    }
}
