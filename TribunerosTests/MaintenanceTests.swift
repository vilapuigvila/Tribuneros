//
//  MaintenanceTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class MaintenanceTests: XCTestCase {
    func testRemoteValueDecidesWithoutOverride() {
        XCTAssertTrue(Maintenance.isActive(remoteValue: true, override: nil))
        XCTAssertFalse(Maintenance.isActive(remoteValue: false, override: nil))
    }

    func testDefaultKeyIsFalse() {
        XCTAssertFalse(Service.cachedUnderMaintenance())
    }

    #if DEBUG
    func testDebugOverrideWinsOverRemoteValue() {
        XCTAssertTrue(Maintenance.isActive(remoteValue: false, override: true))
        XCTAssertFalse(Maintenance.isActive(remoteValue: true, override: false))
        XCTAssertEqual(Maintenance.debugOverride(environment: ["CT_MAINTENANCE": "1"], launchValue: nil), true)
        XCTAssertEqual(Maintenance.debugOverride(environment: [:], launchValue: "off"), false)
        XCTAssertNil(Maintenance.debugOverride(environment: [:], launchValue: nil))
    }
    #endif
}
