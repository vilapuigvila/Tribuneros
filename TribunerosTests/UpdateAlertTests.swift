//
//  UpdateAlertTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

@MainActor
final class UpdateAlertTests: XCTestCase {
    private let url = URL(string: "https://apps.apple.com/app/id1")!

    private func release(_ version: String) -> UpdateAlert.Release {
        UpdateAlert.Release(
            version: version,
            url: url
        )
    }

    private final class Box {
        var value: String?
    }

    private func store(_ box: Box) -> UpdateAlert.Store {
        UpdateAlert.Store(
            load: { box.value },
            save: { box.value = $0 }
        )
    }

    func testNewerStoreVersionShows() {
        XCTAssertEqual(
            UpdateAlert.decide(
                appVersion: "1.3",
                lastAlerted: nil,
                available: release("1.4")
            )?.version,
            "1.4"
        )
    }

    func testVersionsCompareNumerically() {
        XCTAssertNotNil(
            UpdateAlert.decide(
                appVersion: "1.9",
                lastAlerted: nil,
                available: release("1.10")
            )
        )
        XCTAssertNil(
            UpdateAlert.decide(
                appVersion: "1.10",
                lastAlerted: nil,
                available: release("1.9")
            )
        )
    }

    func testSameOrOlderStoreVersionShowsNothing() {
        XCTAssertNil(
            UpdateAlert.decide(
                appVersion: "1.4",
                lastAlerted: nil,
                available: release("1.4")
            )
        )
        XCTAssertNil(
            UpdateAlert.decide(
                appVersion: "1.5",
                lastAlerted: nil,
                available: release("1.4")
            )
        )
    }

    func testAlreadyAlertedVersionShowsNothing() {
        XCTAssertNil(
            UpdateAlert.decide(
                appVersion: "1.3",
                lastAlerted: "1.4",
                available: release("1.4")
            )
        )
    }

    func testNextStoreVersionAlertsAgain() {
        XCTAssertEqual(
            UpdateAlert.decide(
                appVersion: "1.3",
                lastAlerted: "1.4",
                available: release("1.5")
            )?.version,
            "1.5"
        )
    }

    func testNoLookupOrNoRunningVersionShowsNothing() {
        XCTAssertNil(
            UpdateAlert.decide(
                appVersion: "1.3",
                lastAlerted: nil,
                available: nil
            )
        )
        XCTAssertNil(
            UpdateAlert.decide(
                appVersion: "",
                lastAlerted: nil,
                available: release("1.4")
            )
        )
    }

    func testPresenterShowsOnceAndStoresTheVersion() async {
        let box = Box()
        let first = UpdateAlert.Presenter(store: store(box))
        await first.start(
            isEnabled: true,
            resets: false,
            appVersion: "1.3",
            fetch: { self.release("1.4") }
        )
        XCTAssertEqual(first.showing?.version, "1.4")
        XCTAssertEqual(box.value, "1.4")

        first.dismiss()
        let second = UpdateAlert.Presenter(store: store(box))
        await second.start(
            isEnabled: true,
            resets: false,
            appVersion: "1.3",
            fetch: { self.release("1.4") }
        )
        XCTAssertNil(second.showing)
    }

    func testPresenterRunsOncePerLaunch() async {
        let box = Box()
        let presenter = UpdateAlert.Presenter(store: store(box))
        await presenter.start(
            isEnabled: true,
            resets: false,
            appVersion: "1.3",
            fetch: { nil }
        )
        await presenter.start(
            isEnabled: true,
            resets: false,
            appVersion: "1.3",
            fetch: { self.release("1.4") }
        )
        XCTAssertNil(presenter.showing)
    }

    func testDisabledPresenterNeverFetches() async {
        let presenter = UpdateAlert.Presenter(store: store(Box()))
        var fetched = false
        await presenter.start(
            isEnabled: false,
            resets: false,
            appVersion: "1.3",
            fetch: {
                fetched = true
                return self.release("1.4")
            }
        )
        XCTAssertFalse(fetched)
        XCTAssertNil(presenter.showing)
    }

    func testResetForgetsTheAlertedVersion() async {
        let box = Box()
        box.value = "1.4"
        let presenter = UpdateAlert.Presenter(store: store(box))
        await presenter.start(
            isEnabled: true,
            resets: true,
            appVersion: "1.3",
            fetch: { self.release("1.4") }
        )
        XCTAssertEqual(presenter.showing?.version, "1.4")
    }

    func testMockedLaunchSkipsUnlessTurnedOn() {
        XCTAssertFalse(UpdateAlert.isEnabled(override: nil, hasMockScenario: true))
        XCTAssertTrue(UpdateAlert.isEnabled(override: true, hasMockScenario: true))
        XCTAssertTrue(UpdateAlert.isEnabled(override: nil, hasMockScenario: false))
    }

    // MARK: - Lookup -

    func testParsesTheLookupResult() throws {
        let json = """
        {"resultCount":1,"results":[{"version":"1.4","trackId":42,"trackViewUrl":"https://apps.apple.com/es/app/tribuneros/id42?uo=4"}]}
        """
        let parsed = try XCTUnwrap(Service.parseAppStoreLookup(Data(json.utf8)))
        XCTAssertEqual(parsed.version, "1.4")
        XCTAssertEqual(parsed.url.absoluteString, "https://apps.apple.com/es/app/tribuneros/id42?uo=4")
    }

    func testLookupWithoutLinkFallsBackToTheTrackId() throws {
        let json = #"{"resultCount":1,"results":[{"version":"1.4","trackId":42}]}"#
        let parsed = try XCTUnwrap(Service.parseAppStoreLookup(Data(json.utf8)))
        XCTAssertEqual(parsed.url.absoluteString, "https://apps.apple.com/app/id42")
    }

    func testLookupRejectsForeignLinks() {
        let json = #"{"resultCount":1,"results":[{"version":"1.4","trackViewUrl":"https://evil.example/x"}]}"#
        XCTAssertNil(Service.parseAppStoreLookup(Data(json.utf8)))
    }

    func testEmptyOrBrokenLookupGivesNil() {
        XCTAssertNil(Service.parseAppStoreLookup(Data(#"{"resultCount":0,"results":[]}"#.utf8)))
        XCTAssertNil(Service.parseAppStoreLookup(Data("not json".utf8)))
    }

    func testLookupURLCarriesBundleAndStorefront() {
        XCTAssertEqual(
            Service.appStoreLookupURL(
                bundleID: "com.pskmoons.Tribuneros",
                country: "es"
            )?.absoluteString,
            "https://itunes.apple.com/lookup?bundleId=com.pskmoons.Tribuneros&country=es"
        )
        XCTAssertEqual(
            Service.appStoreLookupURL(
                bundleID: "com.pskmoons.Tribuneros",
                country: nil
            )?.absoluteString,
            "https://itunes.apple.com/lookup?bundleId=com.pskmoons.Tribuneros"
        )
    }

    func testDebugVersionDefaultsOnlyOnMockedLaunches() {
        XCTAssertEqual(UpdateAlert.debugVersion(environment: [:], launchValue: nil, hasMockScenario: true), "9.9")
        XCTAssertNil(UpdateAlert.debugVersion(environment: [:], launchValue: nil, hasMockScenario: false))
        XCTAssertEqual(
            UpdateAlert.debugVersion(
                environment: ["UPDATE_ALERT_VERSION": "2.0"],
                launchValue: nil,
                hasMockScenario: false
            ),
            "2.0"
        )
    }
}
