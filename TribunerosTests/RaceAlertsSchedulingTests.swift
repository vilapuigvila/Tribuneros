//
//  RaceAlertsSchedulingTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class FakeScheduler: RaceAlerts.NotificationScheduling, @unchecked Sendable {
    var pending: [String] = []
    var added: [RaceAlerts.PlannedAlert] = []
    var removed: [String] = []
    var authorizationRequests = 0

    func pendingIdentifiers() async -> [String] { pending }
    func remove(identifiers: [String]) {
        removed += identifiers
        pending.removeAll { identifiers.contains($0) }
    }
    func add(_ alerts: [RaceAlerts.PlannedAlert]) async {
        added += alerts
        pending += alerts.map(\.id)
    }
    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return true
    }
}

final class RaceAlertsSchedulingTests: XCTestCase {
    private typealias Planner = RaceAlerts.Planner

    private let brussels = TimeZone(identifier: "Europe/Brussels")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    override func setUp() {
        super.setUp()
        L10n.setLanguage("en")
    }

    // MARK: - Fixtures -

    private func date(
        _ day: Int,
        _ hour: Int,
        _ minute: Int = 0,
        in zone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(
            from: DateComponents(
                year: 2026,
                month: 12,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    private func event(
        _ name: String = "World Cup Hamme",
        slug: String? = "hamme",
        date: String = "13-12-2026",
        country: String? = "Belgium",
        cancelled: Bool = false
    ) -> DTO.CXCalendarEvent {
        .init(
            date: date,
            race: name,
            raceClass: name.hasPrefix("World Cup") ? "CDM" : "C1",
            flagURL: nil,
            winnerName: "",
            isCancelled: cancelled,
            raceID: nil,
            raceSlug: slug,
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

    private func entry(
        slug: String = "hamme",
        date: String = "13-12-2026",
        times: [String]
    ) -> DTO.CXSchedules.Entry {
        .init(
            raceSlug: slug,
            date: date,
            schedule: times.map {
                .init(
                    time: $0,
                    category: "Race",
                    date: date
                )
            }
        )
    }

    private func plan(
        _ events: [DTO.CXCalendarEvent],
        schedules: [DTO.CXSchedules.Entry] = [],
        followed: Set<CXRaces.RaceSeries> = [.worldCup],
        now: Date,
        limit: Int = 64
    ) -> [RaceAlerts.PlannedAlert] {
        Planner.alerts(
            followed: followed,
            calendar: events,
            schedules: schedules,
            now: now,
            limit: limit
        )
    }

    // MARK: - Planner -

    func testPastRaceIsSkipped() {
        let alerts = plan(
            [event(date: "12-12-2026")],
            now: date(13, 8, in: brussels)
        )
        XCTAssertTrue(alerts.isEmpty)
    }

    func testFutureRaceGivesStartAndFinish() {
        let alerts = plan(
            [event()],
            now: date(10, 12, in: brussels)
        )
        XCTAssertEqual(alerts.map(\.kind), [.start, .finish])
        XCTAssertEqual(alerts[0].id, "raceAlert.worldCup.start.hamme.2026-12-13")
        XCTAssertEqual(alerts[1].id, "raceAlert.worldCup.finish.hamme.2026-12-13")
    }

    func testStartSkippedAfterTenFiftyFiveOnRaceDay() {
        let late = plan(
            [event()],
            now: date(13, 10, 56, in: brussels)
        )
        XCTAssertEqual(late.map(\.kind), [.finish])
        let early = plan(
            [event()],
            now: date(13, 8, in: brussels)
        )
        XCTAssertEqual(early.map(\.kind), [.start, .finish])
    }

    func testStartSkippedWhenFireDateAlreadyPast() {
        let start = plan(
            [event()],
            now: date(1, 12, in: brussels)
        ).first { $0.kind == .start }
        let fire = date(13, 9, in: brussels)
        XCTAssertNotNil(start)
        let afterFire = plan(
            [event()],
            now: start!.fireDate.addingTimeInterval(1)
        )
        XCTAssertFalse(afterFire.contains { $0.kind == .start })
        XCTAssertGreaterThanOrEqual(start!.fireDate, fire)
    }

    func testFinishSkippedAfterLastStartPlusSixtyMinutes() {
        let schedules = [entry(times: ["12:00", "15:00"])]
        let inTime = plan(
            [event()],
            schedules: schedules,
            now: date(13, 16, in: brussels)
        )
        XCTAssertEqual(inTime.map(\.kind), [.finish])
        let tooLate = plan(
            [event()],
            schedules: schedules,
            now: date(13, 16, 1, in: brussels)
        )
        XCTAssertTrue(tooLate.isEmpty)
    }

    func testPendingAlertsSurviveTheirCutoffs() {
        let schedules = [entry(times: ["15:00"])]
        let finishID = "raceAlert.worldCup.finish.hamme.2026-12-13"
        let kept = Planner.alerts(
            followed: [.worldCup],
            calendar: [event()],
            schedules: schedules,
            now: date(13, 16, 10, in: brussels),
            pending: [finishID]
        )
        XCTAssertEqual(kept.map(\.id), [finishID])
        let fired = Planner.alerts(
            followed: [.worldCup],
            calendar: [event()],
            schedules: schedules,
            now: date(13, 16, 16, in: brussels),
            pending: [finishID]
        )
        XCTAssertTrue(fired.isEmpty)
    }

    func testFinishUsesLatestRowPlusSeventyFiveMinutes() {
        let finish = plan(
            [event()],
            schedules: [entry(times: ["15:00", "10:30", "13:45"])],
            now: date(1, 12, in: brussels)
        ).first { $0.kind == .finish }
        XCTAssertEqual(finish?.fireDate, date(13, 16, 15, in: brussels))
    }

    func testFinishIgnoresRowsOfOtherDays() {
        let rows: [DTO.CXRacePage.ScheduledStart] = [
            .init(time: "13:00", category: "Men Elite", date: "13-12-2026"),
            .init(time: "17:00", category: "Men Elite", date: "14-12-2026")
        ]
        let finish = plan(
            [event()],
            schedules: [.init(raceSlug: "hamme", date: "13-12-2026", schedule: rows)],
            now: date(1, 12, in: brussels)
        ).first { $0.kind == .finish }
        XCTAssertEqual(finish?.fireDate, date(13, 14, 15, in: brussels))
    }

    func testFinishFallsBackToThreePM() {
        let finish = plan(
            [event()],
            now: date(1, 12, in: brussels)
        ).first { $0.kind == .finish }
        XCTAssertEqual(finish?.fireDate, date(13, 16, 15, in: brussels))
    }

    func testVenueTimeZoneBelgiumVersusUS() {
        let now = date(1, 12, in: brussels)
        let belgium = plan(
            [event(country: "Belgium")],
            now: now
        ).first { $0.kind == .finish }
        let us = plan(
            [event(country: "United States")],
            now: now
        ).first { $0.kind == .finish }
        XCTAssertEqual(belgium?.fireDate, date(13, 16, 15, in: brussels))
        XCTAssertEqual(us?.fireDate, date(13, 16, 15, in: newYork))
        XCTAssertNotEqual(belgium?.fireDate, us?.fireDate)
    }

    func testStartMinuteIsSeededAndInWindow() {
        let now = date(1, 12, in: brussels)
        let first = plan([event()], now: now)
        let second = plan([event()], now: now)
        XCTAssertEqual(first, second)
        for index in 0..<40 {
            let alerts = plan(
                [event(slug: "race\(index)")],
                now: now
            )
            let start = alerts.first { $0.kind == .start }!.fireDate
            XCTAssertGreaterThanOrEqual(start, date(13, 9, in: brussels))
            XCTAssertLessThan(start, date(13, 11, in: brussels))
        }
    }

    func testBodiesAreWomenOrMen() {
        let alerts = plan(
            [event()],
            now: date(1, 12, in: brussels)
        )
        let starts = ["Women’s elite starts soon - stay tuned 👀", "Men’s elite starts soon - stay tuned 👀"]
        let finishes = [
            "Women’s elite finished - see the results 🏆🏆🏆",
            "Men’s elite finished - see the results 🏆🏆🏆"
        ]
        XCTAssertTrue(starts.contains(alerts[0].body))
        XCTAssertTrue(finishes.contains(alerts[1].body))
    }

    func testCapKeepsNearestSixtyFour() {
        let events = (0..<30).flatMap { day -> [DTO.CXCalendarEvent] in
            let dayText = String(format: "%02d", day + 1)
            return (0..<3).map {
                event(
                    slug: "race\(day)-\($0)",
                    date: "\(dayText)-01-2027"
                )
            }
        }
        let now = date(1, 12, in: brussels)
        let all = plan(events, now: now, limit: 1000)
        let capped = plan(events, now: now)
        XCTAssertEqual(all.count, 180)
        XCTAssertEqual(capped.count, 64)
        XCTAssertEqual(capped, Array(all.prefix(64)))
    }

    func testFlagEmojiAndTitles() {
        XCTAssertEqual(Planner.flagEmoji(country: "Belgium"), "🇧🇪")
        XCTAssertNil(Planner.flagEmoji(country: "Atlantis"))
        XCTAssertNil(Planner.flagEmoji(country: nil))
        let now = date(1, 12, in: brussels)
        let known = plan([event(country: "Belgium")], now: now)
        XCTAssertEqual(known[0].title, "🇧🇪 World Cup Hamme")
        XCTAssertEqual(known[1].title, "🇧🇪 World Cup Hamme 🏁🏁🏁")
        let unknown = plan([event(country: "Atlantis")], now: now)
        XCTAssertEqual(unknown[0].title, "World Cup Hamme")
    }

    func testOnlyFollowedSeriesAndNotCancelled() {
        let now = date(1, 12, in: brussels)
        let events = [
            event("World Cup Hamme", slug: "a"),
            event("Superprestige Diegem", slug: "b"),
            event("Exact Cross Mol", slug: "c"),
            event("World Cup Cancelled", slug: "d", cancelled: true)
        ]
        let alerts = plan(events, followed: [.superprestige], now: now)
        XCTAssertEqual(Set(alerts.map(\.id)).count, 2)
        XCTAssertTrue(alerts.allSatisfy { $0.id.contains(".b.") })
        XCTAssertTrue(plan(events, followed: [.exactCross], now: now).isEmpty)
    }

    // MARK: - Interactor -

    private func makeInteractor(
        scheduler: FakeScheduler,
        authorization: RaceAlerts.Authorization = .allowed,
        stored: [String] = []
    ) -> RaceAlerts.InteractorImpl {
        let now = date(1, 12, in: brussels)
        let events = [
            event("World Cup Hamme", slug: "hamme"),
            event("Superprestige Diegem", slug: "diegem", date: "27-12-2026")
        ]
        return RaceAlerts.InteractorImpl(
            store: RaceAlerts.Store(
                loadFollowed: { stored },
                saveFollowed: { _ in },
                authorization: { authorization },
                loadCalendar: { events },
                loadSchedules: { [] },
                scheduler: scheduler,
                now: { now }
            )
        )
    }

    func testFollowingSchedulesAndUnfollowingRemoves() async {
        let scheduler = FakeScheduler()
        let interactor = makeInteractor(scheduler: scheduler)
        interactor.useCase(.setFollowing(.worldCup, true))
        interactor.useCase(.setFollowing(.superprestige, true))
        await interactor.waitForReplan()
        XCTAssertEqual(scheduler.pending.count, 4)
        interactor.useCase(.setFollowing(.superprestige, false))
        await interactor.waitForReplan()
        XCTAssertEqual(scheduler.pending.sorted().count, 2)
        XCTAssertTrue(scheduler.pending.allSatisfy { $0.contains(".hamme.") })
        interactor.useCase(.setFollowing(.worldCup, false))
        await interactor.waitForReplan()
        XCTAssertTrue(scheduler.pending.isEmpty)
    }

    func testUnfollowingWithoutCalendarStillRemovesThatSeries() async {
        final class Box: @unchecked Sendable { var isOnline = true }
        let box = Box()
        let scheduler = FakeScheduler()
        let now = date(1, 12, in: brussels)
        let events = [
            event("World Cup Hamme", slug: "hamme"),
            event("Superprestige Diegem", slug: "diegem", date: "27-12-2026")
        ]
        let interactor = RaceAlerts.InteractorImpl(
            store: RaceAlerts.Store(
                loadFollowed: { [] },
                saveFollowed: { _ in },
                authorization: { .allowed },
                loadCalendar: { box.isOnline ? events : nil },
                loadSchedules: { [] },
                scheduler: scheduler,
                now: { now }
            )
        )
        interactor.useCase(.setFollowing(.worldCup, true))
        interactor.useCase(.setFollowing(.superprestige, true))
        await interactor.waitForReplan()
        XCTAssertEqual(scheduler.pending.count, 4)
        box.isOnline = false
        interactor.useCase(.setFollowing(.superprestige, false))
        await interactor.waitForReplan()
        XCTAssertEqual(scheduler.pending.count, 2)
        XCTAssertTrue(scheduler.pending.allSatisfy { $0.hasPrefix("raceAlert.worldCup.") })
    }

    func testSeriesOfID() {
        XCTAssertEqual(Planner.series(ofID: "raceAlert.worldCup.start.hamme.2026-12-13"), .worldCup)
        XCTAssertNil(Planner.series(ofID: "raceAlert.start.hamme.2026-12-13"))
        XCTAssertNil(Planner.series(ofID: "other.worldCup"))
    }

    func testReplanOnlyRemovesRaceAlertIdentifiers() async {
        let scheduler = FakeScheduler()
        scheduler.pending = ["other.thing", "raceAlert.start.old.2026-01-01"]
        let interactor = makeInteractor(scheduler: scheduler)
        interactor.useCase(.setFollowing(.worldCup, true))
        await interactor.waitForReplan()
        XCTAssertEqual(scheduler.removed, ["raceAlert.start.old.2026-01-01"])
        XCTAssertTrue(scheduler.pending.contains("other.thing"))
    }

    func testBlockedSchedulesNothingAndKeepsChoice() async {
        let scheduler = FakeScheduler()
        scheduler.pending = ["raceAlert.start.old.2026-01-01"]
        let interactor = makeInteractor(
            scheduler: scheduler,
            authorization: .blocked
        )
        interactor.useCase(.setFollowing(.worldCup, true))
        await interactor.waitForReplan()
        XCTAssertTrue(scheduler.added.isEmpty)
        XCTAssertTrue(scheduler.pending.isEmpty)
        XCTAssertEqual(interactor.domain.followed, [.worldCup])
    }

    func testSwitchOnWhileUndeterminedRequestsAuthorization() async {
        let scheduler = FakeScheduler()
        let interactor = makeInteractor(
            scheduler: scheduler,
            authorization: .notDetermined
        )
        interactor.useCase(.setFollowing(.worldCup, true))
        await interactor.waitForReplan()
        XCTAssertEqual(scheduler.authorizationRequests, 1)
        XCTAssertTrue(scheduler.added.isEmpty)
    }

    func testRefreshAuthorizationReplansStoredChoices() async {
        let scheduler = FakeScheduler()
        let interactor = makeInteractor(
            scheduler: scheduler,
            stored: ["worldCup"]
        )
        interactor.useCase(.refreshAuthorization)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await interactor.waitForReplan()
        XCTAssertEqual(scheduler.pending.count, 2)
    }
}
