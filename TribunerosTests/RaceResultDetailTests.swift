//
//  RaceResultDetailTests.swift
//  TribunerosTests
//
//  The race result screen: the result page parser (synthetic HTML only — no real PCS result
//  page could be captured when this was written, so re-check against one captured with
//  URLSession), the subtitle and Stage/GC routing built from the homepage's race data, the
//  time column, and the interactor/view model mapping.
//

import XCTest
import Combine
import SwiftSoup
@testable import Tribuneros

final class RaceResultDetailTests: XCTestCase {
    private typealias RaceResult = HomeRaces.RaceResult
    private typealias ViewModel = RaceResult.ViewModel<RaceResult.InteractorImpl>

    // MARK: - Fixtures -

    private func row(
        _ rank: String,
        rider: String,
        team: String,
        time: String
    ) -> String {
        """
        <tr><td>\(rank)</td><td>12</td>\
        <td><span class="flag be"></span> <a href="rider/\(rider.lowercased().replacingOccurrences(of: " ", with: "-"))">\(rider)</a></td>\
        <td>27</td><td><a href="team/\(team.lowercased().replacingOccurrences(of: " ", with: "-"))-2026">\(team)</a></td>\
        <td>100</td><td class="time ar">\(time)</td></tr>
        """
    }

    private func resultsTable(_ rows: [String]) -> String {
        """
        <table class="results"><thead><tr>\
        <th>Rnk</th><th>BIB</th><th>Rider</th><th>Age</th><th>Team</th><th>Pnt</th><th>Time</th>\
        </tr></thead><tbody>\(rows.joined())</tbody></table>
        """
    }

    private var stagePageHTML: String {
        var rows = [
            row("1", rider: "VAN DER POEL Mathieu", team: "Alpecin Premier Tech", time: "4:12:05<span class=\"hide\">4:12:05</span>"),
            row("2", rider: "GACHIGNARD Thomas", team: "TotalEnergies", time: ",,<span class=\"hide\">4:12:05</span>"),
            row("3", rider: "PIGANZOLI Davide", team: "Visma", time: "0:04<span class=\"hide\">4:12:09</span>")
        ]
        rows += (4...14).map { row("\($0)", rider: "RIDER \($0)", team: "Team \($0)", time: "0:\(10 + $0)") }
        let gcRows = [row("1", rider: "GC LEADER", team: "Team GC", time: "18:00:00")]
        return """
        <html><body>
        <div class="page-title"><h1>Skoda Tour de Luxembourg 2026</h1><div class="sub"><span>Stage 5</span> | Mersch › Luxembourg-Limpertsberg</div></div>
        <div class="resTab">\(resultsTable(rows))</div>
        <div class="resTab hide">\(resultsTable(gcRows))</div>
        <ul class="keyvalueList">
        <li><div class="title">Distance: </div><div class="value">177 km</div></li>
        <li><div class="title">Departure: </div><div class="value">Mersch</div></li>
        <li><div class="title">Arrival: </div><div class="value">Luxembourg-Limpertsberg</div></li>
        </ul>
        </body></html>
        """
    }

    private func parse(_ html: String) throws -> DTO.RaceResultPage {
        Service.parseRaceResultPage(try SwiftSoup.parse(html))
    }

    private func race(
        name: String = "Skoda Tour de Luxembourg (2.Pro)",
        details: String = "Stage 5 | Mersch - Luxembourg-Limpertsberg (177km)",
        path: String = "race/tour-de-luxembourg/2026/stage-5"
    ) -> HomeRaces.Representable.RaceFinished {
        HomeRaces.Representable.RaceFinished(
            race: name,
            raceDetails: details,
            winnerImgURL: nil,
            podium: [
                .init(position: "1", flag: nil, countryCode: "nl", name: "VAN DER POEL Mathieu", team: "#", time: "4:12:05"),
                .init(position: "2", flag: nil, countryCode: "fr", name: "GACHIGNARD Thomas", team: "#", time: "0:00"),
                .init(position: "3", flag: nil, countryCode: "it", name: "PIGANZOLI Davide", team: "#", time: "0:04")
            ],
            isCancel: false,
            raceURL: URL(string: "https://www.procyclingstats.com/" + path)
        )
    }

