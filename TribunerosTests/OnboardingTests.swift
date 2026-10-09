//
//  OnboardingTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class OnboardingTests: XCTestCase {
    private let first = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 3600

    // MARK: - Schedule

    func testFirstLaunchShows() {
        XCTAssertTrue(
            Onboarding.Schedule.shouldShow(
                now: first,
                firstShown: nil,
                count: 0
            )
        )
    }

    func testBeforeSevenDaysDoesNotShow() {
        XCTAssertFalse(
            Onboarding.Schedule.shouldShow(
                now: first.addingTimeInterval(7 * day - 1),
                firstShown: first,
                count: 1
            )
        )
    }

    func testAtAndAfterSevenDaysShows() {
        XCTAssertTrue(
            Onboarding.Schedule.shouldShow(
                now: first.addingTimeInterval(7 * day),
                firstShown: first,
                count: 1
            )
        )
        XCTAssertTrue(
            Onboarding.Schedule.shouldShow(
                now: first.addingTimeInterval(40 * day),
                firstShown: first,
                count: 1
            )
        )
    }

    func testNeverAThirdTime() {
        XCTAssertFalse(
            Onboarding.Schedule.shouldShow(
                now: first.addingTimeInterval(365 * day),
                firstShown: first,
                count: 2
            )
        )
    }

    func testShowingRecordsTheFirstDateAndCount() {
        let firstShowing = Onboarding.Schedule.showing(
            now: first,
            record: Onboarding.Record(firstShown: nil, count: 0)
        )
        XCTAssertEqual(firstShowing, Onboarding.Record(firstShown: first, count: 1))

        let secondShowing = Onboarding.Schedule.showing(
            now: first.addingTimeInterval(8 * day),
            record: Onboarding.Record(firstShown: first, count: 1)
        )
        XCTAssertEqual(secondShowing, Onboarding.Record(firstShown: first, count: 2))

        XCTAssertNil(
            Onboarding.Schedule.showing(
                now: first.addingTimeInterval(30 * day),
                record: Onboarding.Record(firstShown: first, count: 2)
            )
        )
    }

    func testSeededSecondShowingOnlyOnAFreshRecord() {
        let seeded = Onboarding.Schedule.seededForSecondShowing(
            Onboarding.Record(firstShown: nil, count: 0),
            now: first
        )
        XCTAssertEqual(seeded.count, 1)
        XCTAssertTrue(
            Onboarding.Schedule.shouldShow(
                now: first,
                firstShown: seeded.firstShown,
                count: seeded.count
            )
        )
        let done = Onboarding.Record(firstShown: first, count: 2)
        XCTAssertEqual(
            Onboarding.Schedule.seededForSecondShowing(
                done,
                now: first
            ),
            done
        )
    }

    // MARK: - Presenter

    private final class MemoryStore {
        var record = Onboarding.Record(firstShown: nil, count: 0)

        var store: Onboarding.Store {
            Onboarding.Store(
                load: { self.record },
                save: { self.record = $0 }
            )
        }
    }

    @MainActor
    private func launch(
        _ memory: MemoryStore,
        at date: Date,
        isEnabled: Bool = true,
        seedsSecondShowing: Bool = false
    ) -> Onboarding.Presenter {
        let presenter = Onboarding.Presenter(
            store: memory.store,
            now: { date }
        )
        presenter.start(
            isEnabled: isEnabled,
            seedsSecondShowing: seedsSecondShowing
        )
        return presenter
    }

    @MainActor
    func testSkipAndFinishBothCountAsSeen() {
        for dismissal in [Onboarding.Dismissal.skip, .finish] {
            let memory = MemoryStore()
            let firstLaunch = launch(memory, at: first)
            XCTAssertEqual(firstLaunch.showing, 1)
            firstLaunch.dismiss(dismissal)
            XCTAssertNil(firstLaunch.showing)
            XCTAssertEqual(memory.record, Onboarding.Record(firstShown: first, count: 1))

            XCTAssertNil(launch(memory, at: first.addingTimeInterval(day)).showing)

            let secondLaunch = launch(memory, at: first.addingTimeInterval(7 * day))
            XCTAssertEqual(secondLaunch.showing, 2)
            secondLaunch.dismiss(dismissal)
            XCTAssertEqual(memory.record, Onboarding.Record(firstShown: first, count: 2))

            XCTAssertNil(launch(memory, at: first.addingTimeInterval(60 * day)).showing)
            XCTAssertEqual(memory.record.count, 2)
        }
    }

    @MainActor
    func testStartsOncePerProcess() {
        let memory = MemoryStore()
        let presenter = launch(memory, at: first)
        presenter.dismiss(.finish)
        presenter.start(isEnabled: true)
        XCTAssertNil(presenter.showing)
        XCTAssertEqual(memory.record.count, 1)
    }

    @MainActor
    func testDisabledLaunchRecordsNothing() {
        let memory = MemoryStore()
        XCTAssertNil(launch(memory, at: first, isEnabled: false).showing)
        XCTAssertEqual(memory.record, Onboarding.Record(firstShown: nil, count: 0))
    }

    @MainActor
    func testForcedSecondShowingThenNeverAgain() {
        let memory = MemoryStore()
        XCTAssertEqual(launch(memory, at: first, seedsSecondShowing: true).showing, 2)
        XCTAssertNil(launch(memory, at: first, seedsSecondShowing: true).showing)
    }

    @MainActor
    func testResetForgetsThePastShowings() {
        let memory = MemoryStore()
        let seen = launch(memory, at: first)
        seen.dismiss(.finish)
        XCTAssertNil(launch(memory, at: first).showing)

        let presenter = Onboarding.Presenter(
            store: memory.store,
            now: { self.first }
        )
        presenter.start(
            isEnabled: true,
            resets: true
        )
        XCTAssertEqual(presenter.showing, 1)
        XCTAssertEqual(memory.record, Onboarding.Record(firstShown: first, count: 1))
    }

    @MainActor
    func testResetWorksEvenWhenDisabled() {
        let memory = MemoryStore()
        launch(memory, at: first).dismiss(.finish)
        let presenter = Onboarding.Presenter(
            store: memory.store,
            now: { self.first }
        )
        presenter.start(
            isEnabled: false,
            resets: true
        )
        XCTAssertNil(presenter.showing)
        XCTAssertEqual(memory.record, Onboarding.Record(firstShown: nil, count: 0))
    }

    // MARK: - Launch switches and pages

    func testShownWithoutMocksAndSkippedWithMocks() {
        XCTAssertTrue(Onboarding.isEnabled(override: nil, hasMockScenario: false))
        XCTAssertFalse(Onboarding.isEnabled(override: nil, hasMockScenario: true))
        XCTAssertTrue(Onboarding.isEnabled(override: true, hasMockScenario: true))
        XCTAssertFalse(Onboarding.isEnabled(override: false, hasMockScenario: false))
    }

    #if DEBUG
    func testDebugFlag() {
        XCTAssertEqual(Onboarding.debugFlag(environment: ["ONBOARDING": "1"], key: "ONBOARDING", launchValue: nil), true)
        XCTAssertEqual(Onboarding.debugFlag(environment: [:], key: "ONBOARDING", launchValue: "on"), true)
        XCTAssertEqual(Onboarding.debugFlag(environment: ["ONBOARDING": "off"], key: "ONBOARDING", launchValue: "on"), false)
        XCTAssertNil(Onboarding.debugFlag(environment: [:], key: "ONBOARDING", launchValue: nil))
    }
    #endif

    func testPagesHaveBundledAnimationsAndLabels() {
        let pages = Onboarding.pages(showing: 1)
        XCTAssertEqual(pages.map(\.id), [0, 1, 2, 3])
        XCTAssertEqual(Set(pages.map(\.animation)).count, pages.count)
        let bundle = Bundle(for: Onboarding.Presenter.self)
        for page in pages {
            XCTAssertNotNil(bundle.url(forResource: page.animation, withExtension: "json"), page.animation)
            XCTAssertFalse(page.accessibilityLabel.isEmpty)
        }
        XCTAssertNotEqual(Onboarding.pages(showing: 2)[0].title, pages[0].title)
    }
}
