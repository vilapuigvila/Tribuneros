//
//  PushPermissionTests.swift
//  TribunerosTests
//

import XCTest
import UserNotifications
@testable import Tribuneros

final class PushPermissionTests: XCTestCase {
    private func shouldAsk(
        status: UNAuthorizationStatus = .notDetermined,
        splashFinished: Bool = true,
        onboardingShowing: Bool = false,
        mocked: Bool = false,
        flag: Bool = false
    ) -> Bool {
        PushPermission.shouldAsk(
            status: status,
            isLaunchSplashFinished: splashFinished,
            isOnboardingShowing: onboardingShowing,
            isMockedLaunch: mocked,
            isPromptFlagOn: flag
        )
    }

    func testAsksOnceOnboardingHasClosed() {
        XCTAssertTrue(shouldAsk())
    }

    func testWaitsWhileOnboardingShows() {
        XCTAssertFalse(shouldAsk(onboardingShowing: true))
    }

    func testWaitsForLaunchSplash() {
        XCTAssertFalse(shouldAsk(splashFinished: false))
    }

    func testNeverAsksAgainOnceDecided() {
        for status in [UNAuthorizationStatus.authorized, .denied, .provisional, .ephemeral] {
            XCTAssertFalse(
                shouldAsk(status: status),
                "status \(status.rawValue)"
            )
        }
    }

    func testMockedLaunchSkipsUnlessFlagOn() {
        XCTAssertFalse(shouldAsk(mocked: true))
        XCTAssertTrue(
            shouldAsk(
                mocked: true,
                flag: true
            )
        )
    }

    func testFlagDoesNotOverrideOnboardingOrStatus() {
        XCTAssertFalse(
            shouldAsk(
                onboardingShowing: true,
                mocked: true,
                flag: true
            )
        )
        XCTAssertFalse(
            shouldAsk(
                status: .denied,
                mocked: true,
                flag: true
            )
        )
    }
}
