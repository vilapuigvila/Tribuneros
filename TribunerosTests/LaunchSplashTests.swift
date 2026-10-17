//
//  LaunchSplashTests.swift
//  TribunerosTests
//

import SwiftUI
import XCTest
@testable import Tribuneros

final class LaunchSplashTests: XCTestCase {
    func testShownWithoutMocksAndSkippedWithMocks() {
        XCTAssertTrue(LaunchSplash.isEnabled(override: nil, hasMockScenario: false))
        XCTAssertFalse(LaunchSplash.isEnabled(override: nil, hasMockScenario: true))
        XCTAssertFalse(LaunchSplash.isEnabled(override: nil, hasMockScenario: false, isFreshInstall: true))
    }

    func testOverrideWinsOverMockScenario() {
        XCTAssertTrue(LaunchSplash.isEnabled(override: true, hasMockScenario: true))
        XCTAssertFalse(LaunchSplash.isEnabled(override: false, hasMockScenario: false))
    }

    func testDurations() {
        XCTAssertEqual(LaunchSplash.minimumDuration, .seconds(3))
        XCTAssertEqual(LaunchSplash.maximumDuration, .seconds(8))
    }

    // MARK: - Closing rule (0.1 s stands for 3 s, 0.4 s for the request's 5 s, 1 s for 8 s)

    private let minimum: Duration = .milliseconds(100)
    private let maximum: Duration = .seconds(1)

    private func elapsed(request: @escaping @Sendable () async throws -> Void) async -> Duration {
        await ContinuousClock().measure {
            await LaunchSplash.waitToClose(
                minimum: minimum,
                maximum: maximum,
                request: request
            )
        }
    }

    func testRequestFinishingEarlyClosesAtTheMinimum() async {
        let time = await elapsed { }
        XCTAssertGreaterThanOrEqual(time, minimum)
        XCTAssertLessThan(time, .milliseconds(350))
    }

    func testRequestFinishingAfterTheMinimumClosesWhenItEnds() async {
        let time = await elapsed { try await Task.sleep(for: .milliseconds(400)) }
        XCTAssertGreaterThanOrEqual(time, .milliseconds(400))
        XCTAssertLessThan(time, .milliseconds(900))
    }

    func testRequestThatNeverEndsClosesAtTheMaximumAndKeepsRunning() async {
        let finished = Flag()
        let time = await elapsed {
            try await Task.sleep(for: .seconds(2))
            finished.set()
        }
        XCTAssertGreaterThanOrEqual(time, maximum)
        XCTAssertLessThan(time, .milliseconds(1800))
        XCTAssertFalse(finished.value)
    }

    func testFailureCountsAsFinished() async {
        struct Failure: Error {}
        let time = await elapsed { throw Failure() }
        XCTAssertGreaterThanOrEqual(time, minimum)
        XCTAssertLessThan(time, .milliseconds(350))
    }

    func testCancellingTheWaitReturnsAtOnce() async {
        let task = Task {
            await LaunchSplash.waitToClose(
                minimum: .seconds(30),
                maximum: .seconds(60),
                request: { try await Task.sleep(for: .seconds(60)) }
            )
        }
        task.cancel()
        let time = await ContinuousClock().measure { await task.value }
        XCTAssertLessThan(time, .seconds(2))
    }

    func testWithoutAHostTheSplashCountsAsFinished() {
        XCTAssertTrue(EnvironmentValues().isLaunchSplashFinished)
    }

    // MARK: - Request

    func testMockedLaunchDoesNotFetch() async throws {
        let fetched = Flag()
        try await LaunchSplash.warmHomepage(
            hasMockScenario: true,
            fetch: { fetched.set() }
        )
        XCTAssertFalse(fetched.value)
    }

    func testRealLaunchFetchesAndPropagatesFailure() async {
        struct Failure: Error {}
        let fetched = Flag()
        try? await LaunchSplash.warmHomepage(
            hasMockScenario: false,
            fetch: { fetched.set() }
        )
        XCTAssertTrue(fetched.value)
        do {
            try await LaunchSplash.warmHomepage(
                hasMockScenario: false,
                fetch: { throw Failure() }
            )
            XCTFail("expected the failure")
        } catch {
            XCTAssertTrue(error is Failure)
        }
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

private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false

    var value: Bool {
        lock.withLock { flag }
    }

    func set() {
        lock.withLock { flag = true }
    }
}
