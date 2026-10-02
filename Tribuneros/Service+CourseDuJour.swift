//
//  Service+CourseDuJour.swift
//  Tribuneros
//

import Foundation
import SwiftSoup
import Alfy

extension Service {
    static let courseDuJourURL = URL(string: "https://coursedujour.com/")!

    static func courseDuJourURL(date: String?) -> URL {
        guard let date else { return courseDuJourURL }
        return courseDuJourURL.appending(path: "day/\(date)/")
    }

    /// Alfy fixes the expiry when the copy is stored, so the day's first fetch lasts until 00:01.
    static func courseDuJourTTL(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimeInterval {
        let expiry = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60*60*12)
        return expiry.timeIntervalSince(now)
    }

    /// The site's today when `date` is nil, otherwise that day ("yyyy-MM-dd").
    static func getCourseDuJourPage(date: String? = nil) async -> DTO.CourseDuJourPage? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return CourseDuJourMock.page(date: date)
        }
        #endif
        do {
            let (data, _) = try await Requester
                .makeRequest(courseDuJourURL(date: date).absoluteString)
                .ttl(courseDuJourTTL())
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8),
                  let page = parseCourseDuJourPage(try SwiftSoup.parse(html))
            else {
                nonFatalCrashlytics(false, "coursedujour.com page not readable")
                return nil
            }
            return page
        } catch {
            nonFatalCrashlytics(isOffline(error), "coursedujour.com fetch failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// What the schedule lists for `key` on its day, sharing the cached page with the screen.
    static func getCourseDuJourCoverage(for key: HomeRaces.WhereToWatch.RaceKey) async -> HomeRaces.WhereToWatch.Coverage? {
        guard let page = await getCourseDuJourPage(date: key.date) else { return nil }
        return HomeRaces.WhereToWatch.coverage(
            for: key,
            in: page
        )
    }

    // MARK: - Parsing -

    static func parseCourseDuJourPage(_ document: Document) -> DTO.CourseDuJourPage? {
        let days = parseCourseDuJourDays(document)
        let pageDate = (try? document.select("[data-page-date]").first()?.attr("data-page-date"))
            ?? (try? document.select("a[aria-current=page][data-date]").first()?.attr("data-date"))
        guard let pageDate, !pageDate.isEmpty else { return nil }

        let heading = (try? document.select("#janus-schedule-head").first()?.text()) ?? ""
        let updatedAt = (try? document.select("#data-freshness").first()?.attr("data-time"))
            .flatMap(courseDuJourDate)
        let sections = ((try? document.select("h3").array()) ?? []).compactMap(parseCourseDuJourSection)
        guard !days.isEmpty || !sections.isEmpty else { return nil }
        return DTO.CourseDuJourPage(
            date: pageDate,
            heading: heading,
            updatedAt: updatedAt,
            days: days,
            sections: sections
        )
    }

    private static func parseCourseDuJourDays(_ document: Document) -> [DTO.CourseDuJourPage.Day] {
        var seen = Set<String>()
        return ((try? document.select("a[data-date][data-offset]").array()) ?? []).compactMap { link in
            guard let date = try? link.attr("data-date"),
                  let offset = (try? link.attr("data-offset")).flatMap(Int.init),
                  seen.insert(date).inserted
            else {
                return nil
            }
            let text = (try? link.text()) ?? ""
            let count = text.range(of: "(\\d+)\\s+races?", options: .regularExpression)
                .flatMap { Int(text[$0].prefix { $0.isNumber }) }
            return DTO.CourseDuJourPage.Day(
                date: date,
                offset: offset,
                raceCount: count ?? 0
            )
        }
    }

    /// A discipline heading sits in a header div; the race list is the `ul` that follows it.
    private static func parseCourseDuJourSection(_ heading: Element) -> DTO.CourseDuJourPage.Section? {
        guard let discipline = try? heading.text(), !discipline.isEmpty,
              let header = heading.parent()
        else {
            return nil
        }
        let caption = (try? header.select("span").last()?.text()) ?? ""
        let list = try? header.nextElementSibling()
        let rows = list.flatMap { $0.tagName() == "ul" ? try? $0.select("li[data-coverage-start]").array() : nil } ?? []
        guard !rows.isEmpty || caption.lowercased().contains("coverage") else { return nil }
        return DTO.CourseDuJourPage.Section(
            discipline: discipline,
            caption: caption,
            races: rows.compactMap(parseCourseDuJourRace)
        )
    }

    private static func parseCourseDuJourRace(_ row: Element) -> DTO.CourseDuJourPage.Race? {
        let fullName = ((try? row.select("button.copy-race-time").first()?.attr("data-race-name")) ?? "")
        let nameParts = fullName.components(separatedBy: " — ")
        let name = nameParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let stage = nameParts.dropFirst().joined(separator: " — ").trimmingCharacters(in: .whitespacesAndNewlines)

        let time = try? row.select("time[data-utc-start]").first()
        let meta = ((try? row.select("p").array()) ?? [])
            .compactMap { try? $0.text() }
            .first { $0.contains("·") }
            .map { $0.split(separator: "·", maxSplits: 1, omittingEmptySubsequences: false) } ?? []
        let trimmed = CharacterSet.whitespacesAndNewlines
        return DTO.CourseDuJourPage.Race(
            name: name,
            stage: stage.isEmpty ? nil : stage,
            category: meta.first.map { $0.trimmingCharacters(in: trimmed) } ?? "",
            location: meta.dropFirst().first.map { $0.trimmingCharacters(in: trimmed) } ?? "",
            start: (try? time?.attr("data-utc-start")).flatMap(courseDuJourDate),
            end: (try? time?.attr("data-utc-end")).flatMap(courseDuJourDate),
            broadcasters: parseCourseDuJourBroadcasters(row)
        )
    }

    // A race lists its channels in one of three layouts, richest first: the per-channel list of
    // future days, the calendar-subscription checkboxes of today's rows, the summary chips.
    private static func parseCourseDuJourBroadcasters(_ row: Element) -> [DTO.CourseDuJourPage.Broadcaster] {
        var found: [DTO.CourseDuJourPage.Broadcaster] = []

        for item in (try? row.select(".flag-wrapper").array()) ?? [] {
            let link = try? item.select("a[title^=\"Watch on\"]").first()
            let title = (try? link?.attr("title")) ?? ""
            let name = title.isEmpty
                ? ((try? item.select("a[href^=/channels], span.whitespace-nowrap").first()?.text()) ?? "")
                : String(title.dropFirst("Watch on ".count))
            let regions = ((try? item.select("span").array()) ?? [])
                .compactMap { try? $0.text() }
                .first { $0.hasPrefix("(") && $0.hasSuffix(")") }
                .map { String($0.dropFirst().dropLast()) } ?? ""
            let window = try? item.select("time.bc-time").first()
            found.append(
                DTO.CourseDuJourPage.Broadcaster(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    regions: regions,
                    url: (try? link?.attr("href")).flatMap(webLink),
                    start: (try? window?.attr("data-utc-start")).flatMap(courseDuJourDate),
                    end: (try? window?.attr("data-utc-end")).flatMap(courseDuJourDate)
                )
            )
        }

        if found.isEmpty {
            for label in (try? row.select("label:has(input.cal-broadcaster)").array()) ?? [] {
                let text = (try? label.text())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let parts = text.range(of: "\\s*\\(([^()]*)\\)$", options: .regularExpression)
                found.append(
                    DTO.CourseDuJourPage.Broadcaster(
                        name: parts.map { String(text[..<$0.lowerBound]) } ?? text,
                        regions: parts.map { String(text[$0].drop { $0 == " " || $0 == "(" }.dropLast()) } ?? "",
                        url: nil,
                        start: nil,
                        end: nil
                    )
                )
            }
        }

        if found.isEmpty {
            for chip in (try? row.select(".race-chips > span").array()) ?? [] {
                found.append(
                    DTO.CourseDuJourPage.Broadcaster(
                        name: chip.ownText().trimmingCharacters(in: .whitespacesAndNewlines),
                        regions: (try? chip.select("span").first()?.text()) ?? "",
                        url: nil,
                        start: nil,
                        end: nil
                    )
                )
            }
        }

        var names = Set<String>()
        return found.filter { !$0.name.isEmpty && names.insert($0.name).inserted }
    }

    private static func webLink(_ value: String) -> URL? {
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased()) else {
            return nil
        }
        return url
    }

    /// "2026-10-01T02:11:00+00:00" and "2026-10-01T05:35:00.000Z".
    private static func courseDuJourDate(_ value: String) -> Date? {
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return plain.date(from: value) ?? fractional.date(from: value)
    }
}
