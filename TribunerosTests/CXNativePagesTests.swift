//
//  CXNativePagesTests.swift
//  TribunerosTests
//
//  The CX pages that replaced the cyclocross24 web views: full results, a rider's results and a
//  ranking (view-model mapping and routes), plus the system hand-off of third-party links.
//

import XCTest
@testable import Tribuneros

final class CXNativePagesTests: XCTestCase {

    // MARK: - Fixtures -

    private func url(_ path: String) -> URL {
        URL(string: "https://cyclocross24.com/\(path)")!
    }

    private func event(winner: String = "") -> DTO.CXCalendarEvent {
        .init(
            date: "04-01-2026",
            race: "X2O Badkamers Trofee - Middelkerke",
            raceClass: "C1",
            flagURL: nil,
            winnerName: winner,
            isCancelled: false,
            raceID: 18001,
            raceSlug: "middelkerke",
            raceURL: url("race/middelkerke/"),
            resultsURL: url("race/18001/"),
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "Belgium",
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )
    }

    private func results(_ count: Int) -> [DTO.CX24Homepage.CategoryResult] {
        (0..<count).map { index in
            .init(
                position: "\(index + 1)",
                rider: "Rider \(index + 1)",
                age: "25",
                team: index == 1 ? "" : "Team \(index + 1)",
                time: index == 0 ? "58:12" : "+0:\(10 + index)",
                countryFlagURL: nil,
                raceVideosURL: nil,
                riderURL: url("rider/rider-\(index + 1)/")
            )
        }
    }

    private let rider = CXRaces.RiderRef(
        name: "VAN AERT Wout",
        riderURL: URL(string: "https://cyclocross24.com/rider/wout-van-aert/"),
        flagURL: nil,
        country: "Belgium"
    )

    private func riderPage(_ results: [DTO.CXRiderPage.Result]) -> DTO.CXRiderPage {
        .init(
            name: "Wout van Aert",
            avatarURL: nil,
            facts: [],
            results: results
        )
    }

    private func result(
        _ date: String,
        _ race: String,
        position: String = "3",
        raceURL: URL? = URL(string: "https://cyclocross24.com/race/1/")
    ) -> DTO.CXRiderPage.Result {
        .init(
            date: date,
            race: race,
            position: position,
            raceURL: raceURL
        )
    }

    private func standingPage(
        selectedIndex: Int = 0,
        rows: Int = 3,
        team: String? = nil
    ) -> DTO.CXStandingPage {
        .init(
            title: "UCI Ranking Men",
            categories: [
                .init(title: "Men Elite", url: url("uciranking/2026-2027/ME/")),
                .init(title: "Women Elite", url: url("uciranking/2026-2027/WE/")),
                .init(title: "Men Junior", url: url("uciranking/2026-2027/MJ/"))
            ],
            selectedIndex: selectedIndex,
            rows: (0..<rows).map { index in
                .init(
                    position: index + 1,
                    rider: "Rider \(index + 1)",
                    riderURL: url("rider/rider-\(index + 1)/"),
                    countryFlagURL: nil,
                    team: team,
                    points: "\(3000 - index * 100)"
                )
            }
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping () -> Bool
    ) {
        let predicate = NSPredicate { _, _ in condition() }
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: nil
        )
        wait(for: [expectation], timeout: timeout)
    }

    // MARK: - Full results -

    func testFullResultsMapsEveryRowInOrder() {
        let domain = CXRaces.FullResults.Domain(
            event: event(),
            load: .loaded(results(25))
        )
        let state = CXRaces.FullResults.ViewModel<CXRaces.FullResults.InteractorImpl>.mapToViewState(domain)
        XCTAssertEqual(state.title, "X2O Badkamers Trofee - Middelkerke")
        guard case .loaded(let rows) = state.body else {
            return XCTFail("expected rows, got \(state.body)")
        }
        XCTAssertEqual(rows.count, 25)
        XCTAssertEqual(rows.map(\.position), (1...25).map { "\($0)" })
        XCTAssertTrue(rows[0].isWinner)
        XCTAssertFalse(rows[1].isWinner)
        XCTAssertEqual(rows[1].team, "")
    }

    func testFullResultsLoadingAndFailedStates() {
        let mapper = CXRaces.FullResults.ViewModel<CXRaces.FullResults.InteractorImpl>.mapToViewState
        XCTAssertEqual(mapper(.init(event: event(), load: .loading)).body, .loading)
        guard case .unavailable = mapper(.init(event: event(), load: .failed)).body else {
            return XCTFail("a failed load is unavailable")
        }
    }

