//
//  Service+Paddock.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import Foundation
import SwiftSoup

extension Service {

    static func getPaddock() async throws -> DTO.Paddock {
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
