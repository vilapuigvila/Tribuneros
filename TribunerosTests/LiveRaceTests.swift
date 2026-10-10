//
//  LiveRaceTests.swift
//  TribunerosTests
//
//  The live race screen: the hint rule and text, the PCS live page URL, the polling window (on a
//  fake clock, so nothing waits in real time), the hint recording, and the view model mapping
//  ("ago" text, highlighted stats, the messages).
//

import XCTest
import Combine
@testable import Tribuneros

final class LiveRaceTests: XCTestCase {
    private typealias LiveRace = HomeRaces.LiveRace
    private typealias Interactor = LiveRace.InteractorImpl
    private typealias ViewModel = LiveRace.ViewModel<LiveRace.InteractorImpl>

    private let first = Date(timeIntervalSince1970: 1_800_000_000)
    private let hour: TimeInterval = 3600

    private let context = LiveRace.Context(
        name: "Il Lombardia",
        subtitle: "1.UWT",
        flagCode: "it",
        url: LiveRace.Context.liveURL(urlPath: "race/il-lombardia/2026/result")
    )

    private let page = DTO.LivePage(
        stats: [
            DTO.LivePage.Stat(
                key: "kmtogo",
                label: "KM to go",
                value: "121.2"
            ),
            DTO.LivePage.Stat(
                key: "race_status",
                label: "Status",
                value: "racing"
            )
        ],
        status: "racing",
        profile: nil,
        groups: [],
        events: []
    )

    // MARK: - Fakes -

    /// Time for the interactor: `sleep` advances it, so no test waits in real time.
    private final class FakeClock {
        static let origin = Date(timeIntervalSince1970: 1_800_000_000)

        let start = FakeClock.origin
        var date = FakeClock.origin
        private(set) var sleeps: [TimeInterval] = []
        /// Runs after each sleep with the sleep count, so a test can act in the middle of a window.
        var onSleep: ((Int) -> Void)?

        func sleep(_ seconds: TimeInterval) {
            date = date.addingTimeInterval(seconds)
            sleeps.append(seconds)
            onSleep?(sleeps.count)
        }
    }

    /// Counts the fetches; the page returned for each one comes from `respond` (fetch 1 is 1).
    private final class FakeFeed {
        private(set) var fetches = 0
        private let respond: (Int) -> DTO.LivePage?

        init(respond: @escaping (Int) -> DTO.LivePage?) {
            self.respond = respond
        }

        func fetch() -> DTO.LivePage? {
            fetches += 1
            return respond(fetches)
        }
    }

    /// The hint's stored values, kept in memory.
    private final class HintBox {
        var firstShown: Date?
        var count = 0
        var records: [Int] = []

        var store: LiveRace.HintStore {
            LiveRace.HintStore(
                firstShown: { self.firstShown },
                count: { self.count },
                record: { date, count in
                    self.firstShown = self.firstShown ?? date
                    self.count = count
                    self.records.append(count)
                }
            )
        }
    }

    private func makeInteractor(
        url: URL?,
        feed: FakeFeed,
        clock: FakeClock,
        hints: HintBox = HintBox()
    ) -> Interactor {
        Interactor(
            url: url,
            loadPage: { _ in feed.fetch() },
            now: { clock.date },
            sleep: { clock.sleep($0) },
            hintStore: hints.store
        )
    }

    /// Lets the window task run until it is over; the fake sleep never waits, so this ends fast.
    @MainActor
    private func settle(_ interactor: Interactor) async {
        var turns = 0
        while interactor.domain.isPolling, turns < 1_000 {
            turns += 1
            await Task.yield()
        }
    }

    // MARK: - Hint -

    func testHintTextSaysWhatPollingDoes() {
        XCTAssertEqual(
            LiveRace.Hint.text,
            "Live updates every 5 seconds for a minute. Pull down to follow again."
        )
    }

    func testHintShowsOnAFreshInstall() {
        XCTAssertTrue(
            LiveRace.Hint.shouldShow(
                now: first,
                firstShown: nil,
                count: 0
            )
        )
    }

