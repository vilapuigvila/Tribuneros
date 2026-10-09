//
//  LaunchSplashTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class LaunchSplashTests: XCTestCase {
    func testShownWithoutMocksAndSkippedWithMocks() {
        XCTAssertTrue(LaunchSplash.isEnabled(override: nil, hasMockScenario: false))
        XCTAssertFalse(LaunchSplash.isEnabled(override: nil, hasMockScenario: true))
    }

    func testOverrideWinsOverMockScenario() {
        XCTAssertTrue(LaunchSplash.isEnabled(override: true, hasMockScenario: true))
        XCTAssertFalse(LaunchSplash.isEnabled(override: false, hasMockScenario: false))
    }

    func testBundledAssets() {
        let bundle = Bundle(for: LaunchJingle.self)
        XCTAssertNotNil(bundle.url(forResource: "launch_jingle", withExtension: "m4a"))
        XCTAssertNotNil(bundle.url(forResource: "launch_splash", withExtension: "json"))
    }

    #if DEBUG
    func testDebugOverride() {
        XCTAssertEqual(LaunchSplash.debugOverride(environment: ["LAUNCH_SPLASH": "1"], launchValue: nil), true)
        XCTAssertEqual(LaunchSplash.debugOverride(environment: [:], launchValue: "on"), true)
        XCTAssertEqual(LaunchSplash.debugOverride(environment: [:], launchValue: "off"), false)
        XCTAssertNil(LaunchSplash.debugOverride(environment: [:], launchValue: nil))
    }
    #endif
}
