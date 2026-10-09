//
//  SpoilerHintTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class SpoilerHintTests: XCTestCase {
    private let first = Date(timeIntervalSince1970: 1_800_000_000)
    private let hour: TimeInterval = 3600

    func testTextAsksForALongPress() {
        XCTAssertEqual(
            HomeRaces.SpoilerHint.text,
            "Press and hold a result to show or hide spoilers"
        )
    }

    func testFirstLaunchShows() {
        XCTAssertTrue(
            HomeRaces.SpoilerHint.shouldShow(
                now: first,
                firstShown: nil,
                count: 0
            )
        )
    }

    func testLessThan48HoursAfterFirstDoesNotShow() {
        XCTAssertFalse(
            HomeRaces.SpoilerHint.shouldShow(
                now: first.addingTimeInterval(47 * hour),
                firstShown: first,
                count: 1
            )
        )
    }

    func testAfter48HoursWithOneShowingShows() {
        XCTAssertTrue(
            HomeRaces.SpoilerHint.shouldShow(
                now: first.addingTimeInterval(48 * hour),
                firstShown: first,
                count: 1
            )
        )
    }

    func testTwoShowingsNeverShowAgain() {
        XCTAssertFalse(
            HomeRaces.SpoilerHint.shouldShow(
                now: first.addingTimeInterval(500 * hour),
                firstShown: first,
                count: 2
            )
        )
    }
}