    func testHintWaitsFor48HoursAfterTheFirstShowing() {
        XCTAssertFalse(
            LiveRace.Hint.shouldShow(
                now: first.addingTimeInterval(47 * hour),
                firstShown: first,
                count: 1
            )
        )
        XCTAssertTrue(
            LiveRace.Hint.shouldShow(
                now: first.addingTimeInterval(48 * hour),
                firstShown: first,
                count: 1
            )
        )
    }

    func testHintNeverShowsAThirdTime() {
        XCTAssertFalse(
            LiveRace.Hint.shouldShow(
                now: first.addingTimeInterval(500 * hour),
                firstShown: first,
                count: 2
            )
        )
    }

    // MARK: - Live URL -

    func testLiveURLAddsLiveToTheRacePath() {
        XCTAssertEqual(
            LiveRace.Context.liveURL(urlPath: "race/il-lombardia/2026/result")?.absoluteString,
            "https://www.procyclingstats.com/race/il-lombardia/2026/result/live"
        )
    }

    func testLiveURLAcceptsAnAbsoluteOrSlashedPath() {
        let expected = "https://www.procyclingstats.com/race/il-lombardia/2026/result/live"
        XCTAssertEqual(
            LiveRace.Context.liveURL(urlPath: "https://www.procyclingstats.com/race/il-lombardia/2026/result")?.absoluteString,
            expected
        )
        XCTAssertEqual(
            LiveRace.Context.liveURL(urlPath: "/race/il-lombardia/2026/result/")?.absoluteString,
            expected
        )
    }

    func testLiveURLIsNotDoubledAndEmptyPathsHaveNoURL() {
        XCTAssertEqual(
            LiveRace.Context.liveURL(urlPath: "race/il-lombardia/2026/result/live")?.absoluteString,
            "https://www.procyclingstats.com/race/il-lombardia/2026/result/live"
        )
        XCTAssertNil(LiveRace.Context.liveURL(urlPath: nil))
        XCTAssertNil(LiveRace.Context.liveURL(urlPath: ""))
        XCTAssertNil(LiveRace.Context.liveURL(urlPath: "   "))
    }

    // MARK: - Polling -

    @MainActor
    func testOneWindowPollsTwelveTimesAndStops() async {
        let feed = FakeFeed(respond: { _ in self.page })
        let clock = FakeClock()
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock
        )

        interactor.useCase(.start)
        await settle(interactor)

