//
//  Service+Previews.swift
//  Tribuneros
//
//  The homepage "Previews" list (shown while Results today is empty) and the pre-race state of
//  the race's PCS LiveStats page behind `HomeRaces.RacePreview`.
//

import Foundation
import Alfy
import SwiftSoup

extension Service {
    private static let previewFactRowLimit = 5
    private static let previewFactColumnLimit = 4
    private static let previewFactLimit = 8

    /// Anchors on the "Previews" `h4`; `[]` when the section is missing or empty.
    static func parsePreviews(from document: Document) -> [DTO.Preview] {
        guard let heading = try? document.select("h4:contains(Previews)").first(),
              let list = try? heading.nextElementSibling(),
              list.tagName() == "ul",
              let items = try? list.select("li")
        else {
            return []
        }
        return items.compactMap { item in
            guard let link = try? item.select("div.name a").first(),
                  let href = try? link.attr("href"),
                  let name = try? link.text(),
                  !name.isEmpty,
                  !href.isEmpty
            else {
                return nil
            }
            return DTO.Preview(
                countdown: collapsed((try? item.select("div.days").first()?.text()) ?? ""),
                name: collapsed(name),
                url: pcsAbsoluteURL(href)
            )
        }
    }

    /// Fetches and parses a race's LiveStats page (10 min cache); `nil` when it can't be loaded.
    static func getPreviewPage(url: URL) async -> DTO.PreviewPage? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return HomeRaces.MockScenario.previewPage(for: url)
        }
        #endif
        do {
            let (data, _) = try await Requester
                .makeRequest(url.absoluteString)
                .ttl(600) // 10 minutes
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return parsePreviewPage(try SwiftSoup.parse(html))
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "PCS preview page: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// Never throws: a page it can't read gives `nil`, a part it can't read is left empty.
    static func parsePreviewPage(_ document: Document) -> DTO.PreviewPage? {
        guard (try? document.select("ul.ls5b-kpi, table.keypoints, li.event").first()) != nil else {
            return nil
        }
        let reds = (try? document.select(".title-line2 font.red").array()) ?? []
        let route = reds.first.flatMap { try? $0.text() }.map(collapsed) ?? ""
        let places = route
            .components(separatedBy: "›")
            .map { collapsed($0) }
            .filter { !$0.isEmpty }
        let distance = reds.dropFirst().first
            .flatMap { try? $0.text() }
            .map { collapsed($0).trimmingCharacters(in: CharacterSet(charactersIn: "()")) }
        let stage = (try? document.select(".title-line2 font.blue").first()?.text()).map(collapsed)
        return DTO.PreviewPage(
            stage: stage?.isEmpty == false ? stage : nil,
            from: places.first,
            to: places.count > 1 ? places.last : nil,
            distance: distance?.isEmpty == false ? distance : nil,
            start: previewValue(document, selector: ".ls5b-kpi .starttime"),
            startCET: previewValue(document, selector: ".ls5b-kpi .starttime_cet"),
            keypoints: parsePreviewKeypoints(document),
            facts: parsePreviewFacts(document)
        )
    }

    private static func previewValue(
        _ document: Document,
        selector: String
    ) -> String? {
        let value = (try? document.select(selector).first()?.text()).map(collapsed)
        return value?.isEmpty == false ? value : nil
    }

    private static func parsePreviewKeypoints(_ document: Document) -> [DTO.PreviewPage.Keypoint] {
        let rows = (try? document.select("table.keypoints tbody tr").array()) ?? []
        return rows.compactMap { row in
            guard let cells = try? row.select("td").array(),
                  cells.count >= 4,
                  let km = try? cells[0].text(),
                  let type = try? cells[2].text(),
                  let name = try? cells[3].text(),
                  !km.isEmpty,
                  !name.isEmpty
            else {
                return nil
            }
            return DTO.PreviewPage.Keypoint(
                km: collapsed(km),
                type: collapsed(type),
                name: collapsed(name)
            )
        }
    }

    /// Keeps the text cards and the ones with a table; drops the feed header, the PCS game promo
    /// and the cards whose content is a chart or profile rather than a table.
    private static func parsePreviewFacts(_ document: Document) -> [DTO.PreviewPage.Fact] {
        let stats = (try? document.select("li.event div.stat").array()) ?? []
        let facts: [DTO.PreviewPage.Fact] = stats.compactMap { stat in
            guard let text = (try? stat.select("div.textCont").first()?.text()).map(collapsed),
                  !text.isEmpty,
                  !text.hasPrefix("Welcome at the"),
                  !text.contains("PCS game")
            else {
                return nil
            }
            let hasChart = (try? stat.select("div.chartCont").first()) != nil
            guard let table = try? stat.select("div.chartCont table").first() else {
                return hasChart ? nil : DTO.PreviewPage.Fact(
                    text: text,
                    header: [],
                    rows: []
                )
            }
            let header = cells(
                in: table,
                selector: "thead th"
            )
            let rows = ((try? table.select("tbody tr").array()) ?? [])
                .prefix(previewFactRowLimit)
                .map { cells(in: $0, selector: "td") }
                .filter { !$0.isEmpty }
            guard !rows.isEmpty else {
                return nil
            }
            return DTO.PreviewPage.Fact(
                text: text,
                header: header,
                rows: rows
            )
        }
        return Array(facts.prefix(previewFactLimit))
    }

    private static func cells(
        in element: Element,
        selector: String
    ) -> [String] {
        ((try? element.select(selector).array()) ?? [])
            .prefix(previewFactColumnLimit)
            .map { collapsed((try? $0.text()) ?? "") }
    }

    private static func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
