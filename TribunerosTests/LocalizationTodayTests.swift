//
//  LocalizationTodayTests.swift
//  TribunerosTests
//
//  The Catalan display text of the Today Races tab, and that the parsing next to it still reads
//  the English PCS text.
//

import XCTest
@testable import Tribuneros

final class LocalizationTodayTests: XCTestCase {
    private typealias RaceNext = HomeRaces.Representable.RaceNext
    private typealias RaceResult = HomeRaces.RaceResult
    private typealias RacePreview = HomeRaces.RacePreview

    override func setUp() {
        super.setUp()
        L10n.setLanguage("ca")
    }

    override func tearDown() {
        L10n.setLanguage("en")
        super.tearDown()
    }

    private func race(
        name: String = "Race",
        category: String = "",
        eta: String = "16:42",
        isLive: Bool = false,
        finishDate: Date? = nil,
        startTime: String? = nil
    ) -> RaceNext {
        RaceNext(
            eta: eta,
            duration: "2h",
            name: name,
            category: category,
            raceType: "",
            distance: "",
            urlPath: nil,
            flagCode: "",
            isLive: isLive,
            finishDate: finishDate,
            startTime: startTime
        )
    }

    // MARK: - Remaining time and tags -

    func testTheRemainingTimeIsReadInCatalan() {
        let now = Date()

        XCTAssertEqual(
            race(finishDate: now.addingTimeInterval(2 * 3600 + 14 * 60 + 0.5)).remainingTimeDescription(now: now),
            "2 h 14 min"
        )
        XCTAssertEqual(
            race(finishDate: now.addingTimeInterval(3600 + 0.5)).remainingTimeDescription(now: now),
            "1 h"
        )
        XCTAssertEqual(
            race(finishDate: now.addingTimeInterval(30 * 60 + 0.5)).remainingTimeDescription(now: now),
            "30 min"
        )
    }

    func testStatusTagsAreInCatalan() {
        XCTAssertEqual(RaceStatusTag.Kind.live.title, "EN DIRECTE")
        XCTAssertEqual(RaceStatusTag.Kind.today.title, "AVUI")
        XCTAssertEqual(RaceStatusTag.Kind.noRaces.title, "CAP CURSA")
        XCTAssertEqual(RaceStatusTag.Kind.finished.title, "ACABADA")
    }

    // MARK: - Stage, one-day and gender -

    func testStagesAndOneDayRacesAreNamedInCatalan() {
        XCTAssertEqual(race(name: "Tour of Poyang Lake - S2").stageLabel, "Etapa 2")
        XCTAssertEqual(race(name: "World Championships WU - ITT").subtitle, "Cursa d’un dia")
    }

    func testTheStageParsingStillReadsThePCSText() {
        XCTAssertEqual(race(name: "Tour of Poyang Lake - S2").title, "Tour of Poyang Lake")
        XCTAssertEqual(HomeRaces.Stage.split(name: "Tour of Poyang Lake - S2")?.stage, "2")
        XCTAssertEqual(HomeRaces.Stage.number(inDetails: "Stage 2a (ITT) | Wulpen - Wulpen (6km)"), "2a")
    }

    func testGenderLabelsAreInCatalan() {
        XCTAssertEqual(race(category: "ME").genderLabel, "HOMES")
        XCTAssertEqual(race(category: "WU").genderLabel, "DONES")
    }

    // MARK: - Accessibility -

    func testTheAccessibilityDescriptionIsInCatalan() {
        let description = race(
            name: "Tour of Poyang Lake",
            category: "ME",
            eta: "16:42",
            isLive: true
        ).accessibilityDescription

        XCTAssertTrue(description.contains("en directe ara"), description)
        XCTAssertTrue(description.contains("homes"), description)
        XCTAssertTrue(description.contains("arribada prevista a les 16:42"), description)
    }

    // MARK: - Result screen -

    func testTheResultSubtitleAndClassificationsAreInCatalan() {
        let stage = RaceResult.Descriptor(
            name: "Skoda Tour de Luxembourg (2.Pro)",
            details: "Stage 3 | Sungai Petani - Kuala Kangsar (189.7km)",
            url: URL(string: "https://www.procyclingstats.com/race/tour-de-langkawi/2026/stage-3")
        )
        XCTAssertEqual(stage.subtitle(), "Etapa 3  ·  Sungai Petani › Kuala Kangsar  (189.7km)")

        let gc = RaceResult.Descriptor(
            name: "Tour",
            details: "General classification",
            url: URL(string: "https://www.procyclingstats.com/race/tour/2026/gc")
        )
        XCTAssertEqual(gc.subtitle(), "Classificació general")

        XCTAssertEqual(RaceResult.Classification.stage.title, "Etapa")
        XCTAssertEqual(RaceResult.Classification.gc.title, "GC")
    }

    func testTheGapTimesAreInCatalan() {
        typealias ViewModel = RaceResult.ViewModel<RaceResult.InteractorImpl>

        XCTAssertEqual(ViewModel.displayTime(",,", isLeader: false), "m.t.")
        XCTAssertEqual(ViewModel.displayTime("0:12", isLeader: false), "+0:12")
        XCTAssertEqual(ViewModel.displayTime("4:12:05", isLeader: true), "4:12:05")
    }

    // MARK: - Messages and shared strings -

    func testTheErrorMessagesAreFriendly() {
        XCTAssertEqual(
            HomeRaces.ErrorView.networkFailure.message,
            "No s’han pogut carregar les curses. Comprova la connexió i torna-ho a provar."
        )
    }

    func testTheRacePreviewFailureIsInCatalan() {
        typealias ViewModel = RacePreview.ViewModel<RacePreview.InteractorImpl>
        let preview = HomeRaces.Representable.RacePreview(countdown: "1h", name: "Race", url: nil)
        let state = ViewModel.mapToViewState(
            preview: preview,
            domain: RacePreview.Domain(url: nil, load: .failed)
        )

        XCTAssertEqual(
            state.body,
            .unavailable("No s’ha pogut carregar la prèvia de la cursa.")
        )
    }

    func testTheSpoilerHintIsInCatalan() {
        XCTAssertEqual(
            HomeRaces.SpoilerHint.text,
            "Mantén premut un resultat per mostrar o amagar els espòilers"
        )
    }

    func testTheWhereToWatchCoverageIsInCatalan() {
        XCTAssertEqual(HomeRaces.WhereToWatch.Coverage.noBroadcast.summary, "Llistada, sense retransmissió encara")
        XCTAssertEqual(HomeRaces.WhereToWatch.Coverage.notListed.summary, "No és a la graella de TV")
        XCTAssertEqual(HomeRaces.WhereToWatch.Coverage.channels(["A", "B", "C", "D"]).summary, "A · B · C +1")
    }

    func testTheRaceCountIsPluralisedInCatalan() {
        XCTAssertEqual(L10n.tr("%lld races", 1), "1 cursa")
        XCTAssertEqual(L10n.tr("%lld races", 3), "3 curses")
    }
}
