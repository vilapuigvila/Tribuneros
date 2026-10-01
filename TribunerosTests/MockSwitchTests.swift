//
//  MockSwitchTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class MockSwitchTests: XCTestCase {
    private typealias Scenario = HomeRaces.MockScenario

    func testNothingSetMeansNoScenario() {
        XCTAssertNil(
            Scenario.resolve(
                environment: [:],
                launchValue: nil
            )
        )
    }

    func testEachValidValueResolvesToItsScenario() {
        let all: [(String, Scenario)] = [
            ("live", .live),
            ("later", .later),
            ("one", .one),
            ("empty", .empty),
            ("stale", .stale),
            ("history", .history),
            ("previews", .previews)
        ]
        for (raw, scenario) in all {
            XCTAssertEqual(
                Scenario.resolve(
                    environment: ["MOCK_SCENARIO": raw],
                    launchValue: nil
                ),
                scenario
            )
            XCTAssertEqual(
                Scenario.resolve(
                    environment: [:],
                    launchValue: raw
                ),
                scenario
            )
        }
    }

    func testUnknownValueMeansNoScenario() {
        XCTAssertNil(
            Scenario.resolve(
                environment: ["MOCK_SCENARIO": "bogus"],
                launchValue: nil
            )
        )
        XCTAssertNil(
            Scenario.resolve(
                environment: [:],
                launchValue: "bogus"
            )
        )
    }

    func testEnvironmentWinsOverLaunchValue() {
        XCTAssertEqual(
            Scenario.resolve(
                environment: ["MOCK_SCENARIO": "one"],
                launchValue: "later"
            ),
            .one
        )
    }

    func testCourseDuJourFlagAloneDoesNotTurnOnMocks() {
        let environment = ["CT_COURSEDUJOUR_NATIVE": "on"]
        XCTAssertNil(
            Scenario.resolve(
                environment: environment,
                launchValue: nil
            )
        )
        XCTAssertEqual(
            Service.courseDuJourNativeOverride(
                environment: environment,
                launchValue: nil
            ),
            true
        )
    }
}
