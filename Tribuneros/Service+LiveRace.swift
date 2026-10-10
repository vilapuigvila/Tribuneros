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
    private static let kmAxisStep = 10.0
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

    /// Never throws: an unreadable page is `nil`, an unreadable part is left empty.
    static func parseLivePage(_ document: Document) -> DTO.LivePage? {
        guard (try? document.select("ul.ls5b-kpi, ul.timeline3, ul.situ5b, ul.situ7, .ProfileV10").first()) != nil else {
            return nil
        }
        return DTO.LivePage(
            stats: liveStats(document),
            status: liveStatus(document),
            profile: liveProfile(document),
            groups: liveGroups(document),
            events: liveEvents(document)
        )
    }

    /// `ul.ls5b-kpi[data-status]` on the preview, `div.race_status` on the racing page.
    private static func liveStatus(_ document: Document) -> String {
        let status = liveAttribute(try? document.select("ul.ls5b-kpi").first(), "data-status")
        guard status.isEmpty else {
            return status
        }
        let kpi = try? document.select(".race_status").first()
        let value = liveAttribute(kpi, "data-value")
        return value.isEmpty ? liveText(kpi) : value
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

    /// The first `.ProfileV10` or `.bigProfile`; height is 1 - y, y counted from the top.
    private static func liveProfile(_ document: Document) -> DTO.LivePage.Profile? {
        guard let profile = try? document.select(".ProfileV10, .bigProfile").first() else {
            return nil
        }
        let points = livePolygonPoints(
            liveAttribute(try? profile.select(".xyProfile, div[style*=clip-path]").first(), "style")
        )
        guard !points.isEmpty else {
            return nil
        }
        let width = liveStyleNumber(
            liveAttribute(try? profile.select(".kmdone.profilePerc, .profilePerc").first(), "style"),
            property: "width"
        ) ?? 0
        let routeKm = liveRouteKm(document)
        return DTO.LivePage.Profile(
            points: points,
            progress: min(max(width, 0), 100) / 100,
            elevationLabels: liveElevationLabels(profile),
            keypoints: liveKeypoints(profile, document),
            routeKm: routeKm,
            kmLabels: liveKmLabels(document, routeKm: routeKm)
        )
    }

    /// The preview's `.hoogteTitle` labels, else the racing page's `.altLine` labels.
    private static func liveElevationLabels(_ profile: Element) -> [String] {
        let preview = ((try? profile.select(".hoogteTitle span").array()) ?? []).map { liveText($0) }
        if !preview.isEmpty {
            return preview
        }
        return ((try? profile.select(".altLine .alt-text-left").array()) ?? []).map { liveText($0) }
    }

    /// Km to go plus km done from the KPI strip: the route's length, 239.4 km on the racing page.
    private static func liveRouteKm(_ document: Document) -> Double? {
        let toGo = Double(liveAttribute(try? document.select("ul.ls5b-kpi .kmtogo").first(), "data-value"))
        let done = Double(liveAttribute(try? document.select("ul.ls5b-kpi .kmdone").first(), "data-value"))
        guard let toGo, let done else {
            return nil
        }
        return toGo + done
    }

    /// Keeps the labels on the route, plus the 10 km step that reaches its end (240 for 239.4 km).
    private static func liveKmLabels(
        _ document: Document,
        routeKm: Double?
    ) -> [DTO.LivePage.Profile.KmLabel] {
        guard let routeKm, routeKm > 0,
              let axis = try? document.select("ul.kmbar3.hideIfMobile").first()
        else {
            return []
        }
        let items = (try? axis.select("li").array()) ?? []
        return items.compactMap { item -> DTO.LivePage.Profile.KmLabel? in
            guard let km = Int(liveText(item)), Double(km) - kmAxisStep < routeKm else {
                return nil
            }
            return DTO.LivePage.Profile.KmLabel(km: km, x: Double(km) / routeKm)
        }
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

    /// Preview: `.kp5_cont`. Racing: the first `.keypointsCont`, one `div` per marker.
    private static func liveKeypoints(
        _ profile: Element,
        _ document: Document
    ) -> [DTO.LivePage.Profile.Keypoint] {
        let preview = (try? profile.select(".kp5_cont").array()) ?? []
        if !preview.isEmpty {
            return preview.compactMap { item -> DTO.LivePage.Profile.Keypoint? in
                let type = liveAttribute(item, "data-type")
                let name = liveKeypointName(item)
                guard let x = liveKeypointX(item), !name.isEmpty else {
                    return nil
                }
                return DTO.LivePage.Profile.Keypoint(x: x, name: name, type: type, isClimb: type == "1")
            }
        }
        let markers = (try? document.select(".keypointsCont").first()?.children().array()) ?? []
        return markers.compactMap { marker -> DTO.LivePage.Profile.Keypoint? in
            guard let x = liveKeypointX(marker) else {
                return nil
            }
            let name = liveMarkerName(marker)
            guard !name.isEmpty else {
                return nil
            }
            let climbs = (try? marker.select(".kp_bol.climb").array()) ?? []
            return DTO.LivePage.Profile.Keypoint(x: x, name: name, type: "", isClimb: !climbs.isEmpty)
        }
    }

    private static func liveKeypointX(_ item: Element) -> Double? {
        guard let left = liveStyleNumber(liveAttribute(item, "style"), property: "left") else {
            return nil
        }
        return min(max(left, 0), 100) / 100
    }

    /// The first text the marker holds on its own: "Passo di Valcava" of "Passo di Valcava<br />…".
    private static func liveMarkerName(_ marker: Element) -> String {
        let elements = (try? marker.select("*").array()) ?? []
        let names = elements.map { liveCollapsed((try? $0.ownText()) ?? "") }
        return names.first(where: { !$0.isEmpty }) ?? ""
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

    /// The racing page's `ul.situ7 > li.group`; the preview's `ul.situ5b > li` when there is none.
    private static func liveGroups(_ document: Document) -> [DTO.LivePage.Group] {
        let racing = (try? document.select("ul.situ7 > li.group").array()) ?? []
        if !racing.isEmpty {
            return racing.compactMap { liveRacingGroup($0) }
        }
        return liveLegacyGroups(document)
    }

    /// `.time`'s own text is the gap, so the `??` font beside it is left out.
    private static func liveRacingGroup(_ item: Element) -> DTO.LivePage.Group? {
        let badge = liveText(try? item.select(".bol").first())
        let name = liveText(try? item.select(".groupname").first())
        let riders = liveRacingRiders(item)
        guard !badge.isEmpty || !name.isEmpty || !riders.isEmpty else {
            return nil
        }
        let time = try? item.select(".time").first()
        return DTO.LivePage.Group(
            name: name,
            gap: liveCollapsed(time.flatMap { try? $0.ownText() } ?? ""),
            gapSeconds: Int(liveAttribute(time, "data-sec")),
            badge: badge,
            isPeloton: liveAttribute(item, "data-peloton") == "1",
            riders: riders
        )
    }

    /// Each rider is a `li` under the group: place (`span.nr`), bib, the rider link and the flag.
    private static func liveRacingRiders(_ item: Element) -> [DTO.LivePage.Group.Rider] {
        let rows = (try? item.select("ul > li").array()) ?? []
        return rows.compactMap { row -> DTO.LivePage.Group.Rider? in
            let name = liveText(try? row.select("a[href*=rider/]").first())
            guard !name.isEmpty else {
                return nil
            }
            return DTO.LivePage.Group.Rider(
                position: Int(liveText(try? row.select("span.nr").first())),
                bib: liveText(try? row.select(".bib").first()),
                name: name,
                countryCode: liveCountryCode(try? row.select("span.flag").first())
            )
        }
    }

    /// `ul.situ5b > li` on the preview layout; only synthetic HTML covers it (no groups before the start).
    private static func liveLegacyGroups(_ document: Document) -> [DTO.LivePage.Group] {
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
                gapSeconds: nil,
                badge: badge,
                isPeloton: badge == "P",
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

    /// Preview rows: a bib and flag before each rider link, read in document order.
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
                            position: nil,
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

    /// The flag's two-letter class: "flag it" and "flag c16 it" both give "it".
    private static func liveCountryCode(_ flag: Element?) -> String {
        liveClasses(flag).first(where: { $0.count == 2 }) ?? ""
    }

    private static func liveClasses(_ element: Element?) -> [String] {
        guard let element, let names = try? element.className() else {
            return []
        }
        return names.split(whereSeparator: \.isWhitespace).map(String.init)
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