    private func descriptor(
        name: String = "Skoda Tour de Luxembourg (2.Pro)",
        details: String,
        path: String
    ) -> RaceResult.Descriptor {
        RaceResult.Descriptor(
            name: name,
            details: details,
            url: URL(string: "https://www.procyclingstats.com/" + path)
        )
    }

    // MARK: - Parser -

    func testStagePageReadsTheVisibleTableTopTen() throws {
        let page = try parse(stagePageHTML)

        XCTAssertEqual(page.rows.count, 10)
        XCTAssertEqual(
            page.rows.first,
            DTO.RaceResultPage.Row(
                position: "1",
                name: "VAN DER POEL Mathieu",
                team: "Alpecin Premier Tech",
                time: "4:12:05"
            )
        )
        XCTAssertEqual(page.rows[1].time, ",,", "the hidden absolute time must not leak into the gap")
        XCTAssertEqual(page.rows[2].time, "0:04")
        XCTAssertEqual(page.rows.last?.position, "10")
        XCTAssertFalse(page.rows.contains { $0.name == "GC LEADER" }, "the hidden GC tab is not this page's result")
    }

    func testStagePageReadsTheRouteFactsAndStage() throws {
        let page = try parse(stagePageHTML)

        XCTAssertEqual(page.stage, "Stage 5")
        XCTAssertEqual(page.from, "Mersch")
        XCTAssertEqual(page.to, "Luxembourg-Limpertsberg")
        XCTAssertEqual(page.distance, "177km")
    }

    func testGCPageWithItsOwnColumnsAndUnrankedRows() throws {
        let html = """
        <table class="results"><thead><tr>\
        <th>Rnk</th><th>Prev</th><th>▼▲</th><th>Rider</th><th>Team</th><th>Time</th>\
        </tr></thead><tbody>\
        <tr><td>1</td><td>1</td><td></td><td><a href="rider/a">LEADER A</a></td><td><a href="team/x">Team X</a></td><td class="time">18:21:40</td></tr>\
        <tr><td>2</td><td>3</td><td>▲1</td><td><a href="rider/b">SECOND B</a></td><td><a href="team/y">Team Y</a></td><td class="time">0:12</td></tr>\
        <tr><td>DNF</td><td>5</td><td></td><td><a href="rider/c">OUT C</a></td><td><a href="team/z">Team Z</a></td><td class="time"></td></tr>\
        </tbody></table>
        """
        let page = try parse(html)

        XCTAssertEqual(page.rows.map(\.name), ["LEADER A", "SECOND B"])
        XCTAssertEqual(page.rows.map(\.time), ["18:21:40", "0:12"])
        XCTAssertEqual(page.rows.map(\.team), ["Team X", "Team Y"])
    }

    func testOneDayPageWithoutAHeaderFallsBackToTheRiderAndTeamLinks() throws {
        let html = """
        <table class="results"><tbody>\
        <tr><td>1</td><td><a href="rider/a">WINNER A</a></td><td><a href="team/x">Team X</a></td><td class="time">4:41:02</td></tr>\
        <tr><td>2</td><td><a href="rider/b">SECOND B</a></td><td><a href="team/y">Team Y</a></td><td class="time">,,</td></tr>\
        </tbody></table>
        """
        let page = try parse(html)

        XCTAssertEqual(
            page.rows,
            [
                .init(position: "1", name: "WINNER A", team: "Team X", time: "4:41:02"),
                .init(position: "2", name: "SECOND B", team: "Team Y", time: ",,")
            ]
        )
        XCTAssertNil(page.stage)
    }

    func testAPageWithoutAResultsTableGivesNoRowsInsteadOfThrowing() throws {
        let page = try parse("<html><body><h1>Just a moment...</h1></body></html>")

        XCTAssertTrue(page.rows.isEmpty)
    }

    // MARK: - Time column -

    func testTimesShowTheLeadersTimeThenGapsAndSameTime() {
        XCTAssertEqual(ViewModel.displayTime("4:12:05", isLeader: true), "4:12:05")
        XCTAssertEqual(ViewModel.displayTime(",,", isLeader: false), "s.t.")
        XCTAssertEqual(ViewModel.displayTime("0:00", isLeader: false), "s.t.")
        XCTAssertEqual(ViewModel.displayTime("0:12", isLeader: false), "+0:12")
        XCTAssertEqual(ViewModel.displayTime("+0:12", isLeader: false), "+0:12")
        XCTAssertEqual(ViewModel.displayTime("#", isLeader: false), "")
    }

