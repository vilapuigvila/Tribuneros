//
//  CxRunScheduleTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class CxRunScheduleTests: XCTestCase {
    private let runTimes = [(16, 30), (22, 30)]
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }

    private func date(
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 10,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func lastRun(at now: Date) -> Date? {
        Service.lastCxRun(
            before: now,
            runTimes: runTimes,
            calendar: calendar
        )
    }

    func testBeforeFirstRunOfTheDayUsesYesterdaysLastRun() {
        XCTAssertEqual(lastRun(at: date(17, 9, 0)), date(16, 22, 30))
    }

    func testBetweenRunsUsesTheEarlierOne() {
        XCTAssertEqual(lastRun(at: date(17, 18, 0)), date(17, 16, 30))
    }

    func testInsideTheGraceTheRunDoesNotCountYet() {
        XCTAssertEqual(lastRun(at: date(17, 16, 33)), date(16, 22, 30))
        XCTAssertEqual(lastRun(at: date(17, 16, 36)), date(17, 16, 30))
    }

    func testAfterMidnightUsesPreviousEvening() {
        XCTAssertEqual(lastRun(at: date(17, 0, 10)), date(16, 22, 30))
    }
}
