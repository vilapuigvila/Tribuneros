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
              let document = await directoryDocument(
                  baseStringURL + path,
                  ttl: 60 * 60 * 12
              )
        else {
            return nil
        }
        return parsePCSTeamPage(document)
    }

    private static func directoryDocument(
        _ url: String,
        ttl: TimeInterval = 60 * 60 * 48 // 2 days
    ) async -> Document? {
        do {
            let (data, _) = try await Requester
                .makeRequest(url)
                .ttl(ttl)
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

    /// Header, KPIs, info, links, roster, victories, results, staff and related teams; every part is empty when its markup is missing.
    static func parsePCSTeamPage(_ document: Document) -> DTO.PCSTeamPage {
        let (name, classCode) = teamHeader(document)
        return DTO.PCSTeamPage(
            name: name,
            classCode: classCode,
            season: teamSeason(document),
            kpis: teamKPIs(document),
            info: teamInfo(document),
            links: teamLinks(document),
            riders: teamRiders(document),
            victories: teamVictories(document),
            topResults: teamTopResults(document),
            staff: teamStaff(document),
            relatedTeams: teamRelated(document)
        )
    }

    private static func cleanText(_ element: Element?) -> String {
        let text = (try? element?.text()) ?? ""
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func intValue(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespaces))
    }

    private static func heading(_ document: Document, _ title: String) -> Element? {
        (try? document.select("h4").array())?.first { cleanText($0) == title }
    }

    private static func teamTableRows(after title: String, in document: Document) -> [[Element]] {
        guard let table = try? heading(document, title)?.nextElementSibling(),
              table.tagName() == "table",
              let rows = try? table.select("tbody > tr").array()
        else {
            return []
        }
        return rows.compactMap { try? $0.select("td").array() }
    }

    private static func teamHeader(_ document: Document) -> (String, String) {
        guard let h1 = try? document.select("h1").first() else { return ("", "") }
        let code = cleanText(try? h1.select("span").first()).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let full = cleanText(h1)
        let name = code.isEmpty ? full : String(full.dropLast(code.count + 2)).trimmingCharacters(in: .whitespaces)
        return (name, code)
    }

    private static func teamSeason(_ document: Document) -> Int? {
        let text = cleanText(try? document.select(".subtitle h2").first())
        return intValue(String(text.prefix(4)))
    }

    private static func teamKPIs(_ document: Document) -> DTO.PCSTeamKPIs {
        var kpis = DTO.PCSTeamKPIs()
        for item in (try? document.select("ul.teamkpi li").array()) ?? [] {
            let value = intValue(cleanText(try? item.select("div.value").first()))
            switch cleanText(try? item.select("div.title").first()) {
            case "Victories": kpis.victories = value
            case "Points": kpis.points = value
            case "PCS#": kpis.pcsRank = value
            case "UCI#": kpis.uciRank = value
            case "Incoming": kpis.incoming = value
            case "Outgoing": kpis.outgoing = value
            default: break
            }
        }
        return kpis
    }

    private static func teamInfo(_ document: Document) -> DTO.PCSTeamInfo {
        var info = DTO.PCSTeamInfo()
        guard let list = try? heading(document, "Info")?.nextElementSibling(),
              let items = try? list.select("li").array()
        else {
            return info
        }
        for item in items {
            let label = cleanText(try? item.select("div.title").first()).trimmingCharacters(in: CharacterSet(charactersIn: ": "))
            guard let value = try? item.select("div.value").first() else { continue }
            let text = cleanText(value)
            let nonEmpty = (text.isEmpty || text == "-") ? nil : text
            switch label {
            case "Team status": info.status = nonEmpty
            case "Abbreviation": info.abbreviation = nonEmpty
            case "License country": info.licenseCountry = nonEmpty
            case "Bike": info.bike = nonEmpty
            case "Jersey":
                if let src = try? value.select("img").first()?.attr("src"), !src.isEmpty {
                    info.jerseyURL = pcsAbsoluteURL(src)
                }
            default: break
            }
        }
        return info
    }

    private static func teamLinks(_ document: Document) -> [DTO.PCSTeamLink] {
        guard let list = try? heading(document, "Info")?.parent()?.nextElementSibling(),
              let anchors = try? list.select("a[target=_blank]").array()
        else {
            return []
        }
        return anchors.compactMap { anchor in
            guard let href = try? anchor.attr("href"),
                  let url = URL(string: href),
                  url.scheme?.hasPrefix("http") == true
            else {
                return nil
            }
            let kind = cleanText(anchor)
            return kind.isEmpty ? nil : DTO.PCSTeamLink(kind: kind, url: url)
        }
    }

    private static func teamRiders(_ document: Document) -> [DTO.PCSTeamRider] {
        var photos: [String: URL] = [:]
        for item in (try? document.select("ul.photos li").array()) ?? [] {
            if let href = try? item.select("a[href^=rider/]").first()?.attr("href"),
               let src = try? item.select("img").first()?.attr("src"),
               !src.isEmpty {
                photos[href] = pcsAbsoluteURL(src)
            }
        }
        let tables = (try? document.select("table.teamlist").array()) ?? []
        guard let table = tables.first(where: { cleanText(try? $0.select("th").last()) == "points" }),
              let rows = try? table.select("tbody > tr").array()
        else {
            return []
        }
        return rows.compactMap { row in
            guard let cells = try? row.select("td").array(), cells.count >= 4,
                  let link = try? cells[1].select("a[href^=rider/]").first(),
                  let href = try? link.attr("href")
            else {
                return nil
            }
            return DTO.PCSTeamRider(
                path: href,
                name: cleanText(link),
                countryCode: spanFlagCode(in: cells[1]) ?? "",
                rank: intValue(cleanText(cells[2])),
                points: intValue(cleanText(cells[3])),
                photoURL: photos[href]
            )
        }
    }

    private static func teamVictories(_ document: Document) -> [DTO.PCSTeamVictory] {
        teamTableRows(after: "Last victories", in: document).compactMap { cells in
            guard cells.count >= 4,
                  let race = try? cells[1].select("a[href^=race/]").first(),
                  let rider = try? cells[3].select("a[href^=rider/]").first()
            else {
                return nil
            }
            return DTO.PCSTeamVictory(
                racePath: (try? race.attr("href")) ?? "",
                raceName: cleanText(race),
                raceClass: cleanText(cells[2]),
                countryCode: spanFlagCode(in: cells[1]) ?? "",
                riderPath: (try? rider.attr("href")) ?? "",
                riderName: cleanText(rider)
            )
        }
    }

    private static func teamTopResults(_ document: Document) -> [DTO.PCSTeamResult] {
        teamTableRows(after: "Top results", in: document).compactMap { cells in
            guard cells.count >= 5,
                  let race = try? cells[1].select("a[href^=race/]").first(),
                  let rider = try? cells[3].select("a[href^=rider/]").first()
            else {
                return nil
            }
            return DTO.PCSTeamResult(
                position: intValue(cleanText(cells[0])),
                racePath: (try? race.attr("href")) ?? "",
                raceName: cleanText(race),
                raceClass: cleanText(cells[2]),
                countryCode: spanFlagCode(in: cells[1]) ?? "",
                riderPath: (try? rider.attr("href")) ?? "",
                riderName: cleanText(rider),
                points: intValue(cleanText(cells[4]))
            )
        }
    }

    private static func teamStaff(_ document: Document) -> [DTO.PCSTeamStaff] {
        teamTableRows(after: "Staff", in: document).compactMap { cells in
            guard cells.count >= 2,
                  let link = try? cells[0].select("a[href^=staff/]").first()
            else {
                return nil
            }
            return DTO.PCSTeamStaff(
                path: (try? link.attr("href")) ?? "",
                name: cleanText(link),
                function: cleanText(cells[1]),
                countryCode: spanFlagCode(in: cells[0]) ?? ""
            )
        }
    }

    /// The `ul.list` after the "Related teams" `h4`: each `li` holds a team link "Name (CLASS)" and a `div.fs12` relation.
    private static func teamRelated(_ document: Document) -> [DTO.PCSRelatedTeam] {
        guard let heading = heading(document, "Related teams"),
              let list = try? heading.nextElementSibling(),
              list.tagName() == "ul",
              let items = try? list.select("li").array()
        else {
            return []
        }
        return items.compactMap { item -> DTO.PCSRelatedTeam? in
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
