//
//  Service+Transfers.swift
//  Tribuneros
//
//  Paddock's transfers, scraped on the device from PCS's `teams/transfers` (PCS stays on the device,
//  see CLAUDE.md). The parser returns `[]` rather than throwing, so a markup change gives an empty list.
//

import Foundation
import SwiftSoup
import Alfy

extension Service {

    private static let transfersURL = baseStringURL + "teams/transfers"

    /// The page's transfer rows as raw `<tr` strings (parsed 25 at a time by `parseTransferRows`); `nil` when the page can't be fetched.
    static func getPCSTransferRows() async -> [String]? {
        do {
            let (data, _) = try await Requester
                .makeRequest(transfersURL)
                .ttl(60 * 60 * 24)
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            let rows = splitTransferRows(html)
            nonFatalCrashlytics(!rows.isEmpty, "PCS teams/transfers: no transfer rows found")
            return rows.isEmpty ? nil : rows
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "PCS transfers page: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// The `<tr` strings of the body that follows the "Goes to" header.
    static func splitTransferRows(_ html: String) -> [String] {
        guard let header = html.range(of: "Goes to"),
              let bodyStart = html.range(of: "<tbody", range: header.upperBound..<html.endIndex),
              let bodyEnd = html.range(of: "</tbody>", range: bodyStart.upperBound..<html.endIndex)
        else {
            return []
        }
        return html[bodyStart.upperBound..<bodyEnd.lowerBound]
            .components(separatedBy: "<tr")
            .dropFirst()
            .map { "<tr" + $0 }
    }

    /// Parses `rows[range]` with the same per-row parser as `parsePCSTransfers`, skipping rows that don't parse.
    static func parseTransferRows(_ rows: [String], in range: Range<Int>) -> [DTO.Transfer] {
        let bounded = range.clamped(to: rows.startIndex..<rows.endIndex)
        let formatter = transferDateFormatter()
        return rows[bounded].compactMap { row in
            guard let element = try? SwiftSoup.parse("<table><tbody>\(row)</tbody></table>").select("tr").first() else {
                return nil
            }
            return parseTransferRow(element, formatter: formatter)
        }
    }

    static func parsePCSTransfers(_ document: Document) -> [DTO.Transfer] {
        let tables = (try? document.select("table.basic").array()) ?? []
        let table = tables.first { table in
            let headers = ((try? table.select("thead th").array()) ?? []).map { ((try? $0.text()) ?? "").trimmingCharacters(in: .whitespaces) }
            return headers.contains("Rider") && headers.contains("From") && headers.contains("Goes to")
        }
        guard let table, let rows = try? table.select("tbody tr") else {
            AppLogger.network.log("empty PCS transfers")
            return []
        }
        let formatter = transferDateFormatter()
        return rows.array().compactMap { parseTransferRow($0, formatter: formatter) }
    }

    private static func transferDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func parseTransferRow(_ row: Element, formatter: DateFormatter) -> DTO.Transfer? {
        let cells = (try? row.select("td").array()) ?? []
        guard cells.count >= 5,
              let rider = parseRiderLink(cells[1]),
              let date = formatter.date(from: ((try? cells[0].text()) ?? "").trimmingCharacters(in: .whitespaces)),
              let team = try? cells[3].select("a[href^=team/]").first()?.text(),
              !team.isEmpty
        else {
            return nil
        }
        let from = ((try? cells[2].select("a[href^=team/]").first()?.text()) ?? "").trimmingCharacters(in: .whitespaces)
        let season = ((try? cells[4].text()) ?? "").trimmingCharacters(in: .whitespaces)
        return DTO.Transfer(
            date: date,
            rider: rider,
            fromTeam: from.isEmpty ? nil : from,
            teamName: team,
            season: season.isEmpty ? nil : season
        )
    }
}
