//
//  Requester.swift
//  meteocat
//
//  Created by albert vila on 31/10/24.
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML // Necessary for XML parsing on certain platforms
#endif
import `SwiftSoup` // Add SwiftSoup for HTML parsing

struct Requester {
    private static let baseURL = URL(string: "https://www.procyclingstats.com/")!
    private static let baseStringURL = "https://www.procyclingstats.com/"
    
    static func getLatestResults() async throws -> DTO.Home {
        let url = URL(string: "https://www.procyclingstats.com/index.php")!
//        let url = URL(string: "https://www.procyclingstats.com/race/settimana-internazionale-coppi-e-bartali/2025/stage-3/info/profiles")!
        do {
            let data = try await URLSession.shared.data(from: url).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            
            let document = try SwiftSoup.parse(htmlContent)
            let nextToFinishResults = parseNextToFinishResults(document)
            let todayResults = parseResultsToday(from: document)
            let yesterdayResults = try parseResultsYesterday(document)
            
            let tomorrowRaces = parseRacesTomorrow(from: document)
            
            return DTO.Home(
                nextToFinish: nextToFinishResults,
                today: todayResults,
                yesterdayResults: yesterdayResults,
                tomorrowRaces: tomorrowRaces
            )
            
        } catch {
            if (error as NSError).code != -1009 {
                assertionFailure(error.localizedDescription)
            }
            throw NSError(domain: "Impossible parsing", code: 0, userInfo: nil)
        }
    }
    