        XCTAssertEqual(feed.fetches, 12)
        XCTAssertEqual(clock.sleeps.count, 11)
        XCTAssertEqual(clock.date.timeIntervalSince(clock.start), 55)
        XCTAssertFalse(interactor.domain.isPolling)
        XCTAssertEqual(interactor.domain.load, .loaded(page))
    }

    @MainActor
    func testRefreshRestartsTheWindowAndWaitsForItsFirstFetch() async {
        let feed = FakeFeed(respond: { _ in self.page })
        let clock = FakeClock()
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock
        )

        interactor.useCase(.start)
        await settle(interactor)
        XCTAssertEqual(feed.fetches, 12)

        await interactor.refresh()
        XCTAssertGreaterThanOrEqual(feed.fetches, 13)

        await settle(interactor)
        XCTAssertEqual(feed.fetches, 24)
        XCTAssertFalse(interactor.domain.isPolling)
    }

    @MainActor
    func testStopEndsTheWindowAtOnce() async {
        let feed = FakeFeed(respond: { _ in self.page })
        let clock = FakeClock()
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock
        )
        clock.onSleep = { count in
            if count == 3 {
                interactor.useCase(.stop)
            }
        }

        interactor.useCase(.start)
        await settle(interactor)

        XCTAssertEqual(feed.fetches, 3)
        XCTAssertFalse(interactor.domain.isPolling)
    }

    @MainActor
    func testAFailedPollKeepsTheLastPage() async {
        let page = self.page
        let feed = FakeFeed(respond: { $0 == 1 ? page : nil })
        let clock = FakeClock()
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock
        )

        interactor.useCase(.start)
        await settle(interactor)

        XCTAssertEqual(feed.fetches, 12)
        XCTAssertEqual(interactor.domain.load, .loaded(page))
        XCTAssertEqual(interactor.domain.updatedAt, clock.start)
    }

    @MainActor
    func testFailedFromTheStartStaysFailedAndKeepsPolling() async {
        let feed = FakeFeed(respond: { _ in nil })
        let clock = FakeClock()
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock
        )

        interactor.useCase(.start)
        await settle(interactor)

        XCTAssertEqual(feed.fetches, 12)
        XCTAssertEqual(interactor.domain.load, .failed)
        XCTAssertNil(interactor.domain.updatedAt)
    }

    @MainActor
    func testNoURLFailsAndNeverPolls() async {
        let feed = FakeFeed(respond: { _ in self.page })
        let clock = FakeClock()
        let interactor = makeInteractor(
            url: nil,
            feed: feed,
            clock: clock
        )

        interactor.useCase(.start)
        await settle(interactor)

        XCTAssertEqual(interactor.domain.load, .failed)
        XCTAssertFalse(interactor.domain.isPolling)
        XCTAssertFalse(interactor.domain.showHint)
        XCTAssertEqual(feed.fetches, 0)
        XCTAssertEqual(clock.sleeps.count, 0)
    }

    // MARK: - Hint recording -

    @MainActor
    func testHintShowsOnTheFirstStartAndIsRecordedOnce() async {
        let feed = FakeFeed(respond: { _ in self.page })
        let clock = FakeClock()
        let hints = HintBox()
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock,
            hints: hints
        )

        interactor.useCase(.start)
        XCTAssertTrue(interactor.domain.showHint)
        XCTAssertEqual(hints.count, 1)
        XCTAssertEqual(hints.firstShown, clock.start)

        await settle(interactor)
        interactor.useCase(.start)
        XCTAssertEqual(hints.records, [1])
        XCTAssertEqual(hints.count, 1)

        interactor.useCase(.dismissHint)
        XCTAssertFalse(interactor.domain.showHint)
    }

    @MainActor
    func testHintStaysHiddenInsideTheWaitAfterAShowing() async {
        let feed = FakeFeed(respond: { _ in self.page })
        let clock = FakeClock()
        let hints = HintBox()
        hints.firstShown = clock.start
        hints.count = 1
        clock.date = clock.start.addingTimeInterval(47 * hour)
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock,
            hints: hints
        )

        interactor.useCase(.start)

        XCTAssertFalse(interactor.domain.showHint)
        XCTAssertEqual(hints.records, [])
    }

    // MARK: - View model mapping -

    private func domain(
        load: LiveRace.Load,
        isPolling: Bool = false,
        updatedAt: Date? = nil
    ) -> LiveRace.Domain {
        LiveRace.Domain(
            url: context.url,
            load: load,
            isPolling: isPolling,
            updatedAt: updatedAt,
            showHint: false
        )
    }

    /// A racing page with a profile (so the profile fields are mapped), the given stats and groups.
    private func racingPage(
        stats: [DTO.LivePage.Stat] = [],
        groups: [DTO.LivePage.Group] = []
    ) -> DTO.LivePage {
        DTO.LivePage(
            stats: stats,
            status: "racing",
            profile: DTO.LivePage.Profile(
                points: [
                    DTO.LivePage.Profile.Point(x: 0, y: 0.2),
                    DTO.LivePage.Profile.Point(x: 1, y: 0.6)
                ],
                progress: 0.252,
                elevationLabels: ["200"],
                keypoints: [],
                routeKm: 239.4,
                kmLabels: [DTO.LivePage.Profile.KmLabel(km: 0, x: 0)]
            ),
            groups: groups,
            events: []
        )
    }

    private func viewState(_ domain: LiveRace.Domain) -> LiveRace.ViewState {
        ViewModel.mapToViewState(
            context: context,
            domain: domain
        )
    }

    func testIdleAndLoadingShowTheLoadingBody() {
        XCTAssertEqual(viewState(domain(load: .idle)).body, .loading)
        XCTAssertEqual(viewState(domain(load: .loading)).body, .loading)
    }

    func testFailedShowsTheUnavailableMessageAndKeepsTheHeader() {
        let state = viewState(domain(load: .failed))

        XCTAssertEqual(
            state.body,
            .unavailable(message: "Couldn't load the live race. Pull down to try again.")
        )
        XCTAssertEqual(state.title, "Il Lombardia")
        XCTAssertEqual(state.subtitle, "1.UWT")
        XCTAssertEqual(state.flagCode, "it")
        XCTAssertEqual(state.pcsURL, context.url)
        XCTAssertEqual(state.updatedText, "")
    }

    func testLoadedPageHighlightsTheStatusOnly() {
        let state = viewState(domain(load: .loaded(page)))

        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        XCTAssertEqual(content.stats.map(\.label), ["KM TO GO", "STATUS"])
        XCTAssertEqual(content.stats.map(\.isHighlighted), [false, true])
        XCTAssertNil(content.profile)
        XCTAssertEqual(content.groups, [])
    }

    func testKpiStripKeepsTheRaceStatsInTheScreenOrder() {
        let stats = [
            DTO.LivePage.Stat(key: "nr_online", label: "#online", value: "9153"),
            DTO.LivePage.Stat(key: "", label: "Start", value: "11:00"),
            DTO.LivePage.Stat(key: "autosync", label: "Autosync", value: "on"),
            DTO.LivePage.Stat(key: "race_status", label: "Status", value: "racing"),
            DTO.LivePage.Stat(key: "elevation_remaining", label: "Elevation-", value: "-"),
            DTO.LivePage.Stat(key: "avg", label: "Avg.", value: "42.6"),
            DTO.LivePage.Stat(key: "racetime", label: "Racetime", value: "1:25:00"),
            DTO.LivePage.Stat(key: "kmdone", label: "KM done", value: "60.4"),
            DTO.LivePage.Stat(key: "kmtogo", label: "KM to go", value: "179.0")
        ]

        let state = viewState(domain(load: .loaded(racingPage(stats: stats))))

        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        XCTAssertEqual(content.stats.map(\.label), ["KM TO GO", "KM DONE", "RACETIME", "AVG.", "START", "STATUS"])
        XCTAssertEqual(content.stats.map(\.value), ["179.0", "60.4", "1:25:00", "42.6", "11:00", "racing"])
        XCTAssertEqual(content.stats.map(\.isHighlighted), [false, false, false, false, false, true])
    }

    func testElevationMinusShowsOnlyOnceKnown() {
        let stats = [
            DTO.LivePage.Stat(key: "elevation_remaining", label: "Elevation-", value: "1840"),
            DTO.LivePage.Stat(key: "avg", label: "Avg.", value: "42.6")
        ]

        let state = viewState(domain(load: .loaded(racingPage(stats: stats))))

        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        XCTAssertEqual(content.stats.map(\.label), ["AVG.", "ELEVATION-"])
    }

    func testAutosyncAndOnlineCountAreLeftOut() {
        let stats = [
            DTO.LivePage.Stat(key: "autosync", label: "Autosync", value: "on"),
            DTO.LivePage.Stat(key: "nr_online", label: "#online", value: "9153")
        ]

        let state = viewState(domain(load: .loaded(racingPage(stats: stats))))

        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        XCTAssertEqual(content.stats, [])
    }

    func testGapShowsOnlyAfterTheFirstGroup() {
        let groups = [
            DTO.LivePage.Group(
                name: "break",
                gap: "+0:00",
                gapSeconds: 0,
                badge: "1",
                isPeloton: false,
                riders: [DTO.LivePage.Group.Rider(position: 1, bib: "26", name: "TIBERI Antonio", countryCode: "it")]
            ),
            DTO.LivePage.Group(
                name: "Peloton",
                gap: "+1:25",
                gapSeconds: 85,
                badge: "P",
                isPeloton: true,
                riders: []
            )
        ]

        let state = viewState(domain(load: .loaded(racingPage(groups: groups))))

        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        XCTAssertEqual(content.groups.map(\.name), ["BREAK", "PELOTON"])
        XCTAssertEqual(content.groups.map(\.gap), ["", "+1:25"])
        XCTAssertEqual(content.groups.map(\.isPeloton), [false, true])
        XCTAssertEqual(content.groups[0].riders.first?.position, "1")
        XCTAssertEqual(content.groups[0].riders.first?.bib, "26")
    }

    func testPelotonEstimateIsTheFrontKmMinusTheGapAtAverageSpeed() throws {
        let groups = [
            DTO.LivePage.Group(
                name: "Peloton",
                gap: "+1:25",
                gapSeconds: 85,
                badge: "P",
                isPeloton: true,
                riders: []
            )
        ]
        let stats = [
            DTO.LivePage.Stat(key: "kmdone", label: "KM done", value: "60.4"),
            DTO.LivePage.Stat(key: "avg", label: "Avg.", value: "42.6")
        ]

        let state = viewState(domain(load: .loaded(racingPage(stats: stats, groups: groups))))

        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        let profile = try XCTUnwrap(content.profile)
        XCTAssertEqual(profile.frontKm, 60.4)
        XCTAssertEqual(try XCTUnwrap(profile.pelotonKm), 60.4 - 85 * 42.6 / 3600, accuracy: 0.0001)
        XCTAssertEqual(profile.routeKm, 239.4)
    }

    func testPelotonEstimateIsNilWhenAnInputIsUnknown() {
        XCTAssertNil(ViewModel.estimatedPelotonKm(frontKm: nil, gapSeconds: 85, averageKmh: 42.6))
        XCTAssertNil(ViewModel.estimatedPelotonKm(frontKm: 60.4, gapSeconds: nil, averageKmh: 42.6))
        XCTAssertNil(ViewModel.estimatedPelotonKm(frontKm: 60.4, gapSeconds: 85, averageKmh: nil))

        let state = viewState(domain(load: .loaded(racingPage(stats: []))))
        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        XCTAssertNil(content.profile?.pelotonKm)
    }

    func testProfileAppearsOnlyWithPoints() {
        let profile = DTO.LivePage.Profile(
            points: [
                DTO.LivePage.Profile.Point(x: 0, y: 0),
                DTO.LivePage.Profile.Point(x: 1, y: 0.5)
            ],
            progress: 0.4,
            elevationLabels: ["0", "250"],
            keypoints: [],
            routeKm: nil,
            kmLabels: []
        )
        let withProfile = DTO.LivePage(
            stats: [],
            status: "racing",
            profile: profile,
            groups: [],
            events: []
        )

        let state = viewState(domain(load: .loaded(withProfile)))

        guard case .loaded(let content) = state.body else {
            return XCTFail("expected the loaded body, got \(state.body)")
        }
        XCTAssertEqual(content.profile?.progress, 0.4)
        XCTAssertEqual(content.profile?.elevationLabels, ["0", "250"])
    }

    func testUpdatedLineShowsTheClockOfTheLastUpdate() throws {
        let updated = try XCTUnwrap(
            Calendar.current.date(
                from: DateComponents(
                    year: 2026,
                    month: 10,
                    day: 10,
                    hour: 14,
                    minute: 5,
                    second: 9
                )
            )
        )

        let state = viewState(
            domain(
                load: .loaded(page),
                updatedAt: updated
            )
        )

        XCTAssertEqual(state.updatedText, "Updated 14:05:09")
    }

    // MARK: - View model -

    @MainActor
    func testViewModelShowsThePageOnceTheInteractorHasIt() async {
        let page = self.page
        let feed = FakeFeed(respond: { _ in page })
        let clock = FakeClock()
        let interactor = makeInteractor(
            url: context.url,
            feed: feed,
            clock: clock
        )
        let viewModel = ViewModel(
            context: context,
            router: Router(),
            interactor: interactor
        )

        let loaded = expectation(description: "the page reaches the screen")
        var cancellable: AnyCancellable?
        cancellable = viewModel.$stateView.sink { state in
            guard case .loaded = state.body else { return }
            loaded.fulfill()
            cancellable?.cancel()
        }

        viewModel.action(.onAppear)
        await fulfillment(of: [loaded], timeout: 2)

        XCTAssertEqual(viewModel.stateView.pcsURL, context.url)
        XCTAssertGreaterThanOrEqual(feed.fetches, 1)
    }
}
