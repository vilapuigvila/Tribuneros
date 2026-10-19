//
//  LaunchTabTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class LaunchTabTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func tab(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Tab {
        let date = calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour)
        )!
        return Tab.launchTab(on: date, calendar: calendar)
    }

    func testBeforeTheWindowOpensIsTodayRaces() {
        XCTAssertEqual(tab(2026, 10, 18, hour: 23), .home)
    }

    func testWindowOpensOn19October() {
        XCTAssertEqual(tab(2026, 10, 19, hour: 0), .cxZone)
    }

    func testWindowCrossesTheNewYear() {
        XCTAssertEqual(tab(2026, 12, 31), .cxZone)
        XCTAssertEqual(tab(2027, 1, 1), .cxZone)
    }

    func testWindowClosesAfter31January() {
        XCTAssertEqual(tab(2027, 1, 31, hour: 23), .cxZone)
        XCTAssertEqual(tab(2027, 2, 1, hour: 0), .home)
    }

    func testMidSummerIsTodayRaces() {
        XCTAssertEqual(tab(2026, 7, 15), .home)
    }

    func testLaunchDateOverrideParsesEnvironmentThenArgument() {
        let fromEnv = Tab.launchDateOverride(
            environment: ["LAUNCH_DATE": "2026-11-05"],
            launchValue: "2026-07-01",
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.month, from: fromEnv!), 11)
        XCTAssertNil(Tab.launchDateOverride(environment: [:], launchValue: nil, calendar: calendar))
        XCTAssertNil(Tab.launchDateOverride(environment: ["LAUNCH_DATE": "nope"], launchValue: nil, calendar: calendar))
    }
}
