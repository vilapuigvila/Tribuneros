//
//  CourseDuJourTests.swift
//  TribunerosTests
//
//  Pins coursedujour.com's markup (coursedujour_today.html: the site's today, rows with the
//  calendar-subscription channels; coursedujour_day.html: a busy later day, rows with the
//  per-channel list) so a redesign fails loudly instead of showing an empty schedule. Also covers
//  matching the opened race and its coverage. Re-capture the fixtures with URLSession when the site changes.
//

import XCTest
import SwiftSoup
@testable import Tribuneros

final class CourseDuJourTests: XCTestCase {
    private typealias WhereToWatch = HomeRaces.WhereToWatch

    private func page(_ name: String) throws -> DTO.CourseDuJourPage {
        guard let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "html") else {
            XCTFail("Missing \(name).html fixture in the test bundle")
            throw XCTSkip()
        }
        let html = try String(contentsOf: url, encoding: .utf8)
        return try XCTUnwrap(Service.parseCourseDuJourPage(try SwiftSoup.parse(html)))
    }

    // MARK: - Parsing -

    func testTodayPageParsesDayStripHeadingAndRace() throws {
        let page = try page("coursedujour_today")

        XCTAssertEqual(page.date, "2026-10-01")
        XCTAssertEqual(page.heading, "Thursday, 1 October 2026")
        XCTAssertNotNil(page.updatedAt)

        XCTAssertEqual(page.days.count, 10)
        XCTAssertEqual(page.days.first?.offset, -1)
        let thursday = try XCTUnwrap(page.days.first { $0.offset == 0 })
        XCTAssertEqual(thursday.date, "2026-10-01")
        XCTAssertEqual(thursday.raceCount, 1)
        XCTAssertEqual(page.days.first { $0.date == "2026-10-03" }?.raceCount, 7)

        XCTAssertEqual(page.sections.map(\.discipline), ["Road", "CX", "Gravel"])
        XCTAssertEqual(page.sections[0].caption, "1 race with live coverage")
        XCTAssertTrue(page.sections[1].races.isEmpty)

        let race = try XCTUnwrap(page.sections[0].races.first)
        XCTAssertEqual(race.name, "Petronas Le Tour de Langkawi")
        XCTAssertEqual(race.stage, "Stage 5")
        XCTAssertEqual(race.category, "2.Pro (Men)")
        XCTAssertEqual(race.location, "Tapah, Malaysia")
        XCTAssertEqual(race.start, Date(timeIntervalSince1970: 1_790_820_660))
        XCTAssertEqual(race.end, Date(timeIntervalSince1970: 1_790_832_900))
    }

    func testTodayPageReadsChannelsFromCalendarCheckboxes() throws {
        let race = try XCTUnwrap(try page("coursedujour_today").sections[0].races.first)

        XCTAssertEqual(race.broadcasters.map(\.name), ["Eurosport / HBO Max", "FloBikes"])
        XCTAssertEqual(race.broadcasters.map(\.regions), ["FI, SE", "CA, US"])
        XCTAssertNil(race.broadcasters[0].url)
    }

    func testDayPageParsesEveryRaceWithItsChannelDetails() throws {
        let page = try page("coursedujour_day")

        XCTAssertEqual(page.date, "2026-10-03")
        XCTAssertEqual(page.sections.flatMap(\.races).count, 7)

        let emilia = try XCTUnwrap(page.sections.flatMap(\.races).first { $0.name == "Giro dell'Emilia" })
        XCTAssertNil(emilia.stage)
        XCTAssertEqual(emilia.category, "1.Pro (Men)")
        XCTAssertEqual(emilia.location, "Ferrara, Italy")
        XCTAssertTrue(emilia.broadcasters.map(\.name).contains("RAI Sport"))

        let eurosport = try XCTUnwrap(emilia.broadcasters.first { $0.name == "Eurosport / HBO Max" })
        XCTAssertEqual(eurosport.regions, "EUR")
        XCTAssertEqual(eurosport.url, URL(string: "https://www.eurosport.com"))
        XCTAssertEqual(eurosport.start, Date(timeIntervalSince1970: 1_791_028_800))

        let langkawi = try XCTUnwrap(page.sections.flatMap(\.races).first { $0.stage == "Stage 7" })
        XCTAssertEqual(langkawi.broadcasters.first?.regions, "DK, FI, NO, SE")
        XCTAssertEqual(langkawi.broadcasters.map(\.name), ["Eurosport / HBO Max", "FloBikes"])
    }

    func testDayPageSplitsMultiPartStagesAndKeepsRaceIdsUnique() throws {
        let races = try page("coursedujour_day").sections.flatMap(\.races)

        let uec = try XCTUnwrap(races.first { $0.stage == "Elite Women Road Race" })
        XCTAssertEqual(uec.name, "UEC Road European Championships 2026")
        XCTAssertEqual(uec.location, "Ljubljana")
        XCTAssertEqual(Set(races.map(\.id)).count, races.count)
    }

    func testRaceWithoutChannelsIsKept() throws {
        let html = """
        <div data-page-date="2026-10-03"><div><h3>Road</h3><span>no live coverage today</span></div>\
        <ul><li data-coverage-start="2026-10-03T12:00:00+00:00">\
        <time data-utc-start="2026-10-03T08:00:00+00:00" data-utc-end="2026-10-03T12:00:00+00:00"></time>\
        <button class="copy-race-time" data-race-name="Quiet Classic"></button>\
        <p>1.1 (Men) &nbsp;&middot;&nbsp; Somewhere, Italy</p></li></ul></div>
        """
        let page = try XCTUnwrap(Service.parseCourseDuJourPage(try SwiftSoup.parse(html)))

        let race = try XCTUnwrap(page.sections.first?.races.first)
        XCTAssertEqual(race.name, "Quiet Classic")
        XCTAssertEqual(race.category, "1.1 (Men)")
        XCTAssertTrue(race.broadcasters.isEmpty)
    }

    func testPageWithoutScheduleDoesNotParse() throws {
        let document = try SwiftSoup.parse("<html><body><p>Just a moment...</p></body></html>")
        XCTAssertNil(Service.parseCourseDuJourPage(document))
    }

    // MARK: - Matching the opened race -

    private func key(
        _ name: String,
        stage: String? = nil,
        raceClass: String = "",
        category: String = "ME",
        date: String = "2026-10-03"
    ) -> WhereToWatch.RaceKey {
        WhereToWatch.RaceKey(
            name: name,
            stage: stage,
            raceClass: raceClass,
            category: category,
            date: date
        )
    }

    private func schedule(_ races: [DTO.CourseDuJourPage.Race]) -> DTO.CourseDuJourPage {
        DTO.CourseDuJourPage(
            date: "2026-10-03",
            heading: "Heading",
            updatedAt: nil,
            days: [],
            sections: [
                DTO.CourseDuJourPage.Section(
                    discipline: "Road",
                    caption: "",
                    races: races
                )
            ]
        )
    }

    private func row(
        _ name: String,
        stage: String? = nil,
        category: String = "1.1 (Men)",
        channels: [String] = []
    ) -> DTO.CourseDuJourPage.Race {
        DTO.CourseDuJourPage.Race(
            name: name,
            stage: stage,
            category: category,
            location: "",
            start: nil,
            end: nil,
            broadcasters: channels.map {
                DTO.CourseDuJourPage.Broadcaster(
                    name: $0,
                    regions: "",
                    url: nil,
                    start: nil,
                    end: nil
                )
            }
        )
    }

    func testMatchesASponsoredStageRaceByItsStage() throws {
        let today = try page("coursedujour_today")

        let stage5 = WhereToWatch.match(
            key("Le Tour de Langkawi", stage: "5", raceClass: "2.Pro", date: "2026-10-01"),
            in: today
        )
        XCTAssertEqual(stage5?.name, "Petronas Le Tour de Langkawi")
        XCTAssertEqual(stage5?.stage, "Stage 5")
        XCTAssertNil(WhereToWatch.match(key("Le Tour de Langkawi", stage: "6", date: "2026-10-01"), in: today))
    }

    func testMatchesOneDayRacesAndIgnoresASharedWord() throws {
        let day = try page("coursedujour_day")

        XCTAssertEqual(WhereToWatch.match(key("Giro dell'Emilia", raceClass: "1.Pro"), in: day)?.name, "Giro dell'Emilia")
        XCTAssertEqual(WhereToWatch.match(key("Cholet Agglo Tour"), in: day)?.name, "Cholet Agglo Tour")
        XCTAssertNil(WhereToWatch.match(key("Giro di Sicilia"), in: day))
        XCTAssertNil(WhereToWatch.match(key("Tour de Langkawi", stage: "6"), in: day))
    }

    func testAgeAndGenderPickTheRightChampionshipRace() throws {
        let day = try page("coursedujour_day")

        XCTAssertEqual(
            WhereToWatch.match(key("European Championships", raceClass: "CC", category: "WE"), in: day)?.stage,
            "Elite Women Road Race"
        )
        XCTAssertEqual(
            WhereToWatch.match(key("European Championships", raceClass: "CC", category: "MJ"), in: day)?.stage,
            "Junior Men Road Race"
        )
        XCTAssertNil(WhereToWatch.match(key("European Championships", raceClass: "CC", category: "ME"), in: day))
        XCTAssertEqual(
            WhereToWatch.match(key("Il Lombardia U23", category: "MU"), in: day)?.name,
            "Il Lombardia Under 23"
        )
        XCTAssertNil(WhereToWatch.match(key("Il Lombardia"), in: day))
    }

    func testMatchesGrandPrixAbbreviationAndRejectsTheOtherGender() {
        let page = schedule([
            row("GP de Montréal", category: "1.UWT (Men)"),
            row("Tour de France Femmes avec Zwift", stage: "Stage 2", category: "2.UWT (Women)")
        ])

        XCTAssertEqual(
            WhereToWatch.match(key("Grand Prix Cycliste de Montréal", raceClass: "1.UWT"), in: page)?.name,
            "GP de Montréal"
        )
        XCTAssertNil(WhereToWatch.match(key("Tour de France", stage: "2"), in: page))
        XCTAssertEqual(
            WhereToWatch.match(key("Tour de France Femmes", stage: "2", category: "WE"), in: page)?.stage,
            "Stage 2"
        )
    }

    func testTwoEqualCandidatesFeatureNeither() {
        let page = schedule([
            row("Quiet Classic"),
            row("Quiet Classic")
        ])

        XCTAssertNil(WhereToWatch.match(key("Quiet Classic"), in: page))
    }

    func testCoverageSummarisesTheMatchedRace() throws {
        let today = try page("coursedujour_today")
        let langkawi = key("Le Tour de Langkawi", stage: "5", date: "2026-10-01")

        let coverage = WhereToWatch.coverage(for: langkawi, in: today)
        XCTAssertEqual(coverage, .channels(["Eurosport / HBO Max", "FloBikes"]))
        XCTAssertEqual(coverage.summary, "Eurosport / HBO Max · FloBikes")

        XCTAssertEqual(WhereToWatch.coverage(for: key("Il Lombardia"), in: today), .notListed)
        XCTAssertEqual(
            WhereToWatch.coverage(for: key("Quiet Classic"), in: schedule([row("Quiet Classic")])),
            .noBroadcast
        )
        XCTAssertEqual(WhereToWatch.Coverage.channels(["A", "B", "C", "D", "E"]).summary, "A · B · C +2")
    }

    func testListingExposesTheMatchedRaceIDAndDay() throws {
        let today = try page("coursedujour_today")
        let langkawi = key("Le Tour de Langkawi", stage: "5", date: "2026-10-01")

        let listing = WhereToWatch.listing(for: langkawi, in: today)
        XCTAssertEqual(listing.coverage, .channels(["Eurosport / HBO Max", "FloBikes"]))
        XCTAssertEqual(listing.raceID, WhereToWatch.match(langkawi, in: today)?.id)
        XCTAssertNotNil(listing.raceID)
        XCTAssertEqual(listing.day, "2026-10-01")

        let missing = WhereToWatch.listing(for: key("Il Lombardia", date: "2026-10-01"), in: today)
        XCTAssertEqual(missing.coverage, .notListed)
        XCTAssertNil(missing.raceID)
        XCTAssertEqual(missing.day, "2026-10-01")
    }

    func testKeyFromATodayRacesRowUsesTheScheduleDay() {
        var parts = DateComponents()
        parts.timeZone = TimeZone(identifier: "UTC")
        parts.year = 2026
        parts.month = 10
        parts.day = 1
        parts.hour = 22
        parts.minute = 30
        let lateFinish = Calendar(identifier: .gregorian).date(from: parts)
        let race = HomeRaces.Representable.RaceNext(
            eta: "00:30",
            duration: "3h",
            name: "CRO Race - S1",
            category: "ME",
            raceType: "2.1",
            distance: "",
            urlPath: "https://www.procyclingstats.com/race/cro-race/2026/stage-1",
            flagCode: "hr",
            finishDate: lateFinish
        )

        let key = WhereToWatch.RaceKey(race: race)

        XCTAssertEqual(key.name, "CRO Race")
        XCTAssertEqual(key.stage, "1")
        XCTAssertEqual(key.raceClass, "2.1")
        XCTAssertEqual(key.date, "2026-10-02")
    }

    func testCacheLastsUntilOneMinutePastMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 8))!
        XCTAssertEqual(Service.courseDuJourTTL(now: morning, calendar: calendar), 16 * 3600 + 60)
        let lateNight = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 23, minute: 59))!
        XCTAssertEqual(Service.courseDuJourTTL(now: lateNight, calendar: calendar), 120)
    }
}
