//
//  LocalizationPaddockTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class LocalizationPaddockTests: XCTestCase {
    override func setUp() {
        super.setUp()
        L10n.setLanguage("ca")
    }

    override func tearDown() {
        L10n.setLanguage("en")
        super.tearDown()
    }

    // MARK: - Filters

    func testFilterTitlesAreCatalan() {
        XCTAssertEqual(Paddock.Filter.all.title, "Tot")
        XCTAssertEqual(Paddock.Filter.transfers.title, "Fitxatges")
        XCTAssertEqual(Paddock.Filter.programs.title, "Programes")
        XCTAssertEqual(Paddock.Filter.birthdays.title, "Aniversaris")
    }

    func testFilterCasesStayTheSame() {
        XCTAssertEqual(Paddock.Filter.allCases, [.all, .transfers, .programs, .birthdays])
    }

    // MARK: - Day groups

    func testSectionIdStaysEnglishWhileTheTitleIsCatalan() {
        let section = Paddock.Section(title: "Yesterday", cards: [])
        XCTAssertEqual(section.id, "Yesterday")
        XCTAssertEqual(section.displayTitle, "Ahir")
    }

    func testDayTitlesAreCatalan() {
        XCTAssertEqual(Paddock.Section(title: "Today", cards: []).displayTitle, "Avui")
        XCTAssertEqual(Paddock.Section(title: "Earlier", cards: []).displayTitle, "Abans")
    }

    func testFeedGroupsStillUseEnglishKeys() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var domain = Paddock.Domain.empty
        domain.events = [
            .init(date: now, kind: .birthdays([]))
        ]
        domain.lastUpdated = now

        let state = Paddock.ViewModel<Paddock.InteractorImpl>.mapToViewState(from: domain, now: now)

        guard case .loaded(let sections) = state.feed else {
            return XCTFail("Expected a loaded feed")
        }
        XCTAssertEqual(sections.map(\.title), ["Today"])
        XCTAssertEqual(sections.map(\.displayTitle), ["Avui"])
    }

    // MARK: - Onboarding

    func testOnboardingTitlesAreCatalan() {
        let first = Onboarding.pages(showing: 1)
        XCTAssertEqual(first[0].title, "Et donem la benvinguda a Cycling Tribune")
        XCTAssertEqual(first[1].title, "Resultats sense espòilers")
        XCTAssertEqual(first[2].title, "Zona CX")
        XCTAssertEqual(first[3].title, "El Paddock")
    }

    func testReturningOnboardingWelcomeIsCatalan() {
        XCTAssertEqual(
            Onboarding.pages(showing: 2)[0].title,
            "Et tornem a donar la benvinguda a Cycling Tribune"
        )
    }

    func testOnboardingKeepsItsAnimationsAndOrder() {
        XCTAssertEqual(
            Onboarding.pages(showing: 1).map(\.animation),
            ["onboarding_welcome", "onboarding_spoilers", "onboarding_cx", "onboarding_paddock"]
        )
    }

    // MARK: - Buttons and maintenance

    func testButtonsAreCatalan() {
        XCTAssertEqual(L10n.tr("Skip"), "Omet")
        XCTAssertEqual(L10n.tr("Next"), "Següent")
        XCTAssertEqual(L10n.tr("Let's ride"), "Som-hi!")
    }

    func testMaintenanceAlertIsCatalan() {
        XCTAssertEqual(L10n.tr("Under maintenance"), "En manteniment")
    }

    func testEnglishLookupsAreUnchangedAfterSwitchingBack() {
        L10n.setLanguage("en")
        XCTAssertEqual(Paddock.Filter.all.title, "All")
        XCTAssertEqual(Paddock.Section(title: "Today", cards: []).displayTitle, "Today")
        XCTAssertEqual(Onboarding.pages(showing: 2)[0].title, "Welcome back to Cycling Tribune")
    }
}