    func testFullResultsWinnerRowOpensWinnerScreenOthersTheRider() {
        let event = event()
        let all = results(12)
        let domain = CXRaces.FullResults.Domain(
            event: event,
            load: .loaded(all)
        )
        typealias VM = CXRaces.FullResults.ViewModel<CXRaces.FullResults.InteractorImpl>
        XCTAssertEqual(
            VM.destination(forRow: 0, domain: domain),
            .cxZone(.winnerDetail(.init(event: event, result: all[0]), from: event))
        )
        XCTAssertEqual(
            VM.destination(forRow: 11, domain: domain),
            .cxZone(.riderDetail(.result(.init(result: all[11], event: event))))
        )
        XCTAssertNil(VM.destination(forRow: 12, domain: domain))
    }

    func testFullResultsInteractorStartsLoadedWhenGivenRows() {
        let interactor = CXRaces.FullResults.InteractorImpl(
            event: event(),
            results: results(3)
        ) { _ in
            XCTFail("rows were given, nothing to fetch")
            return []
        }
        interactor.useCase(.load)
        XCTAssertEqual(interactor.domain.load, .loaded(results(3)))
    }

    // MARK: - Rider results -

    func testRiderResultsAreGroupedBySeasonNewestFirst() {
        let page = [
            result("12-10-2025", "Oct 2025"),
            result("01-02-2026", "Feb 2026"),
            result("23-11-2024", "Nov 2024"),
            result("4.1.2026", "Jan 2026"),
            result("not a date", "Undated"),
            result("08-02-2025", "Feb 2025")
        ]
        let seasons = CXRaces.RiderResults.seasons(page)
        XCTAssertEqual(seasons.map(\.title), ["2025–26", "2024–25", "Others"])
        XCTAssertEqual(seasons[0].rows.map(\.race), ["Feb 2026", "Jan 2026", "Oct 2025"])
        XCTAssertEqual(seasons[1].rows.map(\.race), ["Feb 2025", "Nov 2024"])
        XCTAssertEqual(seasons[2].rows.map(\.race), ["Undated"])
        // Row ids point back at the page's own order.
        XCTAssertEqual(seasons[0].rows.map(\.id), [1, 3, 0])
    }

    func testRiderResultsSameDayKeepsPageOrder() {
        let seasons = CXRaces.RiderResults.seasons([
            result("01-02-2026", "First"),
            result("01-02-2026", "Second")
        ])
        XCTAssertEqual(seasons.first?.rows.map(\.race), ["First", "Second"])
    }

    func testSeasonStartsInJuly() {
        let calendar = Service.cxCalendar
        let june = calendar.date(from: DateComponents(year: 2026, month: 6, day: 30))!
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        XCTAssertEqual(CXRaces.RiderResults.seasonTitle(for: june), "2025–26")
        XCTAssertEqual(CXRaces.RiderResults.seasonTitle(for: july), "2026–27")
    }

    func testRiderResultsMapsAllRowsAnOldDocumentHolds() {
        typealias VM = CXRaces.RiderResults.ViewModel<CXRaces.RiderResults.InteractorImpl>
        let ten = (1...10).map { result(String(format: "%02d-01-2026", $0), "Race \($0)") }
        let state = VM.mapToViewState(.init(rider: rider, load: .loaded(riderPage(ten))))
        XCTAssertEqual(state.title, "Wout van Aert")
        guard case .loaded(let seasons) = state.body else {
            return XCTFail("expected seasons, got \(state.body)")
        }
        XCTAssertEqual(seasons.flatMap(\.rows).count, 10)
        XCTAssertEqual(VM.mapToViewState(.init(rider: rider, load: .loading)).body, .loading)
        XCTAssertEqual(VM.mapToViewState(.init(rider: rider, load: .loading)).title, "VAN AERT Wout")
        guard case .unavailable = VM.mapToViewState(.init(rider: rider, load: .loaded(riderPage([])))).body else {
            return XCTFail("a page without results is an empty state")
        }
    }

