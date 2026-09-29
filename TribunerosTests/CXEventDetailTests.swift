//
//  CXEventDetailTests.swift
//  TribunerosTests
//
//  Created by albert vila on 29/9/26.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class CXEventDetailTests: XCTestCase {

    // MARK: - Race series -

    func testSeriesIsInferredFromNameAndClass() {
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "UCI World Cup Antwerpen", raceClass: "CDM", country: "Belgium"), .worldCup)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Namur", raceClass: "CDM", country: "Belgium"), .worldCup)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Superprestige Ruddervoorde", raceClass: "C1", country: "Belgium"), .superprestige)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "X2O Badkamers Trofee - Koppenbergcross", raceClass: "C1", country: "Belgium"), .x2oTrofee)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Exact Cross Mol", raceClass: "C1", country: "Belgium"), .exactCross)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "UCI World Championships Liévin", raceClass: "CM", country: "France"), .championships)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Belgian National Championships", raceClass: "CN", country: "Belgium"), .championships)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Cyclocross Otegem", raceClass: "C2", country: "Belgium"), .otherBelgian)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Trek USCX #3 - Rochester Cyclocross", raceClass: "C1", country: "United States"), .others)
        XCTAssertEqual(CXRaces.RaceSeries.of(race: "Cross4Life Copenhagen", raceClass: "C2", country: nil), .others)
    }

    // MARK: - Race page parsing -

    func testRacePageParsesWinnersByYear() throws {
        let html = """
        <html>
          <head><meta name="description" content="Beach cyclocross in Middelkerke."></head>
          <body>
            <h1 class="main_title">Middelkerke</h1>
            <table>
              <tr><th>Year</th><th>Winner</th></tr>
              <tr class="r1_row">
                <td>2024</td>
                <td><img class="flag" src="/images/flag/32/Belgium.png"><a class="rurl" href="/rider/eli-iserbyt/">ISERBYT Eli</a></td>
                <td><a href="/race/17001/">Results</a></td>
              </tr>
              <tr class="r1_row">
                <td>03-01-2025</td>
                <td><img class="flag" src="/images/flag/32/Netherlands.png"><a class="rurl" href="/rider/mathieu-van-der-poel/">VAN DER POEL Mathieu</a></td>
                <td><a href="/race/middelkerke/">Race</a><a href="/race/18001/">Results</a></td>
              </tr>
            </table>
            <table>
              <tr class="r1_row"><td>1</td><td><a href="/rider/no-year/">NO YEAR Rider</a></td><td>27</td></tr>
            </table>
          </body>
        </html>
        """

        let page = try Service.parseCx24RacePage(SwiftSoup.parse(html))

        XCTAssertEqual(page.title, "Middelkerke")
        XCTAssertEqual(page.summary, "Beach cyclocross in Middelkerke.")
        XCTAssertEqual(page.pastWinners.map(\.year), ["2025", "2024"])
        XCTAssertEqual(page.pastWinners.first?.rider, "VAN DER POEL Mathieu")
        XCTAssertEqual(page.pastWinners.first?.resultsURL?.absoluteString, "https://cyclocross24.com/race/18001/")
        XCTAssertEqual(page.pastWinners.first?.riderURL?.absoluteString, "https://cyclocross24.com/rider/mathieu-van-der-poel/")
        XCTAssertEqual(page.pastWinners.first?.countryFlagURL?.absoluteString, "https://cyclocross24.com/images/flag/32/Netherlands.png")
    }

    func testRacePageWithoutEditionsIsEmpty() throws {
        let page = try Service.parseCx24RacePage(SwiftSoup.parse("<html><body><h1>Race</h1></body></html>"))

        XCTAssertEqual(page.title, "Race")
        XCTAssertTrue(page.summary.isEmpty)
        XCTAssertTrue(page.pastWinners.isEmpty)
    }

    // MARK: - Rider page parsing -

    func testRiderPageParsesAvatarFactsAndResults() throws {
        let html = """
        <html><body>
          <h1 class="main_title">Mathieu van der Poel</h1>
          <img class="rider-avatar__image" src="/images/rider/mathieu-van-der-poel-kL0.png">
          <dl><dt>Date of birth:</dt><dd>19 January 1995</dd></dl>
          <table>
            <tr><td>Team</td><td>Alpecin - Deceuninck</td></tr>
            <tr><td>1</td><td><a href="/rider/other-rider/">OTHER Rider</a></td></tr>
          </table>
          <table>
            <tr><th>Date</th><th>Race</th><th>Pos</th></tr>
            <tr><td>04-01-2026</td><td><a href="/race/18001/">X2O Trofee Middelkerke</a></td><td>1</td></tr>
            <tr><td>28-12-2025</td><td><a href="/race/17990/">UCI World Cup Dendermonde</a></td><td>2.</td></tr>
          </table>
        </body></html>
        """

        let page = try Service.parseCx24RiderPage(SwiftSoup.parse(html))

        XCTAssertEqual(page.name, "Mathieu van der Poel")
        XCTAssertEqual(page.avatarURL?.absoluteString, "https://cyclocross24.com/images/rider/mathieu-van-der-poel-kL0.png")
        XCTAssertEqual(page.facts.map(\.label), ["Date of birth", "Team"])
        XCTAssertEqual(page.facts.last?.value, "Alpecin - Deceuninck")
        XCTAssertEqual(page.results.map(\.position), ["1", "2"])
        XCTAssertEqual(page.results.first?.date, "04-01-2026")
        XCTAssertEqual(page.results.first?.race, "X2O Trofee Middelkerke")
        XCTAssertEqual(page.results.first?.raceURL?.absoluteString, "https://cyclocross24.com/race/18001/")
    }
}
