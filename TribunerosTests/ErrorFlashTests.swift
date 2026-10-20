//
//  ErrorFlashTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class ErrorFlashTests: XCTestCase {
    func testTotalDurationIsAboutTwoAndAHalfSeconds() {
        XCTAssertEqual(
            ErrorFlash.totalDuration,
            2.5,
            accuracy: 0.01
        )
    }

    func testPhasesFollowTheTimeline() {
        XCTAssertEqual(ErrorFlash.phase(at: 0), .entering)
        XCTAssertEqual(ErrorFlash.phase(at: ErrorFlash.enterDuration), .holding)
        XCTAssertEqual(ErrorFlash.phase(at: ErrorFlash.enterDuration + 1), .holding)
        XCTAssertEqual(ErrorFlash.phase(at: ErrorFlash.enterDuration + ErrorFlash.holdDuration), .leaving)
        XCTAssertEqual(ErrorFlash.phase(at: ErrorFlash.totalDuration), .gone)
        XCTAssertEqual(ErrorFlash.phase(at: 10), .gone)
    }

    func testOnlyEnteringAndHoldingAreShown() {
        XCTAssertTrue(ErrorFlash.isShown(.entering))
        XCTAssertTrue(ErrorFlash.isShown(.holding))
        XCTAssertFalse(ErrorFlash.isShown(.leaving))
        XCTAssertFalse(ErrorFlash.isShown(.gone))
    }

    func testReduceMotionNeverSlides() {
        XCTAssertEqual(ErrorFlash.yOffset(shown: false, reduceMotion: true), 0)
        XCTAssertEqual(ErrorFlash.yOffset(shown: true, reduceMotion: true), 0)
        XCTAssertEqual(ErrorFlash.yOffset(shown: true, reduceMotion: false), 0)
        XCTAssertLessThan(ErrorFlash.yOffset(shown: false, reduceMotion: false), 0)
    }
}

final class RaceInfoBlankTests: XCTestCase {
    private func info(
        title: String = "",
        date: String = "",
        distance: String = "",
        classification: String = ""
    ) -> DTO.RaceDetailInfo {
        DTO.RaceDetailInfo(
            title: title,
            date: date,
            startTime: "",
            classification: classification,
            category: "",
            distance: distance,
            departure: "",
            arrival: "",
            verticalMeters: "",
            profileURL: nil
        )
    }

    func testEmptyTitleAndNoRowsIsBlank() {
        XCTAssertTrue(info().isBlank)
    }

    func testOnlyTagsStillCountsAsBlank() {
        XCTAssertTrue(info(classification: "2.1").isBlank)
    }

    func testATitleIsNotBlank() {
        XCTAssertFalse(info(title: "Tour").isBlank)
    }

    func testAnInfoRowIsNotBlank() {
        XCTAssertFalse(info(date: "01 October 2026").isBlank)
        XCTAssertFalse(info(distance: "134 km").isBlank)
    }

    func testMockRaceInfoSwitch() {
        typealias Mock = Service.MockRaceInfo
        XCTAssertNil(Mock.resolve(environment: [:], launchValue: nil))
        XCTAssertEqual(Mock.resolve(environment: [:], launchValue: "error"), .error)
        XCTAssertEqual(Mock.resolve(environment: [:], launchValue: "blank"), .blank)
        XCTAssertNil(Mock.resolve(environment: [:], launchValue: "nope"))
        XCTAssertEqual(Mock.resolve(environment: ["MOCK_RACE_INFO": "blank"], launchValue: "error"), .blank)
    }
}
