//
//  NetworkLogTests.swift
//  TribunerosTests
//

import os
import XCTest
@testable import Tribuneros

final class NetworkLogTests: XCTestCase {
    private var lines: [(level: OSLogType, message: String)] = []
    private let originalOutput = AppLogger.output

    override func setUp() {
        super.setUp()
        lines = []
        AppLogger.output = { [unowned self] _, level, message in
            lines.append((level, message))
        }
    }

    override func tearDown() {
        AppLogger.output = originalOutput
        super.tearDown()
    }

    private func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .file
        )
    }

    func testJsonSummaryHasSourceSizeAndDuration() throws {
        let object: [String: Any] = ["b": 1, "a": "x"]
        let bytes = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        ).count

        let result = NetworkLog.jsonLines(
            "cx/standings",
            source: .server,
            object: object,
            duration: 0.143
        )

        XCTAssertEqual(result[0].0, .default)
        XCTAssertEqual(result[0].1, "[NETWORK] - cx/standings - server · \(size(bytes)) · 143 ms")
    }

    func testCacheSourceIsMarked() {
        let result = NetworkLog.jsonLines(
            "cxRiders/abc",
            source: .cache,
            object: ["a": 1],
            duration: 0.002
        )

        XCTAssertTrue(result[0].1.hasPrefix("[NETWORK] - cxRiders/abc - cache · "))
        XCTAssertTrue(result[0].1.hasSuffix(" · 2 ms"))
    }

    func testMissingDocumentLogsOneSummaryWithoutBody() {
        let result = NetworkLog.jsonLines(
            "cx/calendar",
            source: .server,
            object: nil,
            duration: 0.05
        )

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].0, .default)
        XCTAssertEqual(result[0].1, "[NETWORK] - cx/calendar - server · missing · 50 ms")
    }

    func testBodyIsSortedPrettyJSONOnDebugLines() {
        let result = NetworkLog.jsonLines(
            "cx/homepage",
            source: .server,
            object: ["b": 1, "a": 2],
            duration: 0
        )

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[1].0, .debug)
        XCTAssertEqual(
            result[1].1,
            "[NETWORK] - cx/homepage - (1/1) {\n  \"a\" : 2,\n  \"b\" : 1\n}"
        )
    }

    func testLargeBodyIsNumberedChunksThatRebuildIt() throws {
        let object: [String: Any] = [
            "rows": (0..<400).map { ["name": "Rider number \($0)", "points": $0] }
        ]
        let pretty = try String(
            decoding: JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            as: UTF8.self
        )

        let result = NetworkLog.jsonLines(
            "cx/standings",
            source: .server,
            object: object,
            duration: 0
        )
        let body = Array(result.dropFirst())

        XCTAssertGreaterThan(body.count, 1)
        XCTAssertTrue(body.allSatisfy { $0.0 == .debug })
        var rebuilt: [String] = []
        for (index, entry) in body.enumerated() {
            let prefix = "[NETWORK] - cx/standings - (\(index + 1)/\(body.count)) "
            XCTAssertTrue(entry.1.hasPrefix(prefix))
            let part = String(entry.1.dropFirst(prefix.count))
            XCTAssertLessThanOrEqual(part.utf8.count, NetworkLog.chunkBytes)
            rebuilt.append(part)
        }
        XCTAssertEqual(rebuilt.joined(separator: "\n"), pretty)
    }

    func testSingleLongLineIsSplitByCharacters() {
        let text = String(repeating: "é", count: 1000)

        let parts = NetworkLog.chunks(
            text,
            limit: 800
        )

        XCTAssertGreaterThan(parts.count, 1)
        XCTAssertTrue(parts.allSatisfy { $0.utf8.count <= 800 })
        XCTAssertEqual(parts.joined(), text)
    }

    func testPageSummaryIsDefaultBelow400() {
        NetworkLog.page(
            URL(string: "https://example.com/race"),
            status: 200,
            bytes: 524_288,
            duration: 0.83
        )

        XCTAssertEqual(lines.map(\.level), [.default])
        XCTAssertEqual(lines[0].message, "[NETWORK] - https://example.com/race - status 200 · \(size(524_288)) · 830 ms")
    }

    func testPageClientAndServerErrorsLogAtError() {
        for status in [404, 503] {
            NetworkLog.page(
                URL(string: "https://example.com"),
                status: status,
                bytes: 0,
                duration: 0
            )
        }

        XCTAssertEqual(lines.map(\.level), [.error, .error])
    }

    func testFailureLogsAtErrorWithReasonAndDuration() {
        NetworkLog.failure(
            "remote-config",
            error: URLError(.notConnectedToInternet),
            duration: 0.143
        )

        XCTAssertEqual(lines.map(\.level), [.error])
        XCTAssertTrue(lines[0].message.hasPrefix("[NETWORK] - remote-config - failed: "))
        XCTAssertTrue(lines[0].message.hasSuffix(" · 143 ms"))
    }

    func testJsonWritesSummaryThenBodyThroughTheLogger() {
        NetworkLog.json(
            "cx/homepage",
            source: .cache,
            object: ["a": 1],
            duration: 0.01
        )

        XCTAssertEqual(lines.map(\.level), [.default, .debug])
        XCTAssertTrue(lines.allSatisfy { $0.message.hasPrefix("[NETWORK] - cx/homepage - ") })
    }
}
