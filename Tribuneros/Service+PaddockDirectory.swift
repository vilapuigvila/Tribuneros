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
    private static let womenRacesCalendarURL = baseStringURL + "races.php?circuit=24"
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

    /// UCI Women's WorldTour (circuit 24), same markup as the men's list. `nil` when the page can't be fetched; `[]` when nothing parsed.
    static func getPCSWomenRaces() async -> [DTO.PCSRace]? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.womenRaces()
        }
        #endif
        guard let document = await directoryDocument(womenRacesCalendarURL) else { return nil }
        let races = parsePCSRaces(document)
        nonFatalCrashlytics(!races.isEmpty, "PCS races.php?circuit=24: no race rows parsed")
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

    /// One team's page, on demand. `nil` when the page can't be fetched or `path` isn't a `team/…` path.
    static func getPCSTeamPage(path: String) async -> DTO.PCSTeamPage? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.teamPage(path: path)
        }
        #endif
        guard path.hasPrefix("team/"),
              !path.contains(".."),
              let document = await directoryDocument(baseStringURL + path)
        else {
            return nil
        }
        return parsePCSTeamPage(document)
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

    /// Rows are date, start date, race (flag + link), winner and UCI class. A race listed twice keeps its first row.
    static func parsePCSRaces(_ document: Document) -> [DTO.PCSRace] {
        guard let rows = try? document.select("table.basic > tbody > tr").array() else { return [] }
        var seen = Set<String>()
        return rows.compactMap { row -> DTO.PCSRace? in
            guard let cells = try? row.select("td").array(), cells.count >= 5,
                  let link = try? cells[2].select("a[href^=race/]").first(),
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
                raceClass: ((try? cells[4].text()) ?? "").trimmingCharacters(in: .whitespaces),
                countryCode: spanFlagCode(in: cells[2]) ?? ""
            )
        }
    }

    /// "race/tour-down-under-2027-gc" and "...-result" name the same race: keep "race/<slug>-<year>".
    private static func racePath(_ href: String) -> String {
        for suffix in ["-gc", "-result"] where href.hasSuffix(suffix) {
            return String(href.dropLast(suffix.count))
        }
        return href
    }

    /// The flag sits in a `<div>` around the link; only the link's own parent is searched, so a wider one can't lend a flag.
    private static func flagCode(besideTeamLink link: Element) -> String? {
        guard let parent = link.parent(),
              ["li", "td", "div"].contains(parent.tagName())
        else {
            return nil
        }
        return spanFlagCode(in: parent)
    }

    /// The `ul.list` after the "Related teams" `h4`: each `li` holds a team link "Name (CLASS)" and a `div.fs12` relation.
    static func parsePCSTeamPage(_ document: Document) -> DTO.PCSTeamPage {
        guard let heading = try? document.select("h4").array().first(where: {
                  ((try? $0.text()) ?? "").trimmingCharacters(in: .whitespaces) == "Related teams"
              }),
              let list = try? heading.nextElementSibling(),
              list.tagName() == "ul",
              let items = try? list.select("li").array()
        else {
            return DTO.PCSTeamPage(relatedTeams: [])
        }
        let related = items.compactMap { item -> DTO.PCSRelatedTeam? in
            guard let link = try? item.select("a[href^=team/]").first(),
                  let href = try? link.attr("href"),
                  let text = try? link.text().trimmingCharacters(in: .whitespaces),
                  !text.isEmpty
            else {
                return nil
            }
            let (name, classCode) = splitClassSuffix(text)
            return DTO.PCSRelatedTeam(
                path: href,
                name: name,
                classCode: classCode,
                relation: ((try? item.select("div.fs12").first()?.text()) ?? "").trimmingCharacters(in: .whitespaces)
            )
        }
        return DTO.PCSTeamPage(relatedTeams: related)
    }

    /// "Fenix-Premier Tech (WTW)" → ("Fenix-Premier Tech", "WTW").
    private static func splitClassSuffix(_ text: String) -> (String, String) {
        guard text.hasSuffix(")"), let open = text.lastIndex(of: "(") else { return (text, "") }
        let code = text[text.index(after: open)..<text.index(before: text.endIndex)]
        let name = text[..<open].trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? (text, "") : (name, String(code))
    }

    /// Walks `h4` headings and the team links of the page's `ul.list` lists in page order (the menu's links are
    /// in a plain `ul`): a heading names the division of the links after it.
    static func parsePCSTeams(_ document: Document) -> [DTO.PCSTeam] {
        guard let elements = try? document.select("h4, ul.list li a[href^=team/]").array() else { return [] }
        var division = ""
        var seen = Set<String>()
        var teams: [DTO.PCSTeam] = []
        for element in elements {
            if element.tagName() == "h4" {
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