    // MARK: - Descriptor and subtitle -

    func testStageFromTheDetailsLineGetsAGCPageAndASubtitle() {
        let stage = descriptor(
            details: "Stage 3 | Sungai Petani - Kuala Kangsar (189.7km)",
            path: "race/tour-de-langkawi/2026/stage-3"
        )

        XCTAssertEqual(stage.kind, .stage("3"))
        XCTAssertEqual(stage.subtitle(), "Stage 3  ·  Sungai Petani › Kuala Kangsar  (189.7km)")
        XCTAssertEqual(
            stage.gcURL?.absoluteString,
            "https://www.procyclingstats.com/race/tour-de-langkawi/2026/stage-3-gc"
        )
        XCTAssertEqual(stage.classifications, [.stage, .gc])
    }

    func testOneDayRaceHasNoClassificationFilter() {
        let oneDay = descriptor(
            name: "Giro di Campania (1.1)",
            details: "Caserta - Naples (192.7km)",
            path: "race/giro-di-campania/2026/result"
        )

        XCTAssertEqual(oneDay.kind, .oneDay)
        XCTAssertEqual(oneDay.subtitle(), "One-day race  ·  Caserta › Naples  (192.7km)")
        XCTAssertNil(oneDay.gcURL)
        XCTAssertTrue(oneDay.classifications.isEmpty)
    }

    func testHomepageSpacingAndTimeTrialMarkersAreKept() {
        let itt = descriptor(
            details: "Stage 2a (ITT) | Wulpen - Wulpen (6km)",
            path: "race/keizer-der-juniores/2026/stage-2"
        )
        let worlds = descriptor(
            name: "World Championships WE - ITT (WC)",
            details: "Montreal  - Montreal  (39.2km)",
            path: "race/world-championship-itt-we/2026/result"
        )

        XCTAssertEqual(itt.subtitle(), "Stage 2a (ITT)  ·  Wulpen › Wulpen  (6km)")
        XCTAssertEqual(worlds.subtitle(), "One-day race  ·  Montreal › Montreal  (39.2km)")
    }

    func testFinalGeneralClassificationEntryShowsOnlyThatTable() {
        let gc = descriptor(
            details: "General classification",
            path: "race/tour-de-luxembourg/2026/gc"
        )

        XCTAssertEqual(gc.kind, .generalClassification)
        XCTAssertEqual(gc.subtitle(), "General classification")
        XCTAssertTrue(gc.classifications.isEmpty)
    }

    func testStageSuffixInTheNameIsReadLikeTodayRaces() {
        let suffixed = descriptor(
            name: "Tour of Turkey - S2",
            details: "",
            path: "race/tour-of-turkey/2026/stage-2"
        )

        XCTAssertEqual(suffixed.kind, .stage("2"))
        XCTAssertEqual(suffixed.subtitle(), "Stage 2")
    }

    func testSubtitleTakesTheRouteFromTheResultPageWhenTheHomepageHasNone() {
        let bare = descriptor(
            details: "",
            path: "race/tour-de-luxembourg/2026/stage-5"
        )
        let page = DTO.RaceResultPage(
            stage: "Stage 5",
            from: "Mersch",
            to: "Luxembourg",
            distance: "177km",
            rows: []
        )

        XCTAssertEqual(bare.subtitle(page: page), "Stage 5  ·  Mersch › Luxembourg  (177km)")
    }