    func testRiderResultsRowsOpenRacesLikeRecentResults() {
        typealias VM = CXRaces.RiderResults.ViewModel<CXRaces.RiderResults.InteractorImpl>
        let rows = [
            result("01-02-2026", "Win", position: "1", raceURL: url("race/18001/")),
            result("25-01-2026", "Third", position: "3", raceURL: url("race/18002/")),
            result("18-01-2026", "No link", raceURL: nil)
        ]
        let domain = CXRaces.RiderResults.Domain(
            rider: rider,
            load: .loaded(riderPage(rows))
        )
        XCTAssertEqual(
            VM.destination(forResult: 0, domain: domain, calendar: []),
            CXRaces.destination(forRiderResult: rows[0], rider: rider, calendar: [])
        )
        guard case .cxZone(.winnerDetail) = VM.destination(forResult: 0, domain: domain, calendar: []) else {
            return XCTFail("a win opens the winner screen")
        }
        guard case .cxZone(.eventDetail) = VM.destination(forResult: 1, domain: domain, calendar: []) else {
            return XCTFail("any other place opens the race")
        }
        XCTAssertNil(VM.destination(forResult: 2, domain: domain, calendar: []))
    }

    // MARK: - Ranking -

    func testRankingMapsChipsAndRowsOfTheSelectedCategory() {
        typealias VM = CXRaces.Ranking.ViewModel<CXRaces.Ranking.InteractorImpl>
        let page = standingPage(selectedIndex: 1, rows: 30)
        var domain = CXRaces.Ranking.Domain(
            context: .init(title: "UCI Ranking", category: nil, url: url("uciranking/"), logoURL: nil),
            url: url("uciranking/2026-2027/WE/")
        )
        domain.load = .loaded(page)
        domain.categories = page.categories
        domain.selectedIndex = 1
        let state = VM.mapToViewState(domain)
        XCTAssertEqual(state.title, "UCI Ranking Men")
        XCTAssertEqual(state.chips?.map(\.title), ["Men Elite", "Women Elite", "Men Junior"])
        XCTAssertEqual(state.chips?.map(\.isSelected), [false, true, false])
        guard case .loaded(let rows) = state.body else {
            return XCTFail("expected rows, got \(state.body)")
        }
        XCTAssertEqual(rows.count, 30)
        XCTAssertEqual(rows.first?.position, "1")
        XCTAssertNil(rows.first?.team, "a null team hides the line")
    }

    func testRankingWhileLoadingKeepsTheKnownTitleAndNoChips() {
        typealias VM = CXRaces.Ranking.ViewModel<CXRaces.Ranking.InteractorImpl>
        let state = VM.mapToViewState(
            .init(
                context: .init(title: "Superprestige", category: "Men Elite", url: url("standings/superprestige/"), logoURL: nil),
                url: url("standings/superprestige/"),
                load: .loading
            )
        )
        XCTAssertEqual(state.title, "Superprestige")
        XCTAssertNil(state.chips)
        XCTAssertEqual(state.body, .loading)
    }

    func testRankingWithoutAPageIsUnavailableNotLoading() {
        typealias VM = CXRaces.Ranking.ViewModel<CXRaces.Ranking.InteractorImpl>
        let state = VM.mapToViewState(
            .init(
                context: .init(title: "Superprestige", category: nil, url: url("standings/superprestige/"), logoURL: nil),
                url: url("standings/superprestige/"),
                load: .failed
            )
        )
        guard case .unavailable = state.body else {
            return XCTFail("a missing page shows a message, got \(state.body)")
        }
    }

    func testRankingRowOpensRiderWithStanding() {
        typealias VM = CXRaces.Ranking.ViewModel<CXRaces.Ranking.InteractorImpl>
        let page = standingPage(selectedIndex: 2)
        let pageURL = url("uciranking/2026-2027/MJ/")
        let domain = CXRaces.Ranking.Domain(
            context: .init(title: "UCI Ranking", category: nil, url: pageURL, logoURL: nil),
            url: pageURL,
            load: .loaded(page)
        )
        guard case .cxZone(.riderDetail(.standing(let standing))) = VM.destination(forRow: 1, domain: domain) else {
            return XCTFail("a row opens the rider screen with its standing")
        }
        XCTAssertEqual(standing.rider, "Rider 2")
        XCTAssertEqual(standing.position, 2)
        XCTAssertEqual(standing.points, "2900")
        XCTAssertEqual(standing.rankingTitle, "UCI Ranking Men")
        XCTAssertEqual(standing.category, "Men Junior")
        XCTAssertEqual(standing.standingsURL, pageURL)
        XCTAssertNil(VM.destination(forRow: 3, domain: domain))
    }

