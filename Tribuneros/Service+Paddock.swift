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
            print("avvp [NETWORK] - empty latest transfers")
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
            print("avvp [NETWORK] - empty program updates")
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
            print("avvp [NETWORK] - empty birthdays")
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
                .ttl(86400) // 24 hours
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

    /// Best-effort: no real rider page could be captured when this was written, so it keys on
    /// loose structure — the `h1` name, the first rider photo, a team link in the title block,
    /// and "Label:" elements (`b`, `strong` or `.bold`) followed by their value — rather than on
    /// exact classes. Covered only by synthetic HTML in `PaddockTests`.
    static func parsePCSRiderPage(_ document: Document) -> DTO.PCSRiderPage? {
        let name = collapsedWhitespace((try? document.select("h1").first()?.text()) ?? "")
        guard !name.isEmpty else {
            return nil
        }
        let imageSource = (try? document.select(".rdr-img-cont img, img[src*=images/riders/]").first()?.attr("src")) ?? ""
        let team = (try? document.select(".page-title a[href^=team/], .rdr-info-cont a[href^=team/]").first()?.text())
            .map(collapsedWhitespace)
        let container = (try? document.select(".rdr-info-cont").first()) ?? document.body()
        return DTO.PCSRiderPage(
            name: name,
            imageURL: imageSource.isEmpty ? nil : pcsAbsoluteURL(imageSource),
            team: team?.isEmpty == false ? team : nil,
            facts: container.map(parsePCSRiderFacts) ?? []
        )
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
