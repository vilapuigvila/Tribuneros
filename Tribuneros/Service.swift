//
//  Requester.swift
//  meteocat
//
//  Created by albert vila on 31/10/24.
//

import Foundation
import Alfy
#if canImport(FoundationXML)
import FoundationXML // Necessary for XML parsing on certain platforms
#endif
import `SwiftSoup` // Add SwiftSoup for HTML parsing

struct Service {
    private static let baseURL = URL(string: "https://www.procyclingstats.com/")!
    static let baseStringURL = "https://www.procyclingstats.com/"
    static let homepageURL = "https://www.procyclingstats.com/index.php"
    private static let requester = Requester.self

    /// PCS answers 403 to image requests without a Referer and a browser User-Agent.
    private static let pcsImageHeaderFields = [
        "Referer": baseStringURL,
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)"
    ]

    private static func isPCSHost(_ url: URL?) -> Bool {
        guard let host = url?.host else { return false }
        return host == "procyclingstats.com" || host.hasSuffix(".procyclingstats.com")
    }

    static func pcsImageHeaders(for url: URL) -> [Requester.HeaderParam] {
        guard isPCSHost(url) else { return [] }
        return pcsImageHeaderFields.map {
            .custom(
                headerField: $0.key,
                value: $0.value
            )
        }
    }

    static func addPCSImageHeaders(to request: inout URLRequest) {
        guard isPCSHost(request.url) else { return }
        pcsImageHeaderFields.forEach {
            request.setValue(
                $0.value,
                forHTTPHeaderField: $0.key
            )
        }
    }

    static func getLatestResults() async throws -> DTO.Home {
//        let url = URL(string: "https://www.procyclingstats.com/race/settimana-internazionale-coppi-e-bartali/2025/stage-3/info/profiles")!
        do {
            let (document, staleCopySavedAt) = try await getHomepageCopy()
            let nextToFinishResults = parseNextToFinishResults(document)
            let todayResults = parseResultsToday(from: document)
            let yesterdayResults = try parseResultsYesterday(document)

            let tomorrowRaces = parseRacesTomorrow(from: document)
            let liveStatsRaces = parseLiveStats(document)

            return DTO.Home(
                nextToFinish: nextToFinishResults,
                today: todayResults,
                yesterdayResults: yesterdayResults,
                tomorrowRaces: tomorrowRaces,
                liveStats: liveStatsRaces,
                staleCopySavedAt: staleCopySavedAt,
                previews: parsePreviews(from: document)
            )

        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, error.localizedDescription)
            }
            throw NSError(domain: "Impossible parsing", code: 0, userInfo: nil)
        }
    }

    private static let latestResultsURL = baseStringURL + "races.php?s=latest-results"
    private static let historyLimit = 30

    /// Winners of the races finished before yesterday, newest first, from PCS's "Latest race
    /// results" table (today and yesterday have their own sections, from the homepage).
    static func getHistoryRaces(now: Date = Date()) async -> [DTO.TodayResult] {
        do {
            let (data, _) = try await Requester
                .makeRequest(latestResultsURL)
                .ttl(6 * 3600)
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else { return [] }
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            return parseHistoryResults(
                try SwiftSoup.parse(html),
                before: calendar.startOfDay(for: yesterday),
                calendar: calendar
            )
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "History fetch error: \(error.localizedDescription)")
            }
            return []
        }
    }

    /// Rows are date, race (link), class, winner (flag + link) and time ago; a row dated before
    /// `cutoff` becomes a result with the winner as its only podium entry.
    static func parseHistoryResults(
        _ document: Document,
        before cutoff: Date,
        calendar: Calendar = .current
    ) -> [DTO.TodayResult] {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.calendar = calendar
        input.timeZone = calendar.timeZone
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.calendar = calendar
        output.timeZone = calendar.timeZone
        output.setLocalizedDateFormatFromTemplate("d MMM")

        guard let rows = try? document.select("table.basic > tbody > tr").array() else { return [] }
        let results = rows.compactMap { row -> DTO.TodayResult? in
            guard let cells = try? row.select("td").array(), cells.count >= 4,
                  let dateText = try? cells[0].text(),
                  let date = input.date(from: dateText),
                  date < cutoff,
                  let raceLink = try? cells[1].select("a").first(),
                  let href = try? raceLink.attr("href"),
                  let raceName = try? raceLink.text(),
                  !raceName.isEmpty,
                  let winnerLink = try? cells[3].select("a").first(),
                  let winnerName = try? winnerLink.text().trimmingCharacters(in: .whitespaces),
                  !winnerName.isEmpty
            else {
                return nil
            }
            let raceClass = (try? cells[2].text()) ?? ""
            let raceCountryCode = spanFlagCode(in: cells[1])
            let flagCode = spanFlagCode(in: cells[3])
            return DTO.TodayResult(
                raceName: raceClass.isEmpty ? raceName : "\(raceName) (\(raceClass))",
                raceDetails: output.string(from: date),
                raceURL: URL(string: baseStringURL + historyStageHref(href, raceName: raceName)),
                winner: nil,
                podium: [
                    DTO.TodayResult.Winner(
                        position: "1",
                        flag: flagCode.flatMap { URL(string: baseStringURL + "images/flags/" + $0 + ".png") },
                        countryCode: flagCode,
                        name: winnerName,
                        team: "",
                        time: ""
                    )
                ],
                additionalDetails: [],
                raceCountryCode: raceCountryCode
            )
        }
        return Array(results.prefix(historyLimit))
    }

    /// PCS links stage-race rows to `race/<slug>-<year>-gc`, whose results table is filled by
    /// JavaScript; `race/<slug>/<year>/stage-N` has the rows in the HTML.
    private static func historyStageHref(
        _ href: String,
        raceName: String
    ) -> String {
        guard let link = href.range(of: "^race/(.+)-([0-9]{4})-gc$", options: .regularExpression),
              let stage = raceName.range(of: "Stage [0-9]+", options: .regularExpression)
        else {
            return href
        }
        let parts = String(href[link]).dropFirst("race/".count).dropLast("-gc".count)
        let slug = parts.dropLast("-0000".count)
        let year = parts.suffix(4)
        let number = raceName[stage].dropFirst("Stage ".count)
        return "race/\(slug)/\(year)/stage-\(number)"
    }

    private static func spanFlagCode(in cell: Element) -> String? {
        (try? cell.select("span.flag").first()?.className())?
            .split(separator: " ")
            .map(String.init)
            .first { $0.lowercased() != "flag" }
    }

    static func getHomepageDocument() async throws -> Document {
        try await getHomepageCopy().document
    }

    static func getHomepageCopy() async throws -> (document: Document, staleCopySavedAt: Date?) {
        let (data, response) = try await Requester
            .makeRequest(homepageURL)
            .ttl(60*15) // 15 minutes
            .cacheControlBehavior(.ignoreServer)
            .send()
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
        }
        return (
            try SwiftSoup.parse(htmlContent),
            staleCopySavedAt(response, now: Date())
        )
    }

    /// Alfy marks an expired cached copy with `X-Cache: STALE`; its `Age` is seconds since it was fetched.
    static func staleCopySavedAt(
        _ response: URLResponse,
        now: Date
    ) -> Date? {
        guard let http = response as? HTTPURLResponse,
              http.value(forHTTPHeaderField: "X-Cache") == "STALE",
              let age = http.value(forHTTPHeaderField: "Age").flatMap(TimeInterval.init)
        else { return nil }
        return now.addingTimeInterval(-age)
    }

    static func isOffline(_ error: Error) -> Bool {
        if let reason = error as? Requester.ErrorReason, case .noInternetConnection = reason {
            return true
        }
        return (error as NSError).code == -1009
    }
    
    static func parseNextToFinishResults(_ document: Document) -> [DTO.NextToFinishResult] {
        guard let heading = try? document.select("h4:contains(Next to finish)").first(),
              let table = try? heading.nextElementSibling(),
              table.tagName() == "table",
              let tbody = try? table.select("tbody").first(),
              let rows = try? tbody.select("tr")
        else {
            print("avvp [NETWORK] - empty next to finish")
            return []
        }
        var results: [[String]] = []
        
        for row in rows {
            guard let cells = try? row.select("td") else {
                continue
            }
            var rowData: [String] = []
            
            for cell in cells {
                guard let cellText = try? cell.text() else {
                    continue
                }
                rowData.append(cellText)
            }
            // get race path url
            if let pathURL = try? row.select("a").first(), let href = try? pathURL.attr("href") {
                let urlString = "https://www.procyclingstats.com/\(href)"
                rowData.append(urlString)
            } else {
                rowData.append("")
            }
            if let flagSpan = try? row.select("span.flag").first() {
               let classNames = try? flagSpan.className().split(separator: " ")
                if let flagCode = classNames?.first(where: { $0 != "flag" }) {
                    rowData.append(String(flagCode))
                } else {
                    rowData.append("")
                }
            } else {
                rowData.append("")
            }
            results.append(rowData)
        }
        return DTO.NextToFinishResult.parse(cells: results)
    }
    
    // MARK: - Parsing Function -

    private static func parseRaceHeader(_ detailsDiv: Element?) throws -> (title: String, details: String, url: URL?) {
        let link = try detailsDiv?.select("a").first()
        let href = try link?.attr("href") ?? ""
        return (
            title: try link?.select("b").text() ?? "",
            details: try link?.select("span").text() ?? "",
            url: href.isEmpty ? nil : pcsAbsoluteURL(href)
        )
    }

    static func parseResultsToday(from document: Document) -> [DTO.TodayResult] {
        var results = [DTO.TodayResult]()
        let baseUrl = "https://www.procyclingstats.com/"
        
        do {
            guard let resultsList = try document.select("div.h4bar:has(h4:contains(Results today)) ~ ul.hp2-results").first() else {
                print("avvp [NETWORK] - empty today results")
                return results
            }
            let raceItems = resultsList.children().array().filter { $0.tagName() == "li" && $0.hasClass("race") }
            for race in raceItems {
                // 1. Extract race details from the div with inline style containing "calc(100% - 95px)"
                let detailsDiv = try race.select("div").filter { element in
                    try element.hasAttr("style") && element.attr("style").contains("calc(100% - 95px)")
                }.first
                let header = try parseRaceHeader(detailsDiv)
                let raceFullText = try detailsDiv?.text() ?? ""

                // 2. Extract winner image URL from the first <div class="winner-img">
                var winnerURL: URL? = nil
                if let winnerImgDiv = try race.select("div.winner-img").first() {
                    let styleAttr = try winnerImgDiv.attr("style")
                    // Style expected to be like: " background: url(images/riders/bp/de/mie-bjorndal-ottestad-2025.jpg); ..."
                    let pattern = "url\\((.*?)\\)"
                    if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                       let match = regex.firstMatch(in: styleAttr, options: [], range: NSRange(styleAttr.startIndex..<styleAttr.endIndex, in: styleAttr)),
                       let range = Range(match.range(at: 1), in: styleAttr)
                    {
                        let relativeURL = String(styleAttr[range])
                        winnerURL = URL(string: baseUrl + relativeURL)
                    }
                }
                
                let podiumWinners: [DTO.TodayResult.Winner] = {
                    guard let podiumRows = try? race.select("table.top3 > tbody > tr").array() else {
                        return []
                    }
                    return podiumRows.compactMap { row in
                        guard let cells = try? row.select("td").array(), cells.count >= 3 else {
                            return nil
                        }
                        guard let position = try? cells[0].text() else {
                            return nil
                        }
                        let flagSpan: (countryCode: String?, urlFlag: URL?) = {
                            guard let flagSpan = try? cells[1].select("span.flag").first(),
                                  let classes = try? flagSpan.className().split(separator: " ").map(String.init),
                                  let code = classes.first(where: { $0.lowercased() != "flag" })
                            else {
                                return (nil, nil)
                            }
                            return (code, URL(string: baseUrl + "images/flags/" + code + ".png"))
                        }()
                        let raceInfo: (name: String?, team: String?, time: String?) = {
                            if cells.count == 3 {
                                let name = try? cells[1].select("a").text()
                                let team = ""
                                let time = try? cells[2].text()
                                return (name, team, time)
                            } else {
                                let name = try? cells[1].select("a").text()
                                let team = try? cells[2].select("a").text()
                                let time = try? cells[3].text()
                                return (name, team, time)
                            }
                        }()
                        return DTO.TodayResult.Winner(
                            position: position,
                            flag: flagSpan.urlFlag,
                            countryCode: flagSpan.countryCode,
                            name: raceInfo.name ?? "",
                            team: raceInfo.team ?? "",
                            time: raceInfo.time ?? ""
                        )
                    }
                }()
                
                // 4. Parse additional details from the <ul class="leaders">
                var additionalDetails = [DTO.TodayResult.AdditionalDetails]()
                if let leaderItems = try? race.select("ul.leaders > li").array() {
                    for leader in leaderItems {
                        let tag = try leader.select("div").attr("data-stage_type")
                        let relLeaderUrl = try leader.select("a").attr("href")
                        let fullLeaderUrl = URL(string: baseUrl + relLeaderUrl)
                        
                        let detail = DTO.TodayResult.AdditionalDetails(tag: tag, url: fullLeaderUrl)
                        additionalDetails.append(detail)
                    }
                }
                
                // 5. Create the TodayResult DTO and append to our results
                let resultDTO = DTO.TodayResult(
                    raceName: header.title.isEmpty ? raceFullText : header.title,
                    raceDetails: header.details,
                    raceURL: header.url,
                    winner: winnerURL,
                    podium: podiumWinners,
                    additionalDetails: additionalDetails
                )
                results.append(resultDTO)
            }
        } catch {
            print("avvp [NETWORK] - \(error.localizedDescription)")
        }
        return results
    }
    
    static func parseResultsYesterday(_ document: Document) throws -> [DTO.TodayResult] {
        var results = [DTO.TodayResult]()
        let baseUrl = "https://www.procyclingstats.com/"

       do {
           // Use an adjacent-sibling CSS selector to get the <ul> with results that immediately follows the header:
           guard let resultsUl = try document.select("div.h4bar:has(h4:contains(Results yesterday)) + ul.hp2-results").first() else {
               print("avvp [NETWORK] - empty yesterday results")
               return results
           }
           let raceItems = try resultsUl.select("li.race").array()
           for race in raceItems {
               
               // 1. Extract race details (the text inside the div that shows the race name and extra info)
               // We assume that the div with inline style containing "width: calc(100% - 95px)" holds the race details.
               let detailsDiv = try race.select("div").filter { element in
                   try element.hasAttr("style") && element.attr("style").contains("width: calc(100% - 95px)")
               }.first
               
               /// Volta Ciclista a Catalunya (2.UWT)
               let header = try parseRaceHeader(detailsDiv)

//               let raceDetails = try detailsDiv?.text()
               
               // 2. Get the winner image URL from the <div class="winner-img"> inside the first <a>.
               var raceWinnerUrl: URL? = nil
               if let winnerImgDiv = try race.select("div.winner-img").first() {
                   let styleAttr = try winnerImgDiv.attr("style")
                   // The style is something like: " background: url(images/riders/bp/de/mie-bjorndal-ottestad-2025.jpg); ..."
                   let pattern = "url\\((.*?)\\)"
                   if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                      let match = regex.firstMatch(in: styleAttr, options: [], range: NSRange(styleAttr.startIndex..<styleAttr.endIndex, in: styleAttr)),
                      let range = Range(match.range(at: 1), in: styleAttr)
                   {
                       let relativeUrl = String(styleAttr[range])
                       // Build the full URL using the base URL.
                       raceWinnerUrl = URL(string: baseUrl + relativeUrl)
                   }
               }
               
               // 3. Parse the podium winners from the table with class "top3"
               let podiumWinners: [DTO.TodayResult.Winner] = {
                   guard let podiumRows = try? race.select("table.top3 > tbody > tr").array() else {
                       return []
                   }
                   return podiumRows.compactMap { row in
                       guard let tds = try? row.select("td").array(), tds.count >= 3 else {
                           return nil
                       }
                       guard let position = try? tds[0].text() else {
                           return nil
                       }
                       let flagSpan: (countryCode: String?, urlFlag: URL?) = {
                           guard let flagSpan = try? tds[1].select("span.flag").first(),
                                 let classes = try? flagSpan.className().split(separator: " ").map(String.init),
                                 let code = classes.first(where: { $0.lowercased() != "flag" })
                           else {
                               return (nil, nil)
                           }
                           return (code, URL(string: baseUrl + "images/flags/" + code + ".png"))
                       }()
                       let raceInfo: (name: String?, team: String?, time: String?) = {
                           if tds.count == 3 {
                               let name = try? tds[1].select("a").text()
                               let team = ""
                               let time = try? tds[2].text()
                               return (name, team, time)
                           } else {
                               let name = try? tds[1].select("a").text()
                               let team = try? tds[2].select("a").text()
                               let time = try? tds[3].text()
                               return (name, team, time)
                           }
                       }()
                       return DTO.TodayResult.Winner(
                           position: position,
                           flag: flagSpan.urlFlag,
                           countryCode: flagSpan.countryCode,
                           name: raceInfo.name ?? "#",
                           team: raceInfo.team ?? "#",
                           time: raceInfo.time ?? "#"
                       )
                   }
               }()
               
               // 4. Parse additional details from the <ul class="leaders">.
               let additionalDetails: [DTO.TodayResult.AdditionalDetails] = {
                   guard let leaderItems = try? race.select("ul.leaders > li").array() else { return [] }
                   return leaderItems.compactMap { leader in
                       guard let tag = try? leader.select("div").attr("data-stage_type"),
                             let relUrl = try? leader.select("a").attr("href")
                       else {
                           return nil
                       }
                       let fullUrl = URL(string: baseUrl + relUrl)
                       return DTO.TodayResult.AdditionalDetails(tag: tag, url: fullUrl)
                   }
               }()
               
               // 5. Create the TodayResult DTO for this race item.
               let resultDTO = DTO.TodayResult(
                raceName: header.title.isEmpty ? "-" : header.title,
                raceDetails: header.details,
                raceURL: header.url,
                winner: raceWinnerUrl,
                podium: podiumWinners,
                additionalDetails: additionalDetails
               )
               results.append(resultDTO)
           }
       } catch {
           nonFatalCrashlytics(false, error.localizedDescription)
       }
       return results
    }
    
    // MARK: - first ulr helper -
    
    private static func extractImgWinner(_ item: Element) -> URL? {
        do {
            guard let imgDiv = try item.select("div.winner-img").first() else {
                return nil
            }
            let styleAttribute = try imgDiv.attr("style")
            let pattern = "url\\(([^)]+)\\)"
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsString = styleAttribute as NSString
            let range = NSRange(location: 0, length: nsString.length)
            guard let match = regex.firstMatch(in: styleAttribute, options: [], range: range),
                    let swiftRange = Range(match.range(at: 1), in: styleAttribute)
            else {
                return nil
            }
            let imageUrl = String(styleAttribute[swiftRange])
            guard let hostUrl = URL(string: "https://www.procyclingstats.com"),
                    let fullUrl = URL(string: imageUrl, relativeTo: hostUrl)
            else {
                return nil
            }
            return fullUrl
        } catch {
            return nil
        }
    }
    /*
    static func getTodayRaces(date: Date? = nil) async -> [TodaySectionModel] {
//        https://www.procyclingstats.com/index.php
        let url = URL(string: "https://www.procyclingstats.com/index.php")!
//        https://www.procyclingstats.com/races.php?date=2025-02-19&nation=&cat=&filter=Filter&p=uci&s=today
//        let url = URL(string: "https://www.procyclingstats.com/calendar/uci/today")!
//        let url = URL(string: "https://www.procyclingstats.com/races.php?date=2025-02-19&nation=&cat=&filter=Filter&p=uci&s=today")!
        var sections: [TodaySectionModel] = []
        do {
            let data = try await URLSession.shared.data(from: url).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                print("avvp [NETWORK] - error today races: invalid data encoding")
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            
            let document = try SwiftSoup.parse(htmlContent)
            // MARK: Extract UCI races
            if let uciSection = try document.select("div.mt30:has(h3:contains(UCI races))").first() {
                
                if let uciTable = try uciSection.select("table.basic").first() {
                    let uciRows = try uciTable.select("tbody tr")
                    
                    var races: [TodaySectionModel.Race] = []
                    for row in uciRows {
                        let cells = try row.select("td")
                        // Expecting 5 columns: Race, Class, Cat, Winner, Exp. finish
                        if cells.count >= 5 {
                            let race = try cells.get(0).text()
                            let classification = try cells.get(1).text()
                            let cat = try cells.get(2).text()
                            let winner = try cells.get(3).text()
                            let expFinish = try cells.get(4).text()
                            let todayRace = TodaySectionModel.Race(race: race, category: classification, gender: cat, winner: winner, expectedFinish: expFinish, isCancel: row.hasClass("striked"))
                            races.append(todayRace)
                        }
                    }
                    sections.append(TodaySectionModel(sectionName: "UCI races", races: races))
                } else {
                    nonFatalCrashlytics(false, "missing")
                }
            } else {
                nonFatalCrashlytics(false, "missing")
            }
            
            if let nationalSection = try document.select("div.mt30:has(h3:contains(National races))").first() {
                if let nationalTable = try nationalSection.select("table.basic").first() {
                    let nationalRows = try nationalTable.select("tbody tr")
                    var races: [TodaySectionModel.Race] = []
                    for row in nationalRows {
                        let cells = try row.select("td")
                        // Expecting 3 columns: Race, Cat, Winner
                        if cells.count >= 3 {
                            let race = try cells.get(0).text()
                            let cat = try cells.get(1).text()
                            let winner = try cells.get(2).text()
                            let todayRace = TodaySectionModel.Race(
                                race: race,
                                category: "",
                                gender: cat, winner: winner, expectedFinish: "", isCancel: row.hasClass("striked"))
                            races.append(todayRace)
                        }
                    }
                    sections.append(TodaySectionModel(sectionName: "National Races", races: races))
                } else {
                    print("avvp [NETWORK] No National table found")
                }
            } else {
                print("avvp [NETWORK] No National races section found")
            }
            
            if let nationalSection = try document.select("div.mt30:has(h3:contains(CX races))").first() {
                
                if let nationalTable = try nationalSection.select("table.basic").first() {
                    let nationalRows = try nationalTable.select("tbody tr")
                    var races: [TodaySectionModel.Race] = []
                    for row in nationalRows {
                        let cells = try row.select("td")
                        // Expecting 3 columns: Race, Cat, Winner
                        if cells.count >= 3 {
                            let race = try cells.get(0).text()
                            let cat = try cells.get(1).text()
                            let winner = try cells.get(2).text()
                            let todayRace = TodaySectionModel.Race(
                                race: race,
                                category: "",
                                gender: cat,
                                winner: winner, expectedFinish: "", isCancel: row.hasClass("striked"))
                            races.append(todayRace)
                        }
                    }
                    sections.append(TodaySectionModel(sectionName: "CX Races", races: races))
                } else {
                    nonFatalCrashlytics(false, "CX table found")
                }
            } else {
                nonFatalCrashlytics(false, "No CX races section found")
            }
            
        } catch {
            nonFatalCrashlytics(false, error.localizedDescription)
        }
        return sections
    }
*/
    static func parseRacesTomorrow(from document: Document) -> [DTO.TomorrowRace] {
        do {
            guard let container = try document.select("div.h4line:has(h4:contains(Races tomorrow)) + div").first() else {
//                nonFatalCrashlytics(false, "Races tomorrow section not found")
                return []
            }

            // Find the table with class "basic hp-next-to-finish" within the container
            guard let table = try container.select("table.basic.hp-next-to-finish").first() else {
                nonFatalCrashlytics(false, "Races tomorrow section not found")
                return []
            }

            // Loop over each row in the table body
            var tomorrowRaces: [DTO.TomorrowRace] = []
            let rows = try table.select("tbody > tr").array()
            for row in rows {
                // New row layout: 0 start time (plain text) · 1 profile icon · 2 race · 3 ETA (plain text)
                let cells = try row.select("td").array()
                guard cells.count >= 4 else { continue }

                let startTime = (try? cells[0].text()) ?? ""

                let raceCell = cells[2]
                let raceName = (try? raceCell.select("a").text()) ?? ""
                let raceRelativeURL = (try? raceCell.select("a").attr("href")) ?? ""
                let raceURL = URL(string: Service.baseURL.absoluteString + raceRelativeURL)

                let eta = (try? cells[3].text()) ?? ""
                tomorrowRaces.append(
                    DTO.TomorrowRace(
                        startTime: startTime,
                        raceName: raceName, relativeUrl: raceURL, eta: eta))
            }
            return tomorrowRaces
        } catch {
            nonFatalCrashlytics(false, "Unexpected error parsing HTML document.")
            return []
        }
    }
    
    static func parseLiveStats(_ document: Document) -> [DTO.LiveStatsRace] {
        guard let list = try? document.select("ul.hp3-livestats").first() else {
            return []
        }
        let items = (try? list.select("li").array()) ?? []
        guard !items.isEmpty else {
            return []
        }

        return items.compactMap { li -> DTO.LiveStatsRace? in
            guard let anchor = try? li.select("a").first(),
                  let racePath = try? anchor.attr("href"),
                  !racePath.isEmpty
            else {
                nonFatalCrashlytics(false, "LiveStats <li> missing its race link/href")
                return nil
            }

            let statusSpan = try? anchor.select("span.status").first()
            let status = (try? statusSpan?.text()) ?? ""
            let isLive = statusSpan?.hasClass("live") ?? false

            let raceName = (try? anchor.select("span.title").first()?.text()) ?? ""

            let ridersText = (try? anchor.select("div.togo > span").first()?.text()) ?? ""
            let ridersCount = Int(ridersText)

            let url = URL(string: baseStringURL + racePath)

            return DTO.LiveStatsRace(
                status: status,
                isLive: isLive,
                raceName: raceName,
                ridersCount: ridersCount,
                racePath: racePath,
                url: url
            )
        }
    }

    static func getInfoProfiles(_ urlString: String) async throws -> [DTO.StageProfile] {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil { return [] }
        #endif
        let url = URL(string: urlString + "/info/profiles")!
        do {
            let (data, _) = try await Requester
                .makeRequest(url.absoluteString)
                .ttl(86400*2) // 2 days
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            let doc: Document = try SwiftSoup.parse(htmlContent)
            let listItems: Elements = try doc.select("ul.list > li")
            
            let stageImages: [DTO.StageProfile] = try listItems.array().compactMap { li in
                guard
                    let type = try li.select("div.fs14.bold").first()?.text(),
                    let img = try li.select("img").first()
                else {
                    return nil
                }
                let src = try img.attr("src")
                if src.hasSuffix(".jpg") || src.hasSuffix(".png") {
                    let fullUrl = src.hasPrefix("http") ? src : baseStringURL + src
                    let imageType = DTO.StageProfile.ProfileImageType(rawValue: type)
                    return DTO.StageProfile(type: imageType, url: fullUrl)
                }
                return nil
            }
            print("avpv [NETWORK] get stage profile info - \(dump(stageImages))")
            return stageImages
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, error.localizedDescription)
            }
            return []
        }
    }
    
    /// A race page's "Race information" as (label, value): `<li>` rows of two divs, or the newer
    /// `div.lineh16` run of a bold label div followed by value divs up to the next `<br>`.
    static func raceInfoPairs(_ doc: Document) throws -> [(key: String, value: String)] {
        var pairs: [(key: String, value: String)] = []
        for item in try doc.select("li") {
            let divs = try item.select("div")
            guard divs.count >= 2 else { continue }
            pairs.append((
                key: try divs[0].text().trimmingCharacters(in: .whitespacesAndNewlines),
                value: try divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
        for label in try doc.select("div.lineh16 > div.bold") {
            var values: [String] = []
            var sibling = try label.nextElementSibling()
            while let element = sibling, element.tagName() != "br", !element.hasClass("bold") {
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    values.append(text)
                }
                sibling = try element.nextElementSibling()
            }
            pairs.append((
                key: try label.text().trimmingCharacters(in: .whitespacesAndNewlines),
                value: values.joined(separator: " ")
            ))
        }
        return pairs
    }

    static func getNextToFinishRaceDetail(_ urlString: String) async throws -> DTO.RaceDetailInfo? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return DTO.RaceDetailInfo(
                title: "CRO Race — Stage 1", // l10n:ignore: mock data
                date: "01 October 2026",
                startTime: "12:00",
                classification: "2.1",
                category: "ME",
                distance: "134 km",
                departure: "Zagreb",
                arrival: "Zagreb",
                verticalMeters: "1200",
                profileURL: nil
            )
        }
        #endif
        let url = URL(string: urlString)!
        do {
            let (data, _) = try await Requester
                .makeRequest(url.absoluteString)
                .ttl(60*30) // 30 minutes
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            do {
                let doc: Document = try SwiftSoup.parse(htmlContent)
//                if let ul = try doc.select("ul.infolist").first() {
                    var date: String = ""
                    var startTime: String = ""
                    var classification: String = ""
                    var category: String = ""
                    var distance: String = ""
                    var departure: String = ""
                    var arrival: String = ""
                    var verticalMeters: String = ""
                    
                    for (key, value) in try raceInfoPairs(doc) where !value.isEmpty {
                        switch key.lowercased() {
                        case let key where key.contains("date") && date.isEmpty:
                            date = value
                        case let key where key.contains("start time") && startTime.isEmpty:
                            startTime = value
                        case let key where key.contains("classification") && classification.isEmpty:
                            classification = value
                        case let key where key.contains("category") && category.isEmpty:
                            category = value
                        case let key where key.contains("distance") && distance.isEmpty:
                            distance = value
                        case let key where key.contains("departure") && departure.isEmpty:
                            departure = value
                        case let key where key.contains("arrival") && arrival.isEmpty:
                            arrival = value
                        case let key where key.contains("vertical meters") && verticalMeters.isEmpty:
                            verticalMeters = value
                        default:
                            break
                        }
                    }
                    let title: String = {
                        guard let metaDesc = try? doc.select("meta[name=description]").first(),
                              let desc = try? metaDesc.attr("content")
                        else {
                            return ""
                        }
                        return desc
                    }()
                /*
                    let imgURL: URL? = {
                        guard let relativeURL: Element = try? doc.select("div.mt10 img").first(),
                              let src: String = try? relativeURL.attr("src")
                        else {
                            return nil
                        }
                        return URL(string: "\(baseURL)\(src)")
                    }()*/
                    let raceInfo = DTO.RaceDetailInfo(
                        title: title,
                        date: date,
                        startTime: startTime,
                        classification: classification,
                        category: category,
                        distance: distance,
                        departure: departure,
                        arrival: arrival,
                        verticalMeters: verticalMeters,
                        profileURL: nil // imgURL
                    )
                    print("avpv [NETWORK] get next to finish race detail - \(raceInfo)")
                    return raceInfo
            /*    }
            else {
                    return nil
                }*/
            } catch {
                print("avvp [NETWORK - ERROR] get next to finish race detail - \(error)")
                return nil
            }
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, error.localizedDescription)
            }
            throw NSError(domain: "Impossible parsing", code: 0, userInfo: nil)
        }
    }
}

struct TodaySectionModel: Decodable, Hashable, Sendable {
    
    struct Race: Decodable, Hashable, Sendable {
        let race: String
        let category: String
        let gender: String
        let winner: String
        let expectedFinish: String
        let isCancel: Bool
    }
    
    let sectionName: String
    let races: [Race]
}