    private static func parseNextToFinishResults(_ document: Document) -> [DTO.NextToFinishResult] {
        guard let table = try? document.select("table.hp-tbl1.next-to-finish").first(),
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

    static func parseResultsToday(from document: Document) -> [DTO.TodayResult] {
        var results = [DTO.TodayResult]()
        let baseUrl = "https://www.procyclingstats.com/"
        
        do {
            // First, select the "Results yesterday" header and get the next <ul> with class "hp2-results"
            guard let resultsList = try document.select("h3.black-info-title:contains(Results today) + ul.hp2-results").first() else {
                print("avvp [NETWORK] - empty today results")
                return results
            }
            
            // Loop over each race item (each <li> with class "race")
            let raceItems = try resultsList.select("li.race").array()
            for race in raceItems {
                // 1. Extract race details from the div with inline style containing "calc(100% - 95px)"
                let detailsDiv = try race.select("div").filter { element in
                    try element.hasAttr("style") && element.attr("style").contains("calc(100% - 95px)")
                }.first
                let raceDetails = try detailsDiv?.text() ?? ""
                
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
                    raceName: raceDetails,
                    raceDetails: "",
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
           guard let resultsUl = try document.select("h3.black-info-title:contains(Results yesterday) + ul.hp2-results").first() else {
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
               let raceTitle = try detailsDiv?.select("a").first()?.select("b").text()
               let raceDetails = try detailsDiv?.select("a").first()?.select("span").text()
               
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
                raceName: raceTitle.debugOptional,
                raceDetails: raceDetails.debugOptional,
                winner: raceWinnerUrl,
                podium: podiumWinners,
                additionalDetails: additionalDetails
               )
               results.append(resultDTO)
           }
       } catch {
           assertionFailure(error.localizedDescription)
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
                    assertionFailure()
                }
            } else {
                assertionFailure()
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
                    assertionFailure()
                    print("avvp [NETWORK] CX table found")
                }
            } else {
                print("avvp [NETWORK] No CX races section found")
            }
            
        } catch {
            assertionFailure(error.localizedDescription)
        }
        return sections
    }

    static func parseRacesTomorrow(from document: Document) -> [DTO.TomorrowRace] {
        do {
            // Select the container that immediately follows the header "Races tomorrow"
            // Note: the header is <h3 class="info-title mb5">Races tomorrow</h3>
            guard let container = try document.select("h3.info-title:contains(Races tomorrow) + span.table-cont").first() else {
                assertionFailure("Races tomorrow section not found")
                return []
            }
            
            // Find the table with class "hp-tbl1 tomorrow" within the container
            guard let table = try container.select("table.hp-tbl1.tomorrow").first() else {
                assertionFailure("Races tomorrow section not found")
                return []
            }
            
            // Loop over each row in the table body
            var tomorrowRaces: [DTO.TomorrowRace] = []
            let rows = try table.select("tbody > tr").array()
            for row in rows {
                // Get start time from the first <td> (using the text in the span with class "cet_time")
                let startTD = try row.select("td.fs12.start").first()
                let startTime = try startTD?.select("span.cet_time").text() ?? ""
                
                // The race name cell is the third td (after the start and the icon cell)
                let cells = try row.select("td").array()
                let raceCell = cells.count >= 3 ? cells[2] : nil
                let raceName = try raceCell?.select("a").text() ?? ""
                let raceRelativeURL = try raceCell?.select("a").attr("href") ?? ""
                let raceURL = URL(string: Requester.baseURL.absoluteString + raceRelativeURL)
                
                // Get ETA from the last cell (td.fs12.eta)
                let etaTD = try row.select("td.fs12.eta").first()
                let eta = try etaTD?.select("span.cet_time").text() ?? ""
                tomorrowRaces.append(
                    DTO.TomorrowRace(
                        startTime: startTime,
                        raceName: raceName, relativeUrl: raceURL, eta: eta))
            }
            return tomorrowRaces
        } catch {
            assertionFailure(": Unexpected error parsing HTML document.")
            return []
        }
    }
    
    static func getNextToFinishRaceDetail(_ urlString: String) async throws -> DTO.RaceDetailInfo? {
        let url = URL(string: urlString)!
        do {
            let data = try await URLSession.shared.data(from: url).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            do {
                let doc: Document = try SwiftSoup.parse(htmlContent)
                if let ul = try doc.select("ul.infolist").first() {
                    var date: String = ""
                    var startTime: String = ""
                    var classification: String = ""
                    var category: String = ""
                    var distance: String = ""
                    var departure: String = ""
                    var arrival: String = ""
                    var verticalMeters: String = ""
                    
                    let items = try ul.select("li")
                    for item in items {
                        let divs = try item.select("div")
                        if divs.count >= 2 {
                            let key = try divs[0].text().trimmingCharacters(in: .whitespacesAndNewlines)
                            switch key {
                            case _ where key.lowercased().contains("date"):
                                date = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            case _ where key.lowercased().contains("start time"):
                                startTime = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            case _ where key.lowercased().contains("classification"):
                                classification = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            case _ where key.lowercased().contains("category"):
                                category = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            case _ where key.lowercased().contains("distance"):
                                distance = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            case _ where key.lowercased().contains("departure"):
                                departure = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            case _ where key.lowercased().contains("arrival"):
                                arrival = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            case _ where key.lowercased().contains("vertical meters"):
                                verticalMeters = (try? divs[1].text().trimmingCharacters(in: .whitespacesAndNewlines)) ?? ""
                            default: break
                            }
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
                    let imgURL: URL? = {
                        guard let h3 = try? doc.select("h3").first(where: { try! $0.text() == "Race profile" }),
                                let next = try? h3.nextElementSibling(),
                                let img = try? next.select("img").first(),
                                let src = try? img.attr("src")
                        else {
                            return nil
                        }
                        return URL(string: "\(baseURL)\(src)")
                    }()
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
                        profileURL: imgURL
                    )
                    print("avvp [NETWORK] get next to finish race detail - \(raceInfo)")
                    return raceInfo
                } else {
                    assertionFailure()
                    return nil
                }
            } catch {
                print("avvp [NETWORK - ERROR] get next to finish race detail - \(error)")
                return nil
            }
        } catch {
            assertionFailure(error.localizedDescription)
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

extension String? {
    var debugOptional: String {
        guard let self = self else {
#if DEBUG
            return "shit 😭"
#else
            return "-"
#endif
        }
        return self
    }
}
