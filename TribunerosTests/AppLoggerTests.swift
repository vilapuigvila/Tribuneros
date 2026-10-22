//
//  AppLoggerTests.swift
//  TribunerosTests
//

import os
import XCTest
@testable import Tribuneros

final class AppLoggerTests: XCTestCase {
    private var lines: [(category: String, level: OSLogType, message: String)] = []
    private let originalOutput = AppLogger.output

    override func setUp() {
        super.setUp()
        lines = []
        AppLogger.output = { [unowned self] category, level, message in
            lines.append((category, level, message))
        }
    }

    override func tearDown() {
        AppLogger.output = originalOutput
        super.tearDown()
    }

    func testLineReachesOutputWithCategoryAndLevel() {
        AppLogger.network.error("boom")

        XCTAssertEqual(lines.map(\.category), ["Network"])
        XCTAssertEqual(lines.map(\.level), [.error])
        XCTAssertEqual(lines.map(\.message), ["boom"])
    }

    func testEachCallMapsToItsLevel() {
        AppLogger.navigation.debug("a")
        AppLogger.images.log("b")
        AppLogger.preferences.error("c")

        XCTAssertEqual(lines.map(\.category), ["Navigation", "Images", "Preferences"])
        XCTAssertEqual(lines.map(\.level), [.debug, .default, .error])
    }
}
