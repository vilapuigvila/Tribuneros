import Alfy
import XCTest
@testable import Tribuneros

final class HomepageTTLTests: XCTestCase {
    private func calendar(_ zone: String = "Europe/Madrid") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    private func ttl(
        _ hour: Int,
        _ minute: Int = 0,
        calendar: Calendar
    ) -> TimeInterval {
        let now = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 11,
                day: 18,
                hour: hour,
                minute: minute
            )
        )!
        return Service.homepageTTL(
            now: now,
            calendar: calendar
        ).seconds
    }

    func testInsideEachWindow() {
        let calendar = calendar()
        XCTAssertEqual(ttl(0, 30, calendar: calendar), 5.5 * 3600)
        XCTAssertEqual(ttl(6, 30, calendar: calendar), 2 * 3600)
        XCTAssertEqual(ttl(10, 15, calendar: calendar), 30 * 60)
        XCTAssertEqual(ttl(14, 5, calendar: calendar), 15 * 60)
        XCTAssertEqual(ttl(20, 10, calendar: calendar), 30 * 60)
        XCTAssertEqual(ttl(22, 10, calendar: calendar), 3600)
    }

    func testWindowStartBoundaries() {
        let calendar = calendar()
        XCTAssertEqual(ttl(0, calendar: calendar), 6 * 3600)
        XCTAssertEqual(ttl(6, calendar: calendar), 2 * 3600)
        XCTAssertEqual(ttl(10, calendar: calendar), 30 * 60)
        XCTAssertEqual(ttl(14, calendar: calendar), 15 * 60)
        XCTAssertEqual(ttl(20, calendar: calendar), 30 * 60)
        XCTAssertEqual(ttl(22, calendar: calendar), 3600)
    }

    func testCappedAtWindowEnd() {
        XCTAssertEqual(ttl(5, 30, calendar: calendar()), 30 * 60)
        XCTAssertEqual(ttl(23, 59, calendar: calendar()), 60)
    }

    func testNonUTCTimeZone() {
        let calendar = calendar("America/New_York")
        XCTAssertEqual(ttl(11, calendar: calendar), 30 * 60)
        XCTAssertEqual(ttl(21, 45, calendar: calendar), 15 * 60)
    }
}
