//
//  WhatsNewTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

@MainActor
final class WhatsNewTests: XCTestCase {
    private let releases = [
        WhatsNew.Release(version: "1.10", items: []),
        WhatsNew.Release(version: "1.4", items: []),
        WhatsNew.Release(version: "1.2", items: []),
    ]

    private final class Box {
        var value: String?
    }

    private func store(_ box: Box) -> WhatsNew.Store {
        WhatsNew.Store(
            load: { box.value },
            save: { box.value = $0 }
        )
    }

    func testNewVersionShowsItsReleaseAndStoresMarker() {
        let outcome = WhatsNew.Schedule.decide(
            appVersion: "1.4",
            lastSeen: "1.3",
            onboardingShownAtLaunch: false,
            releases: releases
        )
        XCTAssertEqual(outcome.release?.version, "1.4")
        XCTAssertEqual(outcome.marker, "1.4")
    }

    func testSameVersionShowsNothing() {
        let outcome = WhatsNew.Schedule.decide(
            appVersion: "1.4",
            lastSeen: "1.4",
            onboardingShownAtLaunch: false,
            releases: releases
        )
        XCTAssertNil(outcome.release)
        XCTAssertNil(outcome.marker)
    }

    func testVersionWithoutNewsStoresMarkerAndShowsNothing() {
        let outcome = WhatsNew.Schedule.decide(
            appVersion: "1.5",
            lastSeen: "1.4",
            onboardingShownAtLaunch: false,
            releases: releases
        )
        XCTAssertNil(outcome.release)
        XCTAssertEqual(outcome.marker, "1.5")
    }

    func testOnboardingLaunchNeverShowsAndStoresVersion() {
        let outcome = WhatsNew.Schedule.decide(
            appVersion: "1.4",
            lastSeen: "1.3",
            onboardingShownAtLaunch: true,
            releases: releases
        )
        XCTAssertNil(outcome.release)
        XCTAssertEqual(outcome.marker, "1.4")
    }

    func testExistingInstallWithoutMarkerShows() {
        let outcome = WhatsNew.Schedule.decide(
            appVersion: "1.4",
            lastSeen: nil,
            onboardingShownAtLaunch: false,
            releases: releases
        )
        XCTAssertEqual(outcome.release?.version, "1.4")
    }

    func testFreshInstallStoresRunningVersion() {
        let box = Box()
        WhatsNew.recordLaunch(
            isFreshInstall: true,
            resets: false,
            appVersion: "1.4",
            store: store(box)
        )
        XCTAssertEqual(box.value, "1.4")
    }

    func testExistingInstallRecordsNothingAtLaunch() {
        let box = Box()
        WhatsNew.recordLaunch(
            isFreshInstall: false,
            resets: false,
            appVersion: "1.4",
            store: store(box)
        )
        XCTAssertNil(box.value)
    }

    func testResetForgetsMarker() {
        let box = Box()
        box.value = "1.4"
        WhatsNew.recordLaunch(
            isFreshInstall: true,
            resets: true,
            appVersion: "1.4",
            store: store(box)
        )
        XCTAssertNil(box.value)
    }

    func testPresenterShowsOnceThenNeverForTheSameVersion() {
        let box = Box()
        box.value = "1.3"
        let presenter = WhatsNew.Presenter(store: store(box))
        presenter.start(
            isEnabled: true,
            onboardingShownAtLaunch: false,
            appVersion: "1.4",
            releases: releases
        )
        XCTAssertEqual(presenter.showing?.version, "1.4")
        XCTAssertEqual(box.value, "1.4")
        presenter.dismiss()
        let next = WhatsNew.Presenter(store: store(box))
        next.start(
            isEnabled: true,
            onboardingShownAtLaunch: false,
            appVersion: "1.4",
            releases: releases
        )
        XCTAssertNil(next.showing)
    }

    func testDisabledPresenterShowsNothingAndStoresNothing() {
        let box = Box()
        box.value = "1.3"
        let presenter = WhatsNew.Presenter(store: store(box))
        presenter.start(
            isEnabled: false,
            onboardingShownAtLaunch: false,
            appVersion: "1.4",
            releases: releases
        )
        XCTAssertNil(presenter.showing)
        XCTAssertEqual(box.value, "1.3")
    }

    func testHistoryIsNewestFirstAndStopsAtRunningVersion() {
        let history = WhatsNew.history(
            appVersion: "1.4",
            releases: releases
        )
        XCTAssertEqual(history.map(\.version), ["1.4", "1.2"])
    }

    func testHistoryComparesVersionsNumerically() {
        let history = WhatsNew.history(
            appVersion: "1.10",
            releases: releases
        )
        XCTAssertEqual(history.map(\.version), ["1.10", "1.4", "1.2"])
    }

    func testMockedLaunchSkipsUnlessOverridden() {
        XCTAssertFalse(WhatsNew.isEnabled(override: nil, hasMockScenario: true))
        XCTAssertTrue(WhatsNew.isEnabled(override: true, hasMockScenario: true))
        XCTAssertTrue(WhatsNew.isEnabled(override: nil, hasMockScenario: false))
    }
}
