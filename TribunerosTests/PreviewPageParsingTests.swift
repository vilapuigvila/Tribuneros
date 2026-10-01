//
//  PreviewPageParsingTests.swift
//  TribunerosTests
//
//  Pins the pre-race state of a PCS LiveStats page (saved in pcs_preview.html).
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class PreviewPageParsingTests: XCTestCase {
    private func loadPage() throws -> DTO.PreviewPage {
        guard let url = Bundle(for: type(of: self)).url(forResource: "pcs_preview", withExtension: "html") else {
            XCTFail("Missing pcs_preview.html fixture in the test bundle")
            throw XCTSkip()
        }
        let html = try String(contentsOf: url, encoding: .utf8)
        let document = try SwiftSoup.parse(html)
        return try XCTUnwrap(Service.parsePreviewPage(document))
    }

    func testParsesRouteAndTimes() throws {
        let page = try loadPage()

        XCTAssertEqual(page.stage, "Stage 6")
        XCTAssertEqual(page.from, "Pandan Indah")
        XCTAssertEqual(page.to, "Rembau")
        XCTAssertEqual(page.distance, "121.3km")
        XCTAssertEqual(page.start, "02/10 09:12")
        XCTAssertEqual(page.startCET, "03:12")
    }

    func testParsesKeypoints() throws {
        let page = try loadPage()

        XCTAssertGreaterThan(page.keypoints.count, 1)
        XCTAssertEqual(
            page.keypoints.first,
            DTO.PreviewPage.Keypoint(
                km: "5.1",
                type: "climb",
                name: "Ampang (3.4 km à 4%)"
            )
        )
        XCTAssertTrue(page.keypoints.contains { $0.type == "sprint" })
    }

    func testParsesFactsAndDropsPromo() throws {
        let page = try loadPage()

        XCTAssertFalse(page.facts.isEmpty)
        XCTAssertTrue(page.facts.contains { $0.text.contains("neutralized start is scheduled at 09:00") })
        XCTAssertFalse(page.facts.contains { $0.text.contains("PCS game") })
        XCTAssertFalse(page.facts.contains { $0.text.hasPrefix("Welcome at the") })
        XCTAssertTrue(page.facts.contains { !$0.rows.isEmpty }, "Expected at least one fact with a table")
    }

    func testPageWithoutMarkersParsesToNil() throws {
        let document = try SwiftSoup.parse("<html><body><h1>Nothing here</h1></body></html>")

        XCTAssertNil(Service.parsePreviewPage(document))
    }
}
