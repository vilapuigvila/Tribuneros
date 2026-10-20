//
//  BroadcasterLogoTests.swift
//  TribunerosTests
//

import XCTest
import UIKit
@testable import Tribuneros

final class BroadcasterLogoTests: XCTestCase {
    private typealias Logo = HomeRaces.WhereToWatch.BroadcasterLogo
    private typealias Coverage = HomeRaces.WhereToWatch.Coverage

    func testAKnownChannelHasItsLogo() {
        XCTAssertEqual(Logo.assetName(for: "FloBikes"), "broadcaster-flobikes")
        XCTAssertEqual(Logo.assetName(for: "HBO Max"), "broadcaster-max")
        XCTAssertEqual(Logo.assetName(for: "RAI Sport"), "broadcaster-rai")
    }

    func testMatchingIgnoresCaseAccentsAndPunctuation() {
        XCTAssertEqual(Logo.assetName(for: "L'Équipe"), "broadcaster-lequipe")
        XCTAssertEqual(Logo.assetName(for: "l’equipe"), "broadcaster-lequipe")
        XCTAssertEqual(Logo.assetName(for: "FRANCE.TV"), "broadcaster-francetv")
        XCTAssertEqual(Logo.assetName(for: "sporza"), "broadcaster-sporza")
    }

    func testAnUnknownChannelHasNoLogo() {
        XCTAssertNil(Logo.assetName(for: "VRT"))
        XCTAssertNil(Logo.assetName(for: ""))
    }

    func testCombinedNamesSplitIntoOneTilePerChannel() {
        XCTAssertEqual(
            Logo.tiles(in: "Sporza / VRT"),
            [
                Logo.Tile(name: "Sporza", asset: "broadcaster-sporza"),
                Logo.Tile(name: "VRT", asset: nil)
            ]
        )
        XCTAssertEqual(
            Logo.tiles(in: "Eurosport / HBO Max").compactMap(\.asset),
            ["broadcaster-eurosport", "broadcaster-max"]
        )
        XCTAssertEqual(Logo.tiles(in: "FloBikes").count, 1)
    }

    func testEveryMappedAssetIsBundled() {
        for name in Logo.assetNames {
            XCTAssertNotNil(
                UIImage(named: name, in: .main, compatibleWith: nil),
                name
            )
        }
        XCTAssertEqual(Logo.assetNames.count, 38)
    }

    func testCoverageCarriesTheBroadcastersAndTheirLogos() {
        let coverage = Coverage.channels(["Eurosport / HBO Max", "FloBikes", "VRT"])

        XCTAssertEqual(coverage.summary, "Eurosport / HBO Max · FloBikes · VRT")
        XCTAssertEqual(
            coverage.tiles.map(\.name),
            ["Eurosport", "HBO Max", "FloBikes", "VRT"]
        )
        XCTAssertEqual(
            coverage.tiles.map(\.asset),
            ["broadcaster-eurosport", "broadcaster-max", "broadcaster-flobikes", nil]
        )
    }

    func testCoverageTilesDropRepeatedChannels() {
        let coverage = Coverage.channels(["Sporza / VRT", "Sporza"])

        XCTAssertEqual(coverage.tiles.map(\.name), ["Sporza", "VRT"])
    }

    func testCoverageWithoutChannelsHasNoTiles() {
        XCTAssertTrue(Coverage.noBroadcast.tiles.isEmpty)
        XCTAssertTrue(Coverage.notListed.tiles.isEmpty)
    }
}