    func testRankingChipLoadsThatCategory() {
        var requested: [URL] = []
        let interactor = CXRaces.Ranking.InteractorImpl(
            context: .init(title: "UCI Ranking", category: nil, url: url("uciranking/"), logoURL: nil)
        ) { [self] requestedURL in
            requested.append(requestedURL)
            let index = ["ME", "WE", "MJ"].firstIndex { requestedURL.path.contains($0) } ?? 0
            return standingPage(selectedIndex: index)
        }
        interactor.useCase(.load)
        waitUntil { interactor.domain.load.value != nil }
        XCTAssertEqual(interactor.domain.selectedIndex, 0)

        interactor.useCase(.selectCategory(1))
        XCTAssertEqual(interactor.domain.selectedIndex, 1)
        waitUntil { interactor.domain.load.value?.selectedIndex == 1 }
        XCTAssertEqual(interactor.domain.url, url("uciranking/2026-2027/WE/"))
        XCTAssertEqual(requested, [url("uciranking/"), url("uciranking/2026-2027/WE/")])

        // Back to a page already loaded: no new request.
        interactor.useCase(.selectCategory(0))
        waitUntil { interactor.domain.load.value?.selectedIndex == 0 }
        XCTAssertEqual(requested.count, 3, "the default page and the ME tab are different links")
        interactor.useCase(.selectCategory(1))
        XCTAssertEqual(requested.count, 3, "WE was loaded already")
    }

    func testRankingOpensOnTheRidersCategory() {
        let interactor = CXRaces.Ranking.InteractorImpl(
            context: .init(title: "UCI Ranking", category: "Men Junior", url: url("uciranking/"), logoURL: nil)
        ) { [self] requestedURL in
            standingPage(selectedIndex: requestedURL.path.contains("MJ") ? 2 : 0)
        }
        interactor.useCase(.load)
        waitUntil { interactor.domain.load.value?.selectedIndex == 2 }
        XCTAssertEqual(interactor.domain.url, url("uciranking/2026-2027/MJ/"))
    }

    func testRankingContextFromStandingAndItem() {
        let item = DTO.CXStandings.Item(
            title: "Superprestige",
            url: url("standings/superprestige/"),
            logoURL: nil,
            categories: [
                .init(
                    title: "Women Elite",
                    url: url("standings/superprestige/2025-2026/WE/"),
                    leaders: [
                        .init(position: 1, rider: "Rider", riderURL: nil, countryFlagURL: nil, points: "56")
                    ],
                    leaderImageURL: nil
                )
            ]
        )
        let fromItem = CXRaces.RankingContext(item: item)
        XCTAssertEqual(fromItem.url, url("standings/superprestige/"))
        XCTAssertNil(fromItem.category)

        let standing = CXRaces.RiderStanding(
            leader: item.categories[0].leaders[0],
            category: item.categories[0],
            item: item
        )
        let fromStanding = CXRaces.RankingContext(standing: standing)
        XCTAssertEqual(fromStanding.url, url("standings/superprestige/2025-2026/WE/"))
        XCTAssertEqual(fromStanding.category, "Women Elite")
        XCTAssertEqual(fromStanding.title, "Superprestige")
    }

    // MARK: - Routes -

    func testNewCXActionsPushTheirScreens() {
        let router = Router()
        let viewModel = CXRaces.ViewModel(
            router: router,
            interactor: CXRaces.InteractorImpl()
        )
        viewModel.action(.didTapOnFullResults(event(), results: results(3)))
        viewModel.action(.didTapOnAllRiderResults(rider))
        viewModel.action(
            .didTapOnRanking(
                .init(title: "UCI Ranking", category: nil, url: url("uciranking/"), logoURL: nil)
            )
        )
        XCTAssertEqual(router.navPath.count, 3)
        XCTAssertNil(router.webPage)
    }

    func testExternalLinksLeaveTheAppInsteadOfAWebSheet() throws {
        let router = Router()
        var opened: [URL] = []
        router.openExternally = { opened.append($0) }
        let viewModel = CXRaces.ViewModel(
            router: router,
            interactor: CXRaces.InteractorImpl()
        )
        let link = try XCTUnwrap(URL(string: "https://www.youtube.com/watch?v=abc"))
        viewModel.action(.didTapOnExternalLink(link))
        XCTAssertEqual(opened, [link])
        XCTAssertNil(router.webPage)
        XCTAssertEqual(router.navPath.count, 0)
    }
}
