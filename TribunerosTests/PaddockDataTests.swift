//
//  PaddockDataTests.swift
//  TribunerosTests
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class PaddockDataTests: XCTestCase {

    private func fixtureData(_ name: String, _ ext: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: name, withExtension: ext))
        return try Data(contentsOf: url)
    }

    private func riderPage() throws -> DTO.PCSRiderPage {
        let html = try XCTUnwrap(String(data: fixtureData("pcs_rider", "html"), encoding: .utf8))
        return try XCTUnwrap(Service.parsePCSRiderPage(SwiftSoup.parse(html)))
    }

    private func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    // MARK: - Real rider page

    func testRealRiderPageHeader() throws {
        let page = try riderPage()

        XCTAssertEqual(page.name, "Tadej Pogačar")
        XCTAssertEqual(page.team, "UAE Team Emirates - XRG")
        XCTAssertEqual(page.imageURL?.absoluteString, "https://www.procyclingstats.com/images/riders/oh/dq/tadej-pogacar-2026.jpg")
        XCTAssertFalse(page.facts.isEmpty)
        XCTAssertFalse(page.facts.contains { $0.label == "Name" })
        XCTAssertEqual(page.facts.first { $0.label == "Nationality" }?.value, "Slovenia")
        XCTAssertEqual(page.facts.first { $0.label == "Place of birth" }?.value, "Klanec")
    }

    func testRealRiderPageSpecialtiesAndKeyStats() throws {
        let page = try riderPage()

        XCTAssertEqual(page.specialties.map(\.title), ["Oneday", "GC", "TT", "Sprint", "Climber", "Hills"])
        XCTAssertEqual(page.specialties.first, .init(title: "Oneday", points: 9983))
        XCTAssertEqual(page.specialties[4].points, 11052)
        XCTAssertEqual(page.keyStats.count, 4)
        XCTAssertEqual(page.keyStats.first, .init(value: "130", title: "Wins", detail: "GC (22) Oneday races (33) ITT (10)"))
    }

    func testRealRiderPageTopResultsTeamsAndProgram() throws {
        let page = try riderPage()

        XCTAssertFalse(page.topResults.isEmpty)
        XCTAssertEqual(page.topResults.first?.count, "5x")
        XCTAssertEqual(page.topResults.first?.kind, "GC")
        XCTAssertEqual(page.topResults.first?.race, "Tour de France")
        XCTAssertEqual(page.topResults.first?.years, "'20, '21, '24, '25, '26")
        XCTAssertNil(page.topResults.first { $0.race == "Il Lombardia" }?.kind)

        XCTAssertGreaterThanOrEqual(page.teams.count, 5)
        XCTAssertEqual(page.teams.first?.team, "UAE Team Emirates - XRG")
        XCTAssertEqual(page.teams.first?.level, "WT")
        let seasons = page.teams.compactMap { Int($0.season) }
        XCTAssertEqual(seasons.count, page.teams.count, "the combined 2027-2032 row is skipped")
        XCTAssertEqual(seasons, seasons.sorted(by: >), "newest first")

        XCTAssertEqual(page.program, [
            .init(date: "02.07", race: "Tour de France", countryCode: "fr"),
            .init(date: "04.09", race: "La Vuelta Ciclista a España", countryCode: "es")
        ])
    }

    func testRealRiderPageRankingDeduplicatesSeasons() throws {
        let page = try riderPage()
        let seasons = page.rankingBySeason.map(\.season)

        XCTAssertEqual(page.rankingBySeason.first, .init(season: "2026", points: "3715", rank: "1"))
        XCTAssertEqual(Set(seasons).count, seasons.count)
        XCTAssertEqual(page.rankingBySeason[1], .init(season: "2025", points: "4921", rank: "1"))
    }

    func testRealRiderPageSeasonResults() throws {
        let page = try riderPage()
        let results = page.seasonResults

        XCTAssertGreaterThan(results.count, 15)
        XCTAssertEqual(
            results.first,
            .init(
                date: "22.08 › 13.09",
                result: "",
                race: "La Vuelta Ciclista a España",
                raceClass: "2.UWT",
                distance: nil,
                pcsPoints: nil,
                isStage: false
            )
        )
        XCTAssertEqual(
            results[1],
            .init(
                date: "29.08",
                result: "DNF",
                race: "Stage 8 - Puçol › Xeraco",
                raceClass: nil,
                distance: "161",
                pcsPoints: nil,
                isStage: true
            )
        )
        let win = try XCTUnwrap(results.first { $0.date == "27.08" })
        XCTAssertEqual(win.result, "1")
        XCTAssertEqual(win.pcsPoints, "80")
        XCTAssertEqual(win.distance, "177.4")
        XCTAssertTrue(results.contains { !$0.isStage && $0.raceClass != nil && $0.pcsPoints != nil })
        XCTAssertFalse(results.contains { $0.race.contains("Stage 8 Stage 8") })
    }

    func testRiderPageSectionsDegradeToEmpty() throws {
        let page = try XCTUnwrap(Service.parsePCSRiderPage(SwiftSoup.parse("<html><body><h1>Someone</h1></body></html>")))

        XCTAssertTrue(page.specialties.isEmpty)
        XCTAssertTrue(page.keyStats.isEmpty)
        XCTAssertTrue(page.topResults.isEmpty)
        XCTAssertTrue(page.teams.isEmpty)
        XCTAssertTrue(page.program.isEmpty)
        XCTAssertTrue(page.rankingBySeason.isEmpty)
        XCTAssertTrue(page.seasonResults.isEmpty)
    }

    // MARK: - Feed formats

    func testRSSFeedEscapeCollective() throws {
        let feed = try XCTUnwrap(Service.parsePressFeed(fixtureData("press_rss", "xml")))

        XCTAssertEqual(feed.articles.count, 10)
        let first = feed.articles[0]
        XCTAssertEqual(first.title, "Team presentation ahead of 2027 Grand Départ will be a paid, ticketed event")
        XCTAssertEqual(first.url.absoluteString, "https://escapecollective.com/team-presentation-ahead-of-2027-grand-depart-will-be-a-paid-ticketed-event/")
        XCTAssertEqual(first.date, date("2026-10-20T18:13:26Z"))
        XCTAssertNotNil(first.summary)
        XCTAssertFalse(first.summary?.contains("<") ?? true)
        XCTAssertEqual(feed.articles.filter { $0.imageURL != nil }.count, 4, "media:content images, only on the items that carry one")
        let dates = feed.articles.compactMap(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testRSSFeedCyclingUpToDateUsesEnclosureAndEntities() throws {
        let feed = try XCTUnwrap(Service.parsePressFeed(fixtureData("press_news_rss", "xml")))

        XCTAssertEqual(feed.articles.count, 10)
        XCTAssertEqual(feed.articles[0].date, date("2026-10-20T17:00:00Z"))
        XCTAssertTrue(feed.articles.contains { $0.title.contains("Picnic PostNL's") }, "entities decoded")
        XCTAssertTrue(feed.articles.allSatisfy { $0.title.contains("&#") == false })
        XCTAssertTrue(feed.articles.allSatisfy { $0.imageURL != nil })
        XCTAssertTrue(feed.articles.allSatisfy { $0.summary?.contains("<img") != true })
    }

    func testGoogleNewsSitemap() throws {
        let feed = try XCTUnwrap(Service.parsePressFeed(fixtureData("press_news_sitemap", "xml")))

        XCTAssertEqual(feed.articles.map(\.title), ["Newest story", "Middle story", "Older story & its title"])
        XCTAssertEqual(feed.articles[0].url.absoluteString, "https://example-cycling.test/news/newest-story")
        XCTAssertEqual(feed.articles[0].date, date("2026-10-20T07:00:00Z"))
        XCTAssertEqual(feed.articles[0].imageURL?.absoluteString, "https://example-cycling.test/img/newest.jpg")
        XCTAssertNil(feed.articles[1].imageURL)
        XCTAssertNil(feed.articles[1].summary)
    }

    func testAtomFeed() throws {
        let feed = try XCTUnwrap(Service.parsePressFeed(fixtureData("press_atom", "xml")))

        XCTAssertEqual(feed.articles.count, 2)
        let first = feed.articles[0]
        XCTAssertEqual(first.title, "Atom first entry")
        XCTAssertEqual(first.url.absoluteString, "https://example-atom.test/first", "alternate link, not self")
        XCTAssertEqual(first.date, date("2026-10-19T08:00:00Z"), "published wins over updated")
        XCTAssertEqual(first.summary, "Short summary with & entity.")
        XCTAssertEqual(first.imageURL?.absoluteString, "https://example-atom.test/thumb.jpg")
        XCTAssertEqual(feed.articles[1].url.absoluteString, "https://example-atom.test/second")
        XCTAssertEqual(feed.articles[1].date, date("2026-10-17T08:00:00Z"), "updated is the fallback")
    }

    func testEmptyOrInvalidFeedIsNil() {
        XCTAssertNil(Service.parsePressFeed(Data()))
        XCTAssertNil(Service.parsePressFeed(Data("<html><body>nope</body></html>".utf8)))
        XCTAssertNil(Service.parsePressFeed(Data("<rss><channel><title>x</title></channel></rss>".utf8)))
    }

    func testFeedIsLimitedToThirtyNewestFirst() throws {
        let items = (1...40).map { index in
            "<item><title>Item \(index)</title><link>https://site.test/\(index)</link><pubDate>Mon, 19 Oct 2026 \(String(format: "%02d", index % 24)):00:00 GMT</pubDate></item>"
        }.joined()
        let xml = "<rss version=\"2.0\"><channel><title>t</title><link>https://site.test</link>\(items)</channel></rss>"

        let feed = try XCTUnwrap(Service.parsePressFeed(Data(xml.utf8)))

        XCTAssertEqual(feed.articles.count, 30)
        let dates = feed.articles.compactMap(\.date)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testDatedArticlesComeBeforeUndatedOnes() throws {
        let xml = """
        <rss version="2.0"><channel>
        <item><title>No date</title><link>https://site.test/a</link></item>
        <item><title>Dated</title><link>https://site.test/b</link><pubDate>Mon, 19 Oct 2026 10:00:00 GMT</pubDate></item>
        <item><title>Dated</title><link>https://site.test/b</link><pubDate>Mon, 19 Oct 2026 10:00:00 GMT</pubDate></item>
        </channel></rss>
        """

        let feed = try XCTUnwrap(Service.parsePressFeed(Data(xml.utf8)))

        XCTAssertEqual(feed.articles.map(\.title), ["Dated", "No date"], "duplicate links dropped")
    }

    // MARK: - Summary

    func testSummaryStripsTagsAndDecodesEntities() {
        let raw = "<p>Hello   <b>world</b> &amp; friends&nbsp;&#8217;s<br>second line</p> <img src=\"x.jpg\">"

        XCTAssertEqual(Service.pressSummary(raw), "Hello world & friends ’s second line")
        XCTAssertNil(Service.pressSummary("  <p> </p> "))
    }

    func testSummaryIsCutNearTwoHundredFortyCharacters() throws {
        let raw = "<p>" + String(repeating: "word ", count: 100) + "</p>"

        let summary = try XCTUnwrap(Service.pressSummary(raw))

        XCTAssertLessThanOrEqual(summary.count, 241)
        XCTAssertTrue(summary.hasSuffix("…"))
        XCTAssertTrue(summary.dropLast().hasSuffix("word"), "cut at a word")
        XCTAssertEqual(Service.pressSummary("Short one"), "Short one")
    }

    // MARK: - Discovery

    private let site = URL(string: "https://www.example.com")!

    func testDiscoveryTakesFirstFeedLink() {
        let html = """
        <html><head>
        <link rel="stylesheet" href="/a.css">
        <link rel="alternate" type="application/rss+xml" title="Site" href="https://www.example.com/rss/">
        <link rel="alternate" type="application/atom+xml" href="/atom.xml">
        </head></html>
        """

        XCTAssertEqual(Service.pressFeedURL(fromHomepage: html, siteURL: site)?.absoluteString, "https://www.example.com/rss/")
    }

    func testDiscoverySkipsCommentFeedsAndResolvesRelativeLinks() {
        let html = """
        <html><head>
        <link rel="alternate" type="application/rss+xml" title="Site &raquo; Comments Feed" href="https://www.example.com/comments/feed/">
        <link rel="alternate" type="application/rss+xml" title="Site" href="/feeds.xml">
        </head></html>
        """

        XCTAssertEqual(Service.pressFeedURL(fromHomepage: html, siteURL: site)?.absoluteString, "https://www.example.com/feeds.xml")
    }

    func testDiscoveryWithoutFeedIsNil() {
        let html = """
        <html><head>
        <link rel="alternate" hreflang="es" href="https://www.example.com/es/">
        <link rel="alternate" type="application/rss+xml" title="Comments" href="/comments/feed/">
        </head></html>
        """

        XCTAssertNil(Service.pressFeedURL(fromHomepage: html, siteURL: site))
        XCTAssertNil(Service.pressFeedURL(fromHomepage: "", siteURL: site))
    }

    // MARK: - Mocks

    func testMockRiderPageFillsEverySection() {
        let page = PaddockMock.riderPage(url: URL(string: "https://www.procyclingstats.com/rider/mock-rider")!)

        XCTAssertEqual(page.name, "Mock Rider")
        XCTAssertEqual(page.team, "Mock Racing Team")
        XCTAssertEqual(page.facts.count, 4)
        XCTAssertGreaterThanOrEqual(page.specialties.count, 3)
        XCTAssertFalse(page.keyStats.isEmpty)
        XCTAssertFalse(page.topResults.isEmpty)
        XCTAssertGreaterThanOrEqual(page.teams.count, 3)
        XCTAssertGreaterThanOrEqual(page.program.count, 2)
        XCTAssertFalse(page.rankingBySeason.isEmpty)
        XCTAssertGreaterThanOrEqual(page.seasonResults.count, 15)
        XCTAssertTrue(page.seasonResults.contains { $0.isStage })
        XCTAssertTrue(page.seasonResults.contains { !$0.isStage })
    }

    func testMockPressFeeds() {
        let news = PaddockMock.pressFeed(for: URL(string: "https://www.cyclingnews.com")!)
        let escape = PaddockMock.pressFeed(for: URL(string: "https://escapecollective.com")!)

        XCTAssertEqual(news?.articles.count, 8)
        XCTAssertEqual(escape?.articles.count, 8)
        XCTAssertNil(PaddockMock.pressFeed(for: URL(string: "https://joanseguidor.com")!))
        let dates = news?.articles.compactMap(\.date) ?? []
        XCTAssertEqual(dates, dates.sorted(by: >))
    }
}
