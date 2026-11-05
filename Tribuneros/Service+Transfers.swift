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

    /// `nil` when the page can't be fetched (the caller falls back to the homepage list); `[]` when nothing parsed.
    static func getPCSTransfers() async -> [DTO.Transfer]? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.paddock().transfers
        }
        #endif
        do {
            let (data, _) = try await Requester
                .makeRequest(transfersURL)
                .ttl(60 * 60 * 24)
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            let transfers = parsePCSTransfers(try SwiftSoup.parse(html))
            nonFatalCrashlytics(!transfers.isEmpty, "PCS teams/transfers: no transfer rows parsed")
            return transfers.isEmpty ? nil : transfers
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "PCS transfers page: \(error.localizedDescription)")
            }
            return nil
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
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return rows.array().compactMap { row in
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
}