    /// The homepage fixture's own result entries, so the descriptor follows what PCS really sends.
    func testHomepageFixtureEntriesMapToStageOneDayAndGC() throws {
        guard let url = Bundle(for: type(of: self)).url(forResource: "pcs_real", withExtension: "html") else {
            throw XCTSkip("Missing pcs_real.html fixture in the test bundle")
        }
        let document = try SwiftSoup.parse(try String(contentsOf: url, encoding: .utf8))
        let results = try Service.parseResultsYesterday(document)
        func kind(endingWith path: String) -> RaceResult.Descriptor.Kind? {
            results
                .first { $0.raceURL?.absoluteString.hasSuffix(path) == true }
                .map {
                    RaceResult.Descriptor(
                        name: $0.raceName,
                        details: $0.raceDetails,
                        url: $0.raceURL
                    ).kind
                }
        }

        XCTAssertEqual(kind(endingWith: "tour-de-luxembourg/2026/stage-5"), .stage("5"))
        XCTAssertEqual(kind(endingWith: "keizer-der-juniores/2026/stage-2b"), .stage("2b"))
        XCTAssertEqual(kind(endingWith: "tour-de-luxembourg/2026/gc"), .generalClassification)
        XCTAssertEqual(kind(endingWith: "giro-di-campania/2026/result"), .oneDay)
    }

    // MARK: - Interactor and view model -

    @MainActor
    private func settledState(
        _ race: HomeRaces.Representable.RaceFinished,
        loadPage: @escaping (URL) async -> DTO.RaceResultPage?,
        actions: [RaceResult.Action] = [.onAppear]
    ) async -> RaceResult.ViewState {
        let viewModel = ViewModel(
            race: race,
            router: Router(),
            interactor: RaceResult.InteractorImpl(
                descriptor: RaceResult.Descriptor(
                    name: race.race,
                    details: race.raceDetails,
                    url: race.raceURL
                ),
                loadPage: loadPage
            )
        )
        let settled = expectation(description: "the selected table settles")
        var cancellable: AnyCancellable?
        cancellable = viewModel.$stateView
            .dropFirst()
            .sink { state in
                if case .loading = state.table { return }
                settled.fulfill()
                cancellable?.cancel()
            }
        actions.forEach { viewModel.action($0) }
        await fulfillment(of: [settled], timeout: 2)
        return viewModel.stateView
    }

    @MainActor
    func testLoadedStageShowsTheTopTenWithGapsAndTheFilter() async throws {
        let page = try parse(stagePageHTML)
        let state = await settledState(race()) { _ in page }

        XCTAssertEqual(state.subtitle, "Stage 5  ·  Mersch › Luxembourg-Limpertsberg  (177km)")
        XCTAssertEqual(state.classifications, [.stage, .gc])
        guard case .loaded(let rows) = state.table else {
            return XCTFail("expected the loaded table, got \(state.table)")
        }
        XCTAssertEqual(rows.count, 10)
        XCTAssertEqual(rows.prefix(4).map(\.time), ["4:12:05", "s.t.", "+0:04", "+0:14"])
    }

    @MainActor
    func testSelectingGCLoadsTheStagePlusGCPage() async {
        var requested: [String] = []
        let gcPage = DTO.RaceResultPage(
            stage: nil,
            from: nil,
            to: nil,
            distance: nil,
            rows: [.init(position: "1", name: "GC LEADER", team: "Team", time: "18:00:00")]
        )
        let state = await settledState(
            race(),
            loadPage: { url in
                requested.append(url.lastPathComponent)
                return gcPage
            },
            actions: [.select(.gc)]
        )

        XCTAssertEqual(requested, ["stage-5-gc"])
        XCTAssertEqual(state.selected, .gc)
        XCTAssertEqual(state.fullResultsURL?.lastPathComponent, "stage-5-gc")
        guard case .loaded(let rows) = state.table else {
            return XCTFail("expected the GC table, got \(state.table)")
        }
        XCTAssertEqual(rows.map(\.name), ["GC LEADER"])
    }

    @MainActor
    func testAFailedLoadKeepsTheHomepagePodium() async {
        let state = await settledState(race()) { _ in nil }

        guard case .unavailable(let fallback, _) = state.table else {
            return XCTFail("expected the podium fallback, got \(state.table)")
        }
        XCTAssertEqual(fallback.map(\.name), ["VAN DER POEL Mathieu", "GACHIGNARD Thomas", "PIGANZOLI Davide"])
        XCTAssertEqual(fallback.map(\.time), ["4:12:05", "s.t.", "+0:04"])
        XCTAssertEqual(fallback.map(\.team), ["", "", ""], "the homepage's '#' placeholder is not a team")
        XCTAssertEqual(state.fullResultsURL?.lastPathComponent, "stage-5")
    }
}
