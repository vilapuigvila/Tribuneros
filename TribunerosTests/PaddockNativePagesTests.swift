//
//  PaddockNativePagesTests.swift
//  TribunerosTests
//
//  The Paddock tab without web views: routes, the press screen, the rider screen's sections and
//  the season results screen.
//

import XCTest
@testable import Tribuneros

@MainActor
final class PaddockNativePagesTests: XCTestCase {

    // MARK: - Routes

    private func paddockViewModel(router: Router) -> Paddock.ViewModel<Paddock.InteractorImpl> {
        Paddock.ViewModel(
            router: router,
            interactor: Paddock.InteractorImpl()
        )
    }

    private let rider = Paddock.Rider(
        name: "Rider",
        countryCode: "fr",
        url: URL(string: "https://www.procyclingstats.com/rider/rider")
    )

    private let press = Paddock.PressItem(
        url: URL(string: "https://www.escapecollective.com")!,
        name: "Escape Collective",
        domain: "escapecollective.com"
    )

    func testBirthdayRowOpensTheRiderScreenNotAWebPage() {
        let router = Router()
        let viewModel = paddockViewModel(router: router)

        viewModel.action(.didTapOnRider(.birthday(.init(rider: rider, age: "28"))))

        XCTAssertEqual(router.navPath.count, 1)
        XCTAssertNil(router.webPage)
    }

    func testBirthdayContextCarriesTheRider() {
        let context = Paddock.RiderContext.birthday(.init(rider: rider, age: "28"))
        XCTAssertEqual(context.rider, rider)
    }

    func testPressCircleOpensThePressScreenNotAWebPage() {
        let router = Router()
        var opened: [URL] = []
        router.openExternally = { opened.append($0) }
        let viewModel = paddockViewModel(router: router)

        viewModel.action(.didTapOnPress(press))

        XCTAssertEqual(router.navPath.count, 1)
        XCTAssertNil(router.webPage)
        XCTAssertTrue(opened.isEmpty)
    }

    func testSeasonResultsLinkPushesTheScreen() {
        let router = Router()
        let viewModel = paddockViewModel(router: router)

        viewModel.action(.didTapOnSeasonResults(.init(riderName: "Rider", rows: [])))

        XCTAssertEqual(router.navPath.count, 1)
        XCTAssertNil(router.webPage)
    }

    // MARK: - Press screen

    private func pressViewModel(
        router: Router,
        feed: DTO.PressFeed?
    ) -> Paddock.PressPage.ViewModel<Paddock.PressPage.InteractorImpl> {
        Paddock.PressPage.ViewModel(
            router: router,
            interactor: Paddock.PressPage.InteractorImpl(
                item: press,
                loadFeed: { _ in feed }
            )
        )
    }

    private func article(
        _ name: String,
        date: Date?,
        summary: String? = nil
    ) -> DTO.PressFeed.Article {
        .init(
            title: name,
            url: URL(string: "https://www.escapecollective.com/\(name)")!,
            date: date,
            imageURL: nil,
            summary: summary
        )
    }

