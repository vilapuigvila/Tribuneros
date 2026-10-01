//
//  Service+RaceResult.swift
//  Tribuneros
//
//  The PCS race result page behind `RaceFinishedDetailView`: fetched on demand, cached a day.
//

import Foundation
import Alfy
import SwiftSoup

extension Service {
    static let raceResultRowLimit = 10

    /// Fetches and parses a PCS race result page (1-day cache); `nil` when it can't be loaded.
    static func getCachedRaceResultPage(url: URL) async -> DTO.RaceResultPage? {
        do {
            let (data, _) = try await Requester
                .makeRequest(url.absoluteString)
                .ttl(86400) // 1 day
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return parseRaceResultPage(try SwiftSoup.parse(html))
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "PCS race result page: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// Best-effort, and unverified against a live page: PCS is behind a Cloudflare challenge, so
    /// no real result page could be captured when this was written (see CLAUDE.md). It keys on
    /// the `table.results` class and on the header texts (Rnk / Rider / Team / Time), falling
    /// back to rider/team links when the header is missing. Rows without a numeric rank (DNF,
    /// OTL...) are skipped. Never throws: a page it can't read gives no rows.
    static func parseRaceResultPage(
        _ document: Document,
        limit: Int = Service.raceResultRowLimit
    ) -> DTO.RaceResultPage {
        let info = parseRaceResultInfo(document)
        let rows: [DTO.RaceResultPage.Row]
        if let table = raceResultTable(document) {
            rows = parseRaceResultRows(
                table,
                limit: limit
            )
            nonFatalCrashlytics(!rows.isEmpty, "PCS race result page: table.results has no ranked rows")
        } else {
            nonFatalCrashlytics(false, "PCS race result page: no table.results")
            rows = []
        }
        return DTO.RaceResultPage(
            stage: info.stage,
            from: info.from,
            to: info.to,
            distance: info.distance,
            rows: rows
        )
    }

    /// A stage page holds one `div.resTab` per classification and hides all but the current one,
    /// so the first visible tab's table is this page's result.
    private static func raceResultTable(_ document: Document) -> Element? {
        let tabs = (try? document.select("div.resTab").array()) ?? []
        for tab in tabs where !tab.hasClass("hide") {
            if let table = try? tab.select("table.results").first() {
                return table
            }
        }
        return try? document.select("table.results").first()
    }

    static func parseRaceResultRows(
        _ table: Element,
        limit: Int
    ) -> [DTO.RaceResultPage.Row] {
        let headers = ((try? table.select("thead th").array()) ?? [])
            .map { raceResultText($0).lowercased() }
        let columns = RaceResultColumns(headers: headers)
        let rows = (try? table.select("tbody > tr").array()) ?? []

        var result: [DTO.RaceResultPage.Row] = []
        for row in rows {
            guard result.count < limit else { break }
            let cells = row.children().array().filter { $0.tagName() == "td" }
            guard !cells.isEmpty else { continue }

            let rankIndex = columns.rank ?? 0
            let riderIndex = columns.rider ?? cells.firstIndex(where: { hasLink($0, containing: "rider/") })
            let teamIndex = columns.team ?? cells.firstIndex(where: { hasLink($0, containing: "team/") })
            let timeIndex = columns.time ?? cells.lastIndex(where: { $0.hasClass("time") }) ?? cells.count - 1

            guard cells.indices.contains(rankIndex),
                  let riderIndex,
                  cells.indices.contains(riderIndex)
            else {
                continue
            }
            let position = raceResultText(cells[rankIndex])
            guard Int(position) != nil else { continue }

            let riderCell = cells[riderIndex]
            let riderLink = try? riderCell.select("a[href*=rider/]").first()
            let name = raceResultText(riderLink ?? riderCell)
            guard !name.isEmpty else { continue }

            let team: String = {
                guard let teamIndex, cells.indices.contains(teamIndex) else { return "" }
                let cell = cells[teamIndex]
                let link = try? cell.select("a").first()
                return raceResultText(link ?? cell)
            }()
            let time = cells.indices.contains(timeIndex) ? raceResultTime(cells[timeIndex]) : ""

            result.append(
                DTO.RaceResultPage.Row(
                    position: position,
                    name: name,
                    team: team,
                    time: time
                )
            )
        }
        return result
    }

    /// The race facts list ("Departure:", "Arrival:", "Distance:") as `li > div` pairs, the same
    /// shape `getNextToFinishRaceDetail` reads, and "Stage 3" / "Prologue" from the page title.
    private static func parseRaceResultInfo(_ document: Document) -> (stage: String?, from: String?, to: String?, distance: String?) {
        var from: String?
        var to: String?
        var distance: String?
        for item in (try? document.select("li").array()) ?? [] {
            let divs = item.children().array().filter { $0.tagName() == "div" }
            guard divs.count >= 2 else { continue }
            let key = raceResultText(divs[0]).lowercased()
            let value = raceResultText(divs[1])
            guard !value.isEmpty else { continue }
            if key.hasPrefix("departure"), from == nil {
                from = value
            } else if key.hasPrefix("arrival"), to == nil {
                to = value
            } else if key.hasPrefix("distance"), distance == nil {
                distance = value.replacingOccurrences(of: " ", with: "")
            }
        }

        let titleText = ((try? document.select(".page-title, h1, h2").array()) ?? [])
            .map { raceResultText($0) }
            .joined(separator: " ")
        let stage = titleText
            .range(of: "\\b(Stage [0-9]+[a-z]?|Prologue)\\b", options: .regularExpression)
            .map { String(titleText[$0]) }

        return (stage, from, to, distance)
    }

    /// The visible time: PCS can repeat the absolute time in a hidden `span.hide` next to a gap.
    private static func raceResultTime(_ cell: Element) -> String {
        let ownText = cell.ownText()
        let visible = [ownText] + cell.children().array()
            .filter { !$0.hasClass("hide") }
            .map { raceResultText($0) }
        let text = raceResultCollapsed(visible.joined(separator: " "))
        return text.isEmpty ? raceResultText(cell) : text
    }

    private static func hasLink(
        _ cell: Element,
        containing path: String
    ) -> Bool {
        (try? cell.select("a[href*=\(path)]").first()) != nil
    }

    private static func raceResultText(_ element: Element) -> String {
        raceResultCollapsed((try? element.text()) ?? "")
    }

    private static func raceResultCollapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Column indices read from the results table header; `nil` when PCS didn't label one.
private struct RaceResultColumns {
    let rank: Int?
    let rider: Int?
    let team: Int?
    let time: Int?

    init(headers: [String]) {
        rank = headers.firstIndex { ["rnk", "pos", "#", "rank"].contains($0) }
        rider = headers.firstIndex(of: "rider")
        team = headers.firstIndex(of: "team")
        time = headers.firstIndex(of: "time") ?? headers.firstIndex { $0.contains("time") }
    }
}
