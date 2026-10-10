//
//  Service+LiveRace.swift
//  Tribuneros
//
//  The race's PCS live page (`<race path>/live`) behind `HomeRaces.LiveRace`: polled every 5 s
//  while the live screen is open, so the cache is 4 s (a pull to refresh right after a poll
//  still reads the network).
//

import Foundation
import Alfy
import SwiftSoup

extension Service {
    private static let liveEventRowLimit = 5
    private static let liveEventColumnLimit = 4

    /// Fetches and parses a race's PCS live page (4 s cache); `nil` when it can't be loaded.
    static func getLivePage(url: URL) async -> DTO.LivePage? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return HomeRaces.MockScenario.livePage(for: url)
        }
        #endif
        do {
            let (data, _) = try await Requester
                .makeRequest(url.absoluteString)
                .ttl(4) // the live screen polls every 5 seconds
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return parseLivePage(try SwiftSoup.parse(html))
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "PCS live page: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// Never throws: a page it can't read gives `nil`, a part it can't read is left empty.
    /// `ul.situ5b` (the groups on the road) is empty before the start, and its markup while the
    /// race runs is not verified against a real page, so `liveGroups` is best-effort.
    static func parseLivePage(_ document: Document) -> DTO.LivePage? {
        guard (try? document.select("ul.ls5b-kpi, ul.timeline3, ul.situ5b").first()) != nil else {
            return nil
        }
        let status = liveAttribute(try? document.select("ul.ls5b-kpi").first(), "data-status")
        return DTO.LivePage(
            stats: liveStats(document),
            status: status.isEmpty
                ? liveText(try? document.select(".race_status").first())
                : status,
            profile: liveProfile(document),
            groups: liveGroups(document),
            events: liveEvents(document)
        )
    }

    /// `ul.ls5b-kpi > li`: the label is the `span`, the value the `div` text (or its `data-value`),
    /// the key the div's first class. The `Finish+` stat is left out until the race has finished.
    private static func liveStats(_ document: Document) -> [DTO.LivePage.Stat] {
        let items = (try? document.select("ul.ls5b-kpi > li").array()) ?? []
        var stats: [DTO.LivePage.Stat] = []
        for item in items {
            let label = liveText(try? item.select("span").first())
            let valueElement = try? item.select("div").first()
            var value = liveText(valueElement)
            if value.isEmpty {
                value = liveAttribute(valueElement, "data-value")
            }
            guard !label.isEmpty, !value.isEmpty else {
                continue
            }
            if item.hasClass("since_finish"), value == "0:00:00" {
                continue
            }
            stats.append(
                DTO.LivePage.Stat(
                    key: liveFirstClass(valueElement),
                    label: label,
                    value: value
                )
            )
        }
        return stats
    }

    /// The first `.bigProfile` only. Its `.xyProfile` is a clip-path polygon: `0 100%`, the profile
    /// points (x and y in percent, y counted from the top), then the closing `100% 0, 0 0`.
    /// Height is 1 - y, so a summit has the largest value.
    private static func liveProfile(_ document: Document) -> DTO.LivePage.Profile? {
        guard let profile = try? document.select(".bigProfile").first() else {
            return nil
        }
        let points = livePolygonPoints(
            liveAttribute(try? profile.select(".xyProfile").first(), "style")
        )
        guard !points.isEmpty else {
            return nil
        }
        let width = liveStyleNumber(
            liveAttribute(try? profile.select(".kmdone.profilePerc").first(), "style"),
            property: "width"
        ) ?? 0
        return DTO.LivePage.Profile(
            points: points,
            progress: min(max(width, 0), 100) / 100,
            elevationLabels: ((try? profile.select(".hoogteTitle span").array()) ?? [])
                .map { liveText($0) },
            keypoints: liveKeypoints(profile)
        )
    }

    /// The `clip-path: polygon(...)` pairs without the first point and the two closing corners.
    private static func livePolygonPoints(_ style: String) -> [DTO.LivePage.Profile.Point] {
        guard let start = style.range(of: "polygon("),
              let end = style[start.upperBound...].firstIndex(of: ")")
        else {
            return []
        }
        let pairs = style[start.upperBound..<end]
            .split(separator: ",", omittingEmptySubsequences: false)
            .dropFirst()
            .dropLast(2)
        return pairs.compactMap { pair -> DTO.LivePage.Profile.Point? in
            let parts = pair.split(whereSeparator: \.isWhitespace)
            guard parts.count == 2,
                  let x = liveNumber(parts[0]),
                  let y = liveNumber(parts[1])
            else {
                return nil
            }
            return DTO.LivePage.Profile.Point(
                x: min(max(x, 0), 100) / 100,
                y: 1 - min(max(y, 0), 100) / 100
            )
        }
    }

    /// `.kp5_cont`: `left` is the x position in percent, `data-type` the kind ("1" climb, "2" sprint).
    private static func liveKeypoints(_ profile: Element) -> [DTO.LivePage.Profile.Keypoint] {
        let items = (try? profile.select(".kp5_cont").array()) ?? []
        return items.compactMap { item -> DTO.LivePage.Profile.Keypoint? in
            guard let left = liveStyleNumber(liveAttribute(item, "style"), property: "left") else {
                return nil
            }
            let name = liveKeypointName(item)
            guard !name.isEmpty else {
                return nil
            }
            return DTO.LivePage.Profile.Keypoint(
                x: min(max(left, 0), 100) / 100,
                name: name,
                type: liveAttribute(item, "data-type")
            )
        }
    }

    /// The title's text before its `<br />`: "Ampang" of "Ampang<br />3.4km à 4%".
    private static func liveKeypointName(_ item: Element) -> String {
        guard let title = try? item.select(".keypointTitle").first(),
              let html = try? title.html()
        else {
            return ""
        }
        let name = html.components(separatedBy: "<br").first ?? ""
        return liveCollapsed((try? SwiftSoup.parse(name).text()) ?? "")
    }

    /// `ul.situ5b > li`, best-effort (not verified against a racing page). The round badge is the
    /// first `.bol`; the name is the first heading-like element with text, else PELOTON for "P";
    /// the gap is the first short element that starts with "+" or has a gap/time class; the riders
    /// are the `a[href*=rider/]` links, each with the nearest flag and bib read just before it.
    private static func liveGroups(_ document: Document) -> [DTO.LivePage.Group] {
        let items = (try? document.select("ul.situ5b > li").array()) ?? []
        return items.compactMap { item -> DTO.LivePage.Group? in
            let badge = liveText(try? item.select(".bol").first())
            let riders = liveRiders(item)
            guard !badge.isEmpty || !riders.isEmpty else {
                return nil
            }
            let heading = ((try? item.select("h3, h4, .title, .name, span.group").array()) ?? [])
                .map { liveText($0) }
                .first(where: { !$0.isEmpty })
            let fallback = badge == "P" ? "PELOTON" : (badge.isEmpty ? "GROUP" : "GROUP \(badge)")
            return DTO.LivePage.Group(
                name: heading ?? fallback,
                gap: liveGap(item),
                badge: badge,
                riders: riders
            )
        }
    }

    private static func liveGap(_ item: Element) -> String {
        for element in (try? item.select("*").array()) ?? [] {
            let text = liveText(element)
            let className = (try? element.className()) ?? ""
            let isGapClass = className.contains("gap") || className.contains("time")
            if !text.isEmpty, text.count <= 12, text.hasPrefix("+") || isGapClass {
                return text
            }
        }
        return ""
    }

    /// Scans the group's flags, rider links and bibs in document order: a bib (`.bib` or a cell
    /// that is only digits) and a flag count for the next rider link, then reset.
    private static func liveRiders(_ item: Element) -> [DTO.LivePage.Group.Rider] {
        let elements = (try? item.select("span.flag, a[href*=rider/], td, .bib").array()) ?? []
        var riders: [DTO.LivePage.Group.Rider] = []
        var countryCode = ""
        var bib = ""
        for element in elements {
            if element.tagName() == "a" {
                let name = liveText(element)
                if !name.isEmpty {
                    riders.append(
                        DTO.LivePage.Group.Rider(
                            bib: bib,
                            name: name,
                            countryCode: countryCode
                        )
                    )
                }
                countryCode = ""
                bib = ""
            } else if element.tagName() == "span", element.hasClass("flag") {
                countryCode = liveCountryCode(element)
            } else {
                let text = liveText(element)
                if !text.isEmpty, text.allSatisfy(\.isNumber) {
                    bib = text
                }
            }
        }
        return riders
    }

    /// The flag's second class ("flag it" gives "it"), as `parseRaceResultRows` reads it.
    private static func liveCountryCode(_ flag: Element) -> String {
        let classes = ((try? flag.className()) ?? "")
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        return classes.first(where: { $0.lowercased() != "flag" }) ?? ""
    }

    /// `ul.timeline3 > li.event`, newest first as PCS lists them. Events without text are skipped.
    private static func liveEvents(_ document: Document) -> [DTO.LivePage.Event] {
        let items = (try? document.select("ul.timeline3 > li.event").array()) ?? []
        var events: [DTO.LivePage.Event] = []
        for (index, item) in items.enumerated() {
            let text = liveText(try? item.select("div.textCont").first())
            guard !text.isEmpty else {
                continue
            }
            let uid = liveAttribute(item, "data-uid")
            let seconds = Double(liveAttribute(try? item.select("div.timeago2").first(), "data-ts")) ?? 0
            let table = try? item.select("div.chartCont table").first()
            events.append(
                DTO.LivePage.Event(
                    id: uid.isEmpty ? "\(index)" : uid,
                    badge: liveText(try? item.select("div.bol").first()),
                    text: text,
                    timestamp: seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil,
                    header: table.map { liveCells(in: $0, selector: "thead th") } ?? [],
                    rows: table.map { liveRows(in: $0) } ?? []
                )
            )
        }
        return events
    }

    private static func liveRows(in table: Element) -> [[String]] {
        ((try? table.select("tbody tr").array()) ?? [])
            .prefix(liveEventRowLimit)
            .map { liveCells(in: $0, selector: "td") }
            .filter { !$0.isEmpty }
    }

    private static func liveCells(
        in element: Element,
        selector: String
    ) -> [String] {
        ((try? element.select(selector).array()) ?? [])
            .prefix(liveEventColumnLimit)
            .map { liveText($0) }
    }

    /// The `left` / `width` value of a style attribute, in percent (no unit), `nil` when absent.
    private static func liveStyleNumber(
        _ style: String,
        property: String
    ) -> Double? {
        guard let match = style.range(
            of: "(^|;)\\s*\(property):\\s*-?[0-9.]+%?",
            options: .regularExpression
        ) else {
            return nil
        }
        let value = style[match].components(separatedBy: ":").last ?? ""
        return Double(value.trimmingCharacters(in: CharacterSet(charactersIn: " %")))
    }

    private static func liveNumber(_ text: Substring) -> Double? {
        Double(text.replacingOccurrences(of: "%", with: ""))
    }

    private static func liveFirstClass(_ element: Element?) -> String {
        guard let element = element, let names = try? element.className() else {
            return ""
        }
        return names.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    private static func liveAttribute(
        _ element: Element?,
        _ name: String
    ) -> String {
        guard let element = element else {
            return ""
        }
        return liveCollapsed((try? element.attr(name)) ?? "")
    }

    private static func liveText(_ element: Element?) -> String {
        guard let element = element else {
            return ""
        }
        return liveCollapsed((try? element.text()) ?? "")
    }

    private static func liveCollapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
