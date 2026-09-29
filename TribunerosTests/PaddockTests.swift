//
//  PaddockTests.swift
//  TribunerosTests
//
//  Created by albert vila on 28/9/26.
//

import XCTest
import Alfy
import SwiftSoup
import SwiftUI
@testable import Tribuneros

final class PaddockTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return calendar
    }()

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )!
    }

    private let rider = DTO.RiderLink(
        name: "Rider",
        url: nil,
        countryCode: "fr"
    )

    private var fetchedAt: Date { date(2026, 9, 21, 9, 3) }

    private var paddock: DTO.Paddock {
        DTO.Paddock(
            transfers: [
                .init(date: "20/09", rider: rider, teamName: "Team A"),
                .init(date: "17/09", rider: rider, teamName: "Team B")
            ],
            programUpdates: [
                .init(timeAgo: "15m", rider: rider, changes: [.init(isAdded: true, raceName: "Race A")]),
                .init(timeAgo: "16h", rider: rider, changes: [.init(isAdded: false, raceName: "Race B")]),
                .init(timeAgo: "41h", rider: rider, changes: [.init(isAdded: true, raceName: "Race C")])
            ],
            birthdays: [
                .init(rider: rider, age: "28")
            ]
        )
    }

    func testPressIsLoadingUntilAListIsKnown() {
        func press(_ links: [DTO.PressLink]?) -> Paddock.Press {
            let domain = Paddock.Domain(
                press: links,
                events: [],
                filter: .all,
                lastUpdated: nil,
                loading: false,
                error: nil
            )
            return Paddock.ViewModel<Paddock.InteractorImpl>.mapToViewState(
                from: domain,
                now: fetchedAt,
                calendar: calendar
            ).press
        }
        let link = DTO.PressLink(
            name: "Escape Collective",
            url: URL(string: "https://www.escapecollective.com")!
        )

        XCTAssertEqual(press(nil), .loading)
        XCTAssertEqual(press([]), .loaded([]))
        XCTAssertEqual(
            press([link]),
            .loaded([
                .init(
                    url: link.url,
                    name: "Escape Collective",
                    domain: "escapecollective.com"
                )
            ])
        )
    }

    private func viewState(
        events: [Paddock.Domain.Event],
        filter: Paddock.Filter = .all,
        lastUpdated: Date? = nil,
        loading: Bool = false,
        error: Error? = nil
    ) -> Paddock.ViewState {
        let domain = Paddock.Domain(
            press: [],
            events: events,
            filter: filter,
            lastUpdated: lastUpdated,
            loading: loading,
            error: error?.toEquatableError()
        )
        return Paddock.ViewModel<Paddock.InteractorImpl>.mapToViewState(
            from: domain,
            now: fetchedAt,
            calendar: calendar
        )
    }

    private func sectionCardIDs(_ state: Paddock.ViewState) -> [String: [String]] {
        guard case .loaded(let sections) = state.feed else {
            XCTFail("Expected a loaded feed, got \(state.feed)")
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: sections.map { ($0.title, $0.cards.map(\.id)) })
    }

    // MARK: - PCS times

    func testTimeAgoResolvesMinutesHoursAndDays() {
        let now = fetchedAt
        XCTAssertEqual(Paddock.InteractorImpl.date(fromTimeAgo: "15m", relativeTo: now), now.addingTimeInterval(-15 * 60))
        XCTAssertEqual(Paddock.InteractorImpl.date(fromTimeAgo: "16h", relativeTo: now), now.addingTimeInterval(-16 * 60 * 60))
        XCTAssertEqual(Paddock.InteractorImpl.date(fromTimeAgo: "2d", relativeTo: now), now.addingTimeInterval(-2 * 24 * 60 * 60))
        XCTAssertNil(Paddock.InteractorImpl.date(fromTimeAgo: "h", relativeTo: now))
        XCTAssertNil(Paddock.InteractorImpl.date(fromTimeAgo: "3w", relativeTo: now))
    }

    func testDayMonthFallsBackToLastYearWhenItWouldBeInTheFuture() {
        XCTAssertEqual(
            Paddock.InteractorImpl.date(fromDayMonth: "20/09", relativeTo: fetchedAt, calendar: calendar),
            date(2026, 9, 20)
        )
        XCTAssertEqual(
            Paddock.InteractorImpl.date(fromDayMonth: "28/12", relativeTo: date(2026, 1, 5), calendar: calendar),
            date(2025, 12, 28)
        )
        XCTAssertNil(Paddock.InteractorImpl.date(fromDayMonth: "20-09", relativeTo: fetchedAt, calendar: calendar))
    }

    // MARK: - Feed

    func testFeedGroupsByDayNewestFirst() {
        let events = Paddock.InteractorImpl.events(
            from: paddock,
            fetchedAt: fetchedAt,
            calendar: calendar
        )
        let state = viewState(events: events, lastUpdated: fetchedAt)

        guard case .loaded(let sections) = state.feed else {
            return XCTFail("Expected a loaded feed, got \(state.feed)")
        }
        XCTAssertEqual(sections.map(\.title), ["Today", "Yesterday", "Earlier"])
        // Event indexes: birthdays 0, program updates 1-3, transfers 4-5.
        XCTAssertEqual(sectionCardIDs(state), [
            "Today": ["birthdays-0", "program-1"],
            "Yesterday": ["program-2", "transfer-4"],
            "Earlier": ["program-3", "transfer-5"]
        ])
    }

    func testFilterKeepsOnlyMatchingCards() {
        let events = Paddock.InteractorImpl.events(
            from: paddock,
            fetchedAt: fetchedAt,
            calendar: calendar
        )

        XCTAssertEqual(
            sectionCardIDs(viewState(events: events, filter: .transfers, lastUpdated: fetchedAt)),
            ["Yesterday": ["transfer-4"], "Earlier": ["transfer-5"]]
        )
        XCTAssertEqual(
            sectionCardIDs(viewState(events: events, filter: .birthdays, lastUpdated: fetchedAt)),
            ["Today": ["birthdays-0"]]
        )
        XCTAssertEqual(
            sectionCardIDs(viewState(events: events, filter: .programs, lastUpdated: fetchedAt)),
            ["Today": ["program-1"], "Yesterday": ["program-2"], "Earlier": ["program-3"]]
        )
    }

    func testFeedStateWithoutEvents() {
        XCTAssertEqual(viewState(events: []).feed, .loading, "Never loaded yet")
        XCTAssertEqual(viewState(events: [], lastUpdated: fetchedAt).feed, .empty)
        XCTAssertEqual(viewState(events: [], lastUpdated: fetchedAt, loading: true).feed, .loading)
        XCTAssertEqual(viewState(events: [], error: URLError(.timedOut)).feed, .error)
    }

    func testFailedRefreshKeepsPreviousEvents() {
        let events = Paddock.InteractorImpl.events(
            from: paddock,
            fetchedAt: fetchedAt,
            calendar: calendar
        )
        let state = viewState(events: events, lastUpdated: fetchedAt, error: URLError(.timedOut))

        guard case .loaded = state.feed else {
            return XCTFail("Expected the previous feed, got \(state.feed)")
        }
    }

    // MARK: - Press

    func testPressLinksAcceptNamedAndPlainURLs() {
        let json = #"[{"Domestique":"https://www.domestiquecycling.com/en/"}, " https://www.cyclingnews.com ", {"Bad":"ftp://files.example.com"}, "not a url", 42]"#

        let links = Service.parsePressLinks(Data(json.utf8))

        XCTAssertEqual(links, [
            DTO.PressLink(name: "Domestique", url: URL(string: "https://www.domestiquecycling.com/en/")!),
            DTO.PressLink(name: nil, url: URL(string: "https://www.cyclingnews.com")!)
        ])
    }

    func testPressItemFallsBackToTheDomainWithoutWWW() {
        let named = Paddock.PressItem(link: .init(name: "Domestique", url: URL(string: "https://www.domestiquecycling.com/en/")!))
        XCTAssertEqual(named.name, "Domestique")
        XCTAssertEqual(named.domain, "domestiquecycling.com")

        let plain = Paddock.PressItem(link: .init(name: nil, url: URL(string: "https://www.cyclingnews.com")!))
        XCTAssertEqual(plain.name, "cyclingnews.com")
        XCTAssertNil(plain.domain)
    }
    // MARK: - Rider page

    func testPCSRiderPageParsesInlineLabels() throws {
        // Older PCS layout: bold labels inside one block, split by <br> and spans.
        let html = """
        <html><body>
        <div class="page-title"><div class="main"><h1>Tadej  Pogačar</h1></div>
        <div class="subtitle"><a href="team/uae-team-emirates-xrg-2026">UAE Team Emirates - XRG</a></div></div>
        <div class="rdr-img-cont"><img src="images/riders/bp/aa/tadej-pogacar-2026.jpg"></div>
        <div class="rdr-info-cont"><b>Date of birth:</b> 21st September 1998 (28)<br>
        <b>Nationality:</b> <span class="flag si"></span> <a href="nation/slovenia">Slovenia</a><br>
        <span><b>Weight:</b> 66 kg </span><span><b>Height:</b> 1.76 m</span>
        <span class="mt5"><b>Place of birth:</b> <a href="location/komenda">Komenda</a></span></div>
        </body></html>
        """

        let page = try XCTUnwrap(Service.parsePCSRiderPage(SwiftSoup.parse(html)))

        XCTAssertEqual(page.name, "Tadej Pogačar")
        XCTAssertEqual(page.team, "UAE Team Emirates - XRG")
        XCTAssertEqual(page.imageURL, URL(string: "https://www.procyclingstats.com/images/riders/bp/aa/tadej-pogacar-2026.jpg"))
        XCTAssertEqual(page.facts, [
            .init(label: "Date of birth", value: "21st September 1998 (28)"),
            .init(label: "Nationality", value: "Slovenia"),
            .init(label: "Weight", value: "66 kg"),
            .init(label: "Height", value: "1.76 m"),
            .init(label: "Place of birth", value: "Komenda")
        ])
    }

    func testPCSRiderPageParsesLabelValueRows() throws {
        // List layout: a `.bold` label element next to its value element.
        let html = """
        <html><body><h1>Remco Evenepoel</h1>
        <ul class="list"><li><div class="bold">Date of birth:</div><div>25th January 2000</div></li>
        <li><div class="bold">Nationality:</div><div>Belgium</div></li>
        <li><div class="bold">Notes</div><div>ignored: no colon</div></li></ul>
        </body></html>
        """

        let page = try XCTUnwrap(Service.parsePCSRiderPage(SwiftSoup.parse(html)))

        XCTAssertEqual(page.name, "Remco Evenepoel")
        XCTAssertNil(page.team)
        XCTAssertNil(page.imageURL)
        XCTAssertEqual(page.facts, [
            .init(label: "Date of birth", value: "25th January 2000"),
            .init(label: "Nationality", value: "Belgium")
        ])
    }

    func testPCSRiderPageWithoutNameIsNil() throws {
        XCTAssertNil(Service.parsePCSRiderPage(try SwiftSoup.parse("<html><body><p>Just a moment...</p></body></html>")))
    }

    func testTransferAndProgramCardsOpenTheRiderScreen() {
        let router = Router()
        let viewModel = Paddock.ViewModel(
            router: router,
            interactor: Paddock.InteractorImpl()
        )
        let card = Paddock.TransferCard(
            id: "t",
            date: "20/09",
            rider: .init(rider),
            teamName: "Team A"
        )

        viewModel.action(.didTapOnRider(.transfer(card)))

        XCTAssertEqual(router.navPath.count, 1)
    }
}
