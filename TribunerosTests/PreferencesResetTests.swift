//
//  PreferencesResetTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class PreferencesResetTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: PreferencesReset.Store!
    private let suite = "PreferencesResetTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)
        store = .defaults(defaults)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func seedAppKeys() {
        for key in UserPreferencesKey.allCases {
            defaults.set(Data([1]), forKey: key.rawValue)
        }
    }

    private func appKeysCleared() -> Bool {
        UserPreferencesKey.allCases
            .filter { $0 != .preferencesResetVersion }
            .allSatisfy { defaults.object(forKey: $0.rawValue) == nil }
    }

    func testMissingMarkerClearsAppKeysAndStoresMarker() {
        seedAppKeys()
        defaults.removeObject(forKey: UserPreferencesKey.preferencesResetVersion.rawValue)
        XCTAssertTrue(PreferencesReset.run(store: store, currentVersion: 1))
        XCTAssertTrue(appKeysCleared())
        XCTAssertEqual(store.loadVersion(), 1)
    }

    func testLowerMarkerClears() {
        seedAppKeys()
        store.saveVersion(1)
        XCTAssertTrue(PreferencesReset.run(store: store, currentVersion: 2))
        XCTAssertTrue(appKeysCleared())
        XCTAssertEqual(store.loadVersion(), 2)
    }

    func testCurrentMarkerDoesNothing() {
        seedAppKeys()
        store.saveVersion(1)
        XCTAssertFalse(PreferencesReset.run(store: store, currentVersion: 1))
        XCTAssertFalse(appKeysCleared())
        XCTAssertEqual(store.loadVersion(), 1)
    }

    func testUnrelatedKeysSurvive() {
        defaults.set("cached", forKey: "firebase_remote_config_press")
        seedAppKeys()
        PreferencesReset.run(store: store, currentVersion: 1)
        XCTAssertEqual(defaults.string(forKey: "firebase_remote_config_press"), "cached")
    }

    func testBumpedConstantResetsAgainOnlyOnce() {
        PreferencesReset.run(store: store, currentVersion: 1)
        seedAppKeys()
        store.saveVersion(1)
        XCTAssertFalse(PreferencesReset.run(store: store, currentVersion: 1))
        XCTAssertTrue(PreferencesReset.run(store: store, currentVersion: 2))
        XCTAssertFalse(PreferencesReset.run(store: store, currentVersion: 2))
    }

    func testSimulatedUpdateForgetsMarker() {
        store.saveVersion(1)
        seedAppKeys()
        XCTAssertTrue(PreferencesReset.run(store: store, currentVersion: 1, simulatesUpdate: true))
        XCTAssertTrue(appKeysCleared())
    }

    func testEveryUserDefaultKeyIsCovered() {
        let covered = Set(UserPreferencesKey.allCases.map(\.rawValue))
        XCTAssertTrue(covered.contains("onboardingShownCount"))
        XCTAssertTrue(covered.contains("appLanguage"))
        XCTAssertTrue(covered.contains("spoilerHintShownCount"))
    }
}
