//
//  Service+Paddock.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import Foundation
import SwiftSoup
import Alfy

extension Service {

    static func getPaddock() async throws -> DTO.Paddock {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.paddock()
        }
        #endif
        let document = try await getHomepageDocument()
        return DTO.Paddock(
            transfers: parseTransfers(document),
            programUpdates: parseProgramUpdates(document),
            birthdays: parseBirthdays(document)
        )
    }

    static func parseTransfers(_ document: Document) -> [DTO.Transfer] {
        guard let heading = try? document.select("h4:contains(Latest transfers)").first(),
              let list = try? heading.nextElementSibling(),
              list.hasClass("hp-transfers"),
              let items = try? list.select("li")
        else {
            AppLogger.network.log("empty latest transfers")
            return []
        }
        return items.array().compactMap { item in
            guard let rider = parseRiderLink(item),
                  let date = try? item.select("div.datum").first()?.text(),
                  let team = try? item.select("div.blue a").first()?.text(),
                  !team.isEmpty
            else {
                return nil
            }
            return DTO.Transfer(
                date: date,
                rider: rider,
                teamName: team
            )
        }
    }

    static func parseProgramUpdates(_ document: Document) -> [DTO.ProgramUpdate] {
        // The list sits in the block after the heading's wrapper div, not beside the h4.
        guard let heading = try? document.select("h4:contains(Recent top riders program updates)").first(),
              let block = try? heading.parent()?.nextElementSibling(),
              let items = try? block.select("ul.hp-list > li")
        else {
            AppLogger.network.log("empty program updates")
            return []
        }
        return items.array().compactMap { item in
            guard let rider = parseRiderLink(item),
                  let timeAgo = try? item.select("span.sl-upd-time-ago").first()?.text()
            else {
                return nil
            }
            // Each race is a span whose text is the signed code ("+ToG") and whose title is the full name.
            let changes: [DTO.ProgramUpdate.Change] = ((try? item.select("span[title]").array()) ?? []).compactMap { span in
                guard let code = try? span.text(),
                      let raceName = try? span.attr("title"),
                      !raceName.isEmpty
                else {
                    return nil
                }
                if code.hasPrefix("+") {
                    return .init(isAdded: true, raceName: raceName)
                }
                if code.hasPrefix("-") {
                    return .init(isAdded: false, raceName: raceName)
                }
                return nil
            }
            guard !changes.isEmpty else {
                return nil
            }
            return DTO.ProgramUpdate(
                timeAgo: timeAgo,
                rider: rider,
                changes: changes
            )
        }
    }

    static func parseBirthdays(_ document: Document) -> [DTO.Birthday] {
        guard let heading = try? document.select("h4:contains(Birthdays)").first(),
              let block = try? heading.parent()?.nextElementSibling(),
              let items = try? block.select("ul.list > li")
        else {
            AppLogger.network.log("empty birthdays")
            return []
        }
        return items.array().compactMap { item in
            guard let rider = parseRiderLink(item),
                  let age = try? item.select("div.bold").first()?.text(),
                  !age.isEmpty
            else {
                return nil
            }
            return DTO.Birthday(
                rider: rider,
                age: age
            )
        }
    }

    // MARK: - Rider page -

    /// Fetches and parses a PCS rider page on demand; `nil` when it can't be loaded or parsed.
    static func getPCSRiderPage(url: URL) async -> DTO.PCSRiderPage? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.riderPage(url: url)
        }
        #endif
        do {
            let (data, _) = try await Requester
                .makeRequest(url.absoluteString)
                .ttl(60 * 60 * 12)
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            return parsePCSRiderPage(try SwiftSoup.parse(html))
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "PCS rider page: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// Anchors on the real page's markup (see `pcs_rider.html`); every section degrades to `[]`
    /// when PCS changes it. The first lines keep the older loose fallbacks (synthetic HTML in `PaddockTests`).
    static func parsePCSRiderPage(_ document: Document) -> DTO.PCSRiderPage? {
        let name = collapsedWhitespace((try? document.select("h1").first()?.text()) ?? "")
        guard !name.isEmpty else {
            return nil
        }
        let imageSource = (try? document.select(".rdr-img-cont img, img[src*=images/riders/]").first()?.attr("src")) ?? ""
        let team = (try? document.select(".page-title a[href^=team/], .rdr-info-cont a[href^=team/], .page-title .subtitle h2").first()?.text())
            .map(collapsedWhitespace)
        let container = (try? document.select(".rdr-info-cont, div.lineh14").first()) ?? document.body()
        return DTO.PCSRiderPage(
            name: name,
            imageURL: imageSource.isEmpty ? nil : pcsAbsoluteURL(imageSource),
            team: team?.isEmpty == false ? team : nil,
            facts: container.map(parsePCSRiderFacts) ?? [],
            specialties: parseRiderSpecialties(document),
            keyStats: parseRiderKeyStats(document),
            topResults: parseRiderTopResults(document),
            teams: parseRiderTeams(document),
            program: parseRiderProgram(document),
            rankingBySeason: parseRiderRankings(document),
            seasonResults: parseRiderSeasonResults(document)
        )
    }

    private static func cellText(_ element: Element?) -> String {
        collapsedWhitespace(((try? element?.text()) ?? "").replacingOccurrences(of: "\u{00A0}", with: " "))
    }

    private static func parseRiderSpecialties(_ document: Document) -> [DTO.PCSRiderPage.Specialty] {
        ((try? document.select("ul.pps li").array()) ?? []).compactMap { item in
            let title = cellText(try? item.select(".xtitle").first())
            guard !title.isEmpty,
                  let points = Int(cellText(try? item.select(".xvalue").first()))
            else {
                return nil
            }
            return .init(title: title, points: points)
        }
    }

    private static func parseRiderKeyStats(_ document: Document) -> [DTO.PCSRiderPage.KeyStat] {
        ((try? document.select("ul.rider-kpi li").array()) ?? []).compactMap { item in
            let value = cellText(try? item.select(".kpi").first())
            let title = cellText(try? item.select(".title").first())
            guard !value.isEmpty, !title.isEmpty else {
                return nil
            }
            let detail = cellText(try? item.select(".info").first())
            return .init(
                value: value,
                title: title,
                detail: detail.isEmpty ? nil : detail
            )
        }
    }

    private static func parseRiderTopResults(_ document: Document) -> [DTO.PCSRiderPage.TopResult] {
        ((try? document.select("ul.topresults li").array()) ?? []).compactMap { item in
            let count = cellText(try? item.select(".nrs b").first())
            let race = cellText(try? item.select(".races a").first())
            guard !count.isEmpty, !race.isEmpty else {
                return nil
            }
            let kind = cellText(try? item.select(".races span.blue").first())
            let years = cellText(try? item.select(".races span.clr777").first())
                .trimmingCharacters(in: CharacterSet(charactersIn: "() "))
            return .init(
                count: count,
                kind: kind.isEmpty ? nil : kind,
                race: race,
                years: years.isEmpty ? nil : years
            )
        }
    }

    private static func parseRiderTeams(_ document: Document) -> [DTO.PCSRiderPage.TeamSeason] {
        ((try? document.select("ul.rdr-teams2 li.main").array()) ?? []).compactMap { item in
            let season = cellText(try? item.select(".season").first())
            let team = cellText(try? item.select(".name a").first())
            guard !season.isEmpty, !team.isEmpty else {
                return nil
            }
            let full = cellText(try? item.select(".name").first())
            let level = trailingParenthesis(in: full)
            return .init(
                season: season,
                team: team,
                level: level
            )
        }
    }

    /// "Tour de France (2.UWT)" gives "2.UWT".
    private static func trailingParenthesis(in text: String) -> String? {
        guard text.hasSuffix(")"),
              let open = text.lastIndex(of: "(")
        else {
            return nil
        }
        let inner = text[text.index(after: open)..<text.index(before: text.endIndex)]
        return inner.isEmpty ? nil : String(inner)
    }

    private static func heading(_ document: Document, startingWith title: String) -> Element? {
        ((try? document.select("h4").array()) ?? []).first { cellText($0).hasPrefix(title) }
    }

    private static func parseRiderProgram(_ document: Document) -> [DTO.PCSRiderPage.ProgramRace] {
        guard let list = try? heading(document, startingWith: "Program")?.nextElementSibling(),
              let items = try? list.select("li")
        else {
            return []
        }
        return items.array().compactMap { item in
            let date = cellText(try? item.select(".bold").first())
            let race = cellText(try? item.select("a[href^=race/]").first())
            guard !date.isEmpty, !race.isEmpty else {
                return nil
            }
            let countryCode = (try? item.select("span.flag").first()?.className())?
                .split(separator: " ")
                .first { $0 != "flag" && $0.count == 2 }
            return .init(
                date: date,
                race: race,
                countryCode: countryCode.map(String.init)
            )
        }
    }

    private static func parseRiderRankings(_ document: Document) -> [DTO.PCSRiderPage.SeasonRank] {
        guard let table = try? heading(document, startingWith: "PCS Ranking")?.nextElementSibling(),
              let rows = try? table.select("tbody tr")
        else {
            return []
        }
        var seen = Set<String>()
        return rows.array().compactMap { row in
            let cells = (try? row.select("td").array()) ?? []
            guard cells.count >= 3 else {
                return nil
            }
            let season = cellText(cells[0])
            let points = cellText(cells[1])
            let rank = cellText(cells[2])
            guard !season.isEmpty, !points.isEmpty, seen.insert(season).inserted else {
                return nil
            }
            return .init(
                season: season,
                points: points,
                rank: rank
            )
        }
    }

    private static func parseRiderSeasonResults(_ document: Document) -> [DTO.PCSRiderPage.SeasonResult] {
        ((try? document.select("table.rdrResults tbody tr").array()) ?? []).compactMap { row in
            let cells = (try? row.select("td").array()) ?? []
            guard cells.count >= 8, let link = try? cells[4].select("a").first() else {
                return nil
            }
            _ = try? link.select(".imob").remove()
            let text = cellText(link)
            let date = cellText(cells[0])
            guard !text.isEmpty, !date.isEmpty else {
                return nil
            }
            let raceClass = trailingParenthesis(in: text)
            let race = raceClass.map { String(text.dropLast($0.count + 2)) } ?? text
            let distance = cellText(cells[6])
            let points = cellText(cells[7])
            return .init(
                date: date,
                result: cellText(cells[1]),
                race: collapsedWhitespace(race),
                raceClass: raceClass,
                distance: distance.isEmpty ? nil : distance,
                pcsPoints: points.isEmpty ? nil : points,
                isStage: row.hasClass("stage")
            )
        }
    }

    private static func parsePCSRiderFacts(_ container: Element) -> [DTO.CXRiderPage.Fact] {
        let labels = ((try? container.select("b, strong, .bold").array()) ?? []).filter(isFactLabel)
        var facts: [DTO.CXRiderPage.Fact] = []
        for label in labels {
            let title = collapsedWhitespace((try? label.text()) ?? "").dropLast()
            // The value is whatever follows the label up to the next label or line break.
            var value = ""
            var node = label.nextSibling()
            while let current = node {
                if let element = current as? Element {
                    if element.tagName() == "br" || isFactLabel(element) {
                        break
                    }
                    value += " " + ((try? element.text()) ?? "")
                } else if let text = current as? TextNode {
                    value += " " + text.text()
                }
                node = current.nextSibling()
            }
            value = collapsedWhitespace(value)
            guard !title.isEmpty,
                  title != "Name",
                  !value.isEmpty,
                  value.count <= 80,
                  !facts.contains(where: { $0.label == String(title) })
            else {
                continue
            }
            facts.append(.init(label: String(title), value: value))
        }
        return Array(facts.prefix(10))
    }

    private static func isFactLabel(_ element: Element) -> Bool {
        let tag = element.tagName()
        guard tag == "b" || tag == "strong" || element.hasClass("bold"),
              let text = try? element.text()
        else {
            return false
        }
        let trimmed = collapsedWhitespace(text)
        return trimmed.count > 1 && trimmed.count <= 30 && trimmed.hasSuffix(":")
    }

    private static func collapsedWhitespace(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func pcsAbsoluteURL(_ path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        }
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: baseStringURL + relative)
    }

    private static func parseRiderLink(_ element: Element) -> DTO.RiderLink? {
        guard let link = try? element.select("a[href^=rider/]").first(),
              let name = try? link.text(),
              !name.isEmpty
        else {
            return nil
        }
        let href = (try? link.attr("href")) ?? ""
        // Birthday flags carry an extra size class: "flag c16 si".
        let countryCode = (try? element.select("span.flag").first()?.className())?
            .split(separator: " ")
            .first { $0 != "flag" && $0.count == 2 }
        return DTO.RiderLink(
            name: name,
            url: URL(string: baseStringURL + href),
            countryCode: countryCode.map(String.init) ?? ""
        )
    }
}