    private func settle(
        _ viewModel: Paddock.PressPage.ViewModel<Paddock.PressPage.InteractorImpl>,
        until done: (Paddock.PressPage.ViewState) -> Bool
    ) async {
        viewModel.action(.onAppear)
        for _ in 0..<100 where !done(viewModel.stateView) {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func testPressHeaderShowsMonogramNameAndDomain() {
        let state = Paddock.PressPage.ViewModel<Paddock.PressPage.InteractorImpl>.mapToViewState(
            .init(item: press),
            now: Date()
        )
        XCTAssertEqual(state.monogram, "EC")
        XCTAssertEqual(state.name, "Escape Collective")
        XCTAssertEqual(state.domain, "escapecollective.com")
        XCTAssertEqual(state.body, .loading)
    }

    func testPressRowsAreNewestFirstWithRelativeDates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rows = Paddock.PressPage.ViewModel<Paddock.PressPage.InteractorImpl>.rows(
            from: [
                article("old", date: now.addingTimeInterval(-3 * 86_400)),
                article("undated", date: nil),
                article("new", date: now.addingTimeInterval(-2 * 3_600), summary: "Short")
            ],
            now: now
        )

        XCTAssertEqual(rows.map(\.title), ["new", "old", "undated"])
        XCTAssertEqual(rows[0].summary, "Short")
        XCTAssertEqual(
            rows[0].date,
            L10n.relativeFormatter().localizedString(for: now.addingTimeInterval(-2 * 3_600), relativeTo: now)
        )
        XCTAssertEqual(rows[2].date, "")
    }

    func testPressLoadedFeedMapsToRows() async {
        let now = Date()
        let viewModel = pressViewModel(
            router: Router(),
            feed: .init(articles: [article("a", date: now)])
        )

        await settle(viewModel) { if case .loaded = $0.body { true } else { false } }

        guard case .loaded(let rows) = viewModel.stateView.body else {
            return XCTFail("Expected headlines, got \(viewModel.stateView.body)")
        }
        XCTAssertEqual(rows.map(\.title), ["a"])
    }

    func testPressFailedFeedIsUnavailable() async {
        let viewModel = pressViewModel(
            router: Router(),
            feed: nil
        )

        await settle(viewModel) { if case .unavailable = $0.body { true } else { false } }

        guard case .unavailable = viewModel.stateView.body else {
            return XCTFail("Expected the empty state, got \(viewModel.stateView.body)")
        }
    }

    func testPressEmptyFeedIsUnavailable() {
        let state = Paddock.PressPage.ViewModel<Paddock.PressPage.InteractorImpl>.mapToViewState(
            .init(
                item: press,
                load: .loaded(.init(articles: []))
            ),
            now: Date()
        )
        guard case .unavailable = state.body else {
            return XCTFail("Expected the empty state, got \(state.body)")
        }
    }

    func testHeadlineOpensInTheInAppReader() {
        let router = Router()
        var opened: [URL] = []
        router.openExternally = { opened.append($0) }
        let viewModel = pressViewModel(
            router: router,
            feed: nil
        )
        let url = URL(string: "https://www.escapecollective.com/story")!

        viewModel.action(.openArticle(url))

        XCTAssertEqual(router.webPage?.url, url)
        XCTAssertEqual(router.webPage?.prefersReader, true)
        XCTAssertTrue(opened.isEmpty)
        XCTAssertEqual(router.navPath.count, 0)
    }

    func testOpenSiteOpensTheSiteInTheInAppReader() {
        let router = Router()
        var opened: [URL] = []
        router.openExternally = { opened.append($0) }
        let viewModel = pressViewModel(
            router: router,
            feed: nil
        )

        viewModel.action(.openSite)

        XCTAssertEqual(router.webPage?.url, press.url)
        XCTAssertTrue(opened.isEmpty)
    }

    func testWebOnlyPressCircleOpensTheSiteDirectly() {
        let router = Router()
        let viewModel = paddockViewModel(router: router)
        let ciclismo = Paddock.PressItem(
            url: URL(string: "https://www.ciclismo2005.com")!,
            name: "Ciclismo 2005",
            domain: "ciclismo2005.com"
        )

        viewModel.action(.didTapOnPress(ciclismo))

        XCTAssertEqual(router.webPage?.url, ciclismo.url)
        XCTAssertEqual(router.webPage?.prefersReader, true)
        XCTAssertEqual(router.navPath.count, 0)
        XCTAssertTrue(ciclismo.opensInWebView)
        XCTAssertFalse(press.opensInWebView)
    }

    // MARK: - Rider sections

    private var page: DTO.PCSRiderPage {
        let results = (0..<14).map { index in
            DTO.PCSRiderPage.SeasonResult(
                date: "0\(index % 9 + 1).03",
                result: "\(index + 1)",
                race: "Race \(index)",
                raceClass: "(2.UWT)",
                distance: "180 km",
                pcsPoints: "50",
                isStage: false
            )
        }
        let stage = DTO.PCSRiderPage.SeasonResult(
            date: "10.03",
            result: "1",
            race: "Stage 1",
            raceClass: nil,
            distance: nil,
            pcsPoints: nil,
            isStage: true
        )
        return DTO.PCSRiderPage(
            name: "Rider",
            imageURL: nil,
            team: "Team",
            facts: [],
            specialties: [
                .init(title: "One day races", points: 3000),
                .init(title: "GC", points: 1500)
            ],
            keyStats: [.init(value: "12", title: "Wins", detail: nil)],
            topResults: [.init(count: "5x", kind: "Monument", race: "Lombardia", years: "2021")],
            teams: [.init(season: "2026", team: "UAE", level: "(WT)")],
            program: [.init(date: "02.07", race: "Tour", countryCode: "fr")],
            rankingBySeason: [.init(season: "2026", points: "9000", rank: "1")],
            seasonResults: [stage] + results
        )
    }

    func testRiderSectionsMapEveryField() {
        let sections = Paddock.RiderSections(page: page)

        XCTAssertEqual(sections.specialties.map(\.title), ["One day races", "GC"])
        XCTAssertEqual(sections.specialties.map(\.fraction), [1, 0.5])
        XCTAssertEqual(sections.keyStats.first?.title, "Wins")
        XCTAssertEqual(sections.topResults.first?.count, "5x")
        XCTAssertEqual(sections.program.first?.race, "Tour")
        XCTAssertEqual(sections.teams.first?.level, "(WT)")
        XCTAssertEqual(sections.ranking.first?.rank, "1")
    }

    func testRiderSectionsHideWhenThePageHasNothingMore() {
        let bare = DTO.PCSRiderPage(
            name: "Rider",
            imageURL: nil,
            team: nil,
            facts: []
        )
        XCTAssertEqual(Paddock.RiderSections(page: bare), .empty)
        XCTAssertEqual(Paddock.RiderSections(page: nil), .empty)
    }

    func testSeasonPreviewKeepsTenRaceRowsAndTheFullTableKeepsStages() {
        let sections = Paddock.RiderSections(page: page)

        XCTAssertEqual(sections.seasonPreview.count, Paddock.RiderSections.previewLimit)
        XCTAssertTrue(sections.seasonPreview.allSatisfy { !$0.isStage })
        XCTAssertEqual(sections.seasonResults.count, 15)
        XCTAssertEqual(sections.seasonResults.filter(\.isStage).count, 1)
        XCTAssertEqual(sections.seasonResults.map(\.id), Array(0..<15))
    }

    // MARK: - Season results screen

    func testSeasonResultsContextCarriesEveryRowInOrder() {
        let sections = Paddock.RiderSections(page: page)
        let context = Paddock.SeasonResultsContext(
            riderName: "Rider",
            rows: sections.seasonResults
        )

        XCTAssertEqual(context.rows.first?.race, "Stage 1")
        XCTAssertEqual(context.rows.first?.isStage, true)
        XCTAssertEqual(context.rows.count, 15)
        XCTAssertEqual(
            Set([context, context]).count,
            1,
            "The route payload is Hashable"
        )
    }
}
