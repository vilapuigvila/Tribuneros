//
//  Service+PaddockDirectory.swift
//  Tribuneros
//
//  Paddock's "Races" and "Teams" lists, scraped on the device from PCS's `races.php` and
//  `teams.php` (PCS stays on the device, see CLAUDE.md). Parsers return `[]` rather than
//  throwing, so a markup change gives an empty list, not a broken screen.
//

import Foundation
import SwiftSoup
import Alfy

extension Service {

    private static let racesCalendarURL = baseStringURL + "races.php"
    private static let teamsURL = baseStringURL + "teams.php"

    /// `nil` when the page can't be fetched; `[]` when it loaded but nothing parsed.
    static func getPCSRaces() async -> [DTO.PCSRace]? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.races()
        }
        #endif
        guard let document = await directoryDocument(racesCalendarURL) else { return nil }
        let races = parsePCSRaces(document)
        nonFatalCrashlytics(!races.isEmpty, "PCS races.php: no race rows parsed")
        return races
    }

    /// `nil` when the page can't be fetched; `[]` when it loaded but nothing parsed.
    static func getPCSTeams() async -> [DTO.PCSTeam]? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.teams()
        }
        #endif
        guard let document = await directoryDocument(teamsURL) else { return nil }
        let teams = parsePCSTeams(document)
        nonFatalCrashlytics(!teams.isEmpty, "PCS teams.php: no team links parsed")
        return teams
    }

    private static func directoryDocument(_ url: String) async -> Document? {
        do {
            let (data, _) = try await Requester
                .makeRequest(url)
                .ttl(60 * 60 * 48)
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return try SwiftSoup.parse(html)
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "PCS directory page: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// Rows are date, race (flag + link) and UCI class, like the "latest results" table on the
    /// same page. A race listed once per stage keeps its first row.
    static func parsePCSRaces(_ document: Document) -> [DTO.PCSRace] {
        guard let rows = try? document.select("table.basic > tbody > tr").array() else { return [] }
        var seen = Set<String>()
        return rows.compactMap { row -> DTO.PCSRace? in
            guard let cells = try? row.select("td").array(), cells.count >= 2,
                  let link = try? cells[1].select("a[href^=race/]").first(),
                  let href = try? link.attr("href"),
                  let name = try? link.text().trimmingCharacters(in: .whitespaces),
                  !name.isEmpty
            else {
                return nil
            }
            let path = racePath(href)
            guard seen.insert(path).inserted else { return nil }
            return DTO.PCSRace(
                path: path,
                name: name,
                dateText: ((try? cells[0].text()) ?? "").trimmingCharacters(in: .whitespaces),
                raceClass: cells.count > 2 ? ((try? cells[2].text()) ?? "") : "",
                countryCode: spanFlagCode(in: cells[1]) ?? ""
            )
        }
    }

    /// "race/tour-down-under/2027/stage-1" and ".../gc" are the same race: keep "race/<slug>/<year>".
    private static func racePath(_ href: String) -> String {
        let parts = href.split(separator: "/").map(String.init)
        guard parts.count > 3, parts[0] == "race", Int(parts[2]) != nil else { return href }
        return parts.prefix(3).joined(separator: "/")
    }

    /// The flag sits in the link's own list item or cell; a wider parent would give every team the first flag.
    private static func flagCode(besideTeamLink link: Element) -> String? {
        guard let parent = link.parent(),
              ["li", "td"].contains(parent.tagName())
        else {
            return nil
        }
        return spanFlagCode(in: parent)
    }

    /// Walks headings and team links in page order: a heading names the division of the links after it.
    static func parsePCSTeams(_ document: Document) -> [DTO.PCSTeam] {
        guard let elements = try? document.select("h2, h3, h4, a[href^=team/]").array() else { return [] }
        var division = ""
        var seen = Set<String>()
        var teams: [DTO.PCSTeam] = []
        for element in elements {
            if element.tagName().hasPrefix("h") {
                division = ((try? element.text()) ?? "").trimmingCharacters(in: .whitespaces)
                continue
            }
            guard let href = try? element.attr("href"),
                  let text = try? element.text().trimmingCharacters(in: .whitespaces),
                  !text.isEmpty,
                  seen.insert(href).inserted
            else {
                continue
            }
            teams.append(
                DTO.PCSTeam(
                    path: href,
                    name: text,
                    division: division,
                    countryCode: flagCode(besideTeamLink: element) ?? ""
                )
            )
        }
        return teams
    }
}
