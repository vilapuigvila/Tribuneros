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

enum DTO {
    struct Home: Codable, Equatable {
        let nextToFinish: [NextToFinishResult]
        let today: [TodayResult]
        let yesterdayResults: [TodayResult]
    }
    
    struct NextToFinishResult: Codable, Equatable {
        let eta: String
        let duration: String
        let name: String
        let category: String
        let raceType: String
        let distance: String
        
        static func parse(cells: [[String]]) -> [NextToFinishResult] {
            /*
             ▿ 0 : 7 elements
               - 0 : ""
               - 1 : "15:45"
               - 2 : "2h"
               - 3 : "Vuelta a Extremadura Femenina - S2"
               - 4 : "WE"
               - 5 : "2.1"
               - 6 : "109"
             */
            cells.compactMap {
                NextToFinishResult(eta: $0[1], duration: $0[2], name: $0[3], category: $0[4], raceType: $0[5], distance: $0[6])
            }
        }
    }
    
    struct TodayResult: Codable, Equatable {
        struct Winner: Codable, Equatable {
            let position: String
            let flag: URL?
            let name: String
            let team: String
            let time: String
        }
        struct AdditionalDetails: Codable, Equatable {
            let tag: String
            let url: URL?
        }
        let raceDetails: String
        let winner: URL?
        let podium: [Winner]
        let additionalDetails: [AdditionalDetails]
    }
}

struct Requester {
    private static let baseURL = URL(string: "https://www.procyclingstats.com/")!
    
    static func getLatestResults() async throws -> DTO.Home {
        let url = URL(string: "https://www.procyclingstats.com/index.php")!
        do {
            let data = try await URLSession.shared.data(from: url).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            
            let document = try SwiftSoup.parse(htmlContent)
            let nextToFinishResults = parseNextToFinishResults(document)
            let todayResults = parseResultsToday(from: document)
            let yesterdayResults = try parseResultsYesterday(document)
            return DTO.Home(nextToFinish: nextToFinishResults, today: todayResults, yesterdayResults: yesterdayResults)
            
        } catch {
            assertionFailure(error.localizedDescription)
            throw NSError(domain: "Impossible parsing", code: 0, userInfo: nil)
        }
    }
    
    private static func parseNextToFinishResults(_ document: Document) -> [DTO.NextToFinishResult] {
        guard let table = try? document.select("table.hp-tbl1.next-to-finish").first() else {
            return []
        }
        guard let tbody = try? table.select("tbody").first() else {
            return []
        }
        guard let rows = try? tbody.select("tr") else {
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
            results.append(rowData)
        }
        return DTO.NextToFinishResult.parse(cells: results)
    }
    /*
    private static func parseResultsToday(_ document: Document) throws -> [DTO.TodayResult] {
        if let resultsTodayHeader = try document.select("h3.black-info-title:contains(Results today)").first() {
            // Get its next sibling element – the container with the details
            if let detailsDiv = try resultsTodayHeader.nextElementSibling() {
                let resultsList = try document.select("ul.hp2-results").first()
                guard let listItems = try resultsList?.select("li") else {
                    assertionFailure()
                    return []
                }
                
                var todayResults: [DTO.TodayResult] = []
                for item in listItems {
                    // Optionally check if the item has class "race" (skip ads, etc.)
                    if try item.hasClass("race") {
                        // 1. Extract the image URL from the inline style of the "winner-img" div
                        let winnerURL: URL? = try {
                            if let imgDiv = try? item.select("div.winner-img").first() {
                                guard let style = try? imgDiv.attr("style") else{
                                    return nil
                                }
                                // Use a regex to capture the URL inside url(...)
                                let pattern = "url\\(([^)]+)\\)"
                                let regex = try NSRegularExpression(pattern: pattern, options: [])
                                let nsString = style as NSString
                                let range = NSRange(location: 0, length: nsString.length)
                                let winnerImgURL: URL? = {
                                    if let match = regex.firstMatch(in: style, options: [], range: range) {
                                        let urlRange = match.range(at: 1)
                                        if let swiftRange = Range(urlRange, in: style) {
                                            let relativeUrl = String(style[swiftRange])
                                            // Assuming the host is known
                                            let host = "https://www.procyclingstats.com/"
                                            if let fullUrl = URL(string: relativeUrl, relativeTo: URL(string: host))?.absoluteString {
                                                return URL(string: fullUrl)
                                            }
                                        }
                                    }
                                    return nil
                                }()
                                return winnerImgURL
                            }
                            return nil
                        }()
                        
                        // 2. Extract race details from the adjacent div (with inline style containing "calc(100% - 95px)")
                        let raceDetails: String? = {
                            if let detailsDiv = try? item.select("div[style*='calc(100% - 95px)']").first() {
                                return try? detailsDiv.text()
                            }
                            return nil
                        }()
                        
                        // 3. Wiiners
                        var winners: [DTO.TodayResult.Winner] = []
                        if let table = try item.select("table.top3").first() {
                            let rows = try table.select("tr")
                            for row in rows {
                                let cells = try row.select("td")
                                var cellTexts: [String] = []
                                for cell in cells {
                                    let cellText = try cell.text()
                                    cellTexts.append(cellText)
                                }
                                let winner: DTO.TodayResult.Winner = .init(
                                    position: cellTexts[0],
                                    flag: nil,
                                    name: cellTexts[1],
                                    team: cellTexts[2],
                                    time: cellTexts[3]
                                )
                                winners.append(winner)
                            }
                        }
                        // Additional details
                        let _additionalDetails: [DTO.TodayResult.AdditionalDetails] = {
                            guard let links = try? item.select("a.goto-race") else { return [] }
                            return links.array().compactMap { link in
                                guard let tag = try? link.text() else { return nil }
                                guard let urlString = try? link.attr("href"),
                                      let url = URL(string: "https://www.procyclingstats.com/\(urlString)") else { return nil }
                                return DTO.TodayResult.AdditionalDetails(tag: tag, url: url)
                            }
                        }()
                        todayResults.append(
                            DTO.TodayResult(
                                raceDetails: raceDetails ?? "",
                                winner: winnerURL,
                                podium: winners,
                                additionalDetails: _additionalDetails)
                        )
                    }
                    return todayResults
                }
            } else {
                assertionFailure()
                return []
            }
        } else {
            assertionFailure()
            return []
        }
        assertionFailure()
        return []
    }
*/
    // MARK: - Parsing Function -

    static func parseResultsToday(from document: Document) -> [DTO.TodayResult] {
        var results = [DTO.TodayResult]()
        let baseUrl = "https://www.procyclingstats.com/"
        
        do {
            // First, select the "Results yesterday" header and get the next <ul> with class "hp2-results"
            guard let resultsList = try document.select("h3.black-info-title:contains(Results today) + ul.hp2-results").first() else {
                print("Results yesterday list not found")
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
                
                // 3. Parse the podium winners from the table with class "top3"
                var podiumWinners = [DTO.TodayResult.Winner]()
                if let podiumRows = try? race.select("table.top3 > tbody > tr").array() {
                    for row in podiumRows {
                        let cells = try row.select("td").array()
                        if cells.count >= 4 {
                            let position = try cells[0].text()
                            
                            // Get the flag URL from the <span class="flag"> inside the second cell.
                            var flagURL: URL? = nil
                            if let flagSpan = try? cells[1].select("span.flag").first() {
                                // The flag code is expected to be in one of the classes besides "flag"
                                let classes = try flagSpan.className().split(separator: " ").map(String.init)
                                if let code = classes.first(where: { $0.lowercased() != "flag" }) {
                                    // Compose a full URL to the flag image (adjust the path as needed)
                                    flagURL = URL(string: baseUrl + "images/flags/" + code + ".png")
                                }
                            }
                            
                            let name = try cells[1].select("a").text()
                            let team = try cells[2].select("a").text()
                            let time = try cells[3].text()
                            
                            let winner = DTO.TodayResult.Winner(position: position,
                                                            flag: flagURL,
                                                            name: name,
                                                            team: team,
                                                            time: time)
                            podiumWinners.append(winner)
                        }
                    }
                }
                
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
                let resultDTO = DTO.TodayResult(raceDetails: raceDetails,
                                            winner: winnerURL,
                                            podium: podiumWinners,
                                            additionalDetails: additionalDetails)
                results.append(resultDTO)
            }
        } catch {
            print("Error parsing Results yesterday: \(error)")
        }
        
        return results
    }
    
    static func parseResultsYesterday(_ document: Document) throws -> [DTO.TodayResult] {
        var results = [DTO.TodayResult]()
        let baseUrl = "https://www.procyclingstats.com/"

       do {
           // Use an adjacent-sibling CSS selector to get the <ul> with results that immediately follows the header:
           guard let resultsUl = try document.select("h3.black-info-title:contains(Results yesterday) + ul.hp2-results").first() else {
               print("Results yesterday list not found")
               return results
           }
           let raceItems = try resultsUl.select("li.race").array()
           for race in raceItems {
               
               // 1. Extract race details (the text inside the div that shows the race name and extra info)
               // We assume that the div with inline style containing "width: calc(100% - 95px)" holds the race details.
               let detailsDiv = try race.select("div").filter { element in
                   try element.hasAttr("style") && element.attr("style").contains("width: calc(100% - 95px)")
               }.first
               let raceDetails = try detailsDiv?.text() ?? ""
               
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
               var podiumWinners = [DTO.TodayResult.Winner]()
               if let podiumRows = try? race.select("table.top3 > tbody > tr").array() {
                   for row in podiumRows {
                       let tds = try row.select("td").array()
                       if tds.count >= 4 {
                           let position = try tds[0].text()
                           
                           // Extract the flag from the <span class="flag ...">.
                           // (We assume that flags are shown via a class and that you build the URL from a known path.)
                           var flagUrl: URL? = nil
                           if let flagSpan = try? tds[1].select("span.flag").first() {
                               // For example, if the span’s class is "flag no", we extract "no" as the flag code.
                               let classes = try flagSpan.className().split(separator: " ").map(String.init)
                               if let code = classes.first(where: { $0 != "flag" }) {
                                   flagUrl = URL(string: baseUrl + "images/flags/" + code + ".png")
                               }
                           }
                           
                           // The winner's name is the text of the <a> inside the second td.
                           let name = try tds[1].select("a").text()
                           // The team is in the third td.
                           let team = try tds[2].select("a").text()
                           // The time is in the fourth td.
                           let time = try tds[3].text()
                           
                           let winnerDTO = DTO.TodayResult.Winner(position: position,
                                                                flag: flagUrl,
                                                                name: name,
                                                                team: team,
                                                                time: time)
                           podiumWinners.append(winnerDTO)
                       }
                   }
               }
               
               // 4. Parse additional details from the <ul class="leaders">.
               var additionalDetails = [DTO.TodayResult.AdditionalDetails]()
               if let leaderItems = try? race.select("ul.leaders > li").array() {
                   for leader in leaderItems {
                       // The <div> inside has a "data-stage_type" attribute.
                       let tag = try leader.select("div").attr("data-stage_type")
                       // The <a> holds a link (relative URL).
                       let relUrl = try leader.select("a").attr("href")
                       let fullUrl = URL(string: baseUrl + relUrl)
                       
                       let detail = DTO.TodayResult.AdditionalDetails(tag: tag, url: fullUrl)
                       additionalDetails.append(detail)
                   }
               }
               
               // 5. Create the TodayResult DTO for this race item.
               let resultDTO = DTO.TodayResult(raceDetails: raceDetails,
                                           winner: raceWinnerUrl,
                                           podium: podiumWinners,
                                           additionalDetails: additionalDetails)
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
                print("avp - No winner-img div found in this item.")
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
                print("avp - Could not extract URL from style attribute.")
                return nil
            }
            let imageUrl = String(styleAttribute[swiftRange])
            guard let hostUrl = URL(string: "https://www.procyclingstats.com"),
                    let fullUrl = URL(string: imageUrl, relativeTo: hostUrl)
            else {
                print("avp - Failed to create full URL from imageUrl: \(imageUrl)")
                return nil
            }
            return fullUrl
        } catch {
            print("avp - Error extracting winner image: \(error)")
            return nil
        }
//        do {
//            if let imgDiv = try item.select("div.winner-img").first() {
//                let styleAttribute = try imgDiv.attr("style")
//                
//                // Regular expression to capture the URL from the style attribute.
//                // This pattern matches: url(something)
//                let pattern = "url\\(([^)]+)\\)"
//                let regex = try NSRegularExpression(pattern: pattern, options: [])
//                let nsString = styleAttribute as NSString
//                let range = NSRange(location: 0, length: nsString.length)
//                if let match = regex.firstMatch(in: styleAttribute, options: [], range: range) {
//                    // Extract the first capture group (the content between the parentheses)
//                    let urlRange = match.range(at: 1)
//                    if let swiftRange = Range(urlRange, in: styleAttribute) {
//                        let imageUrl = String(styleAttribute[swiftRange])
//
//                        guard let hostUrl = URL(string: "https://www.procyclingstats.com"),
//                              let fullUrl = URL(string: imageUrl, relativeTo: hostUrl)
//                        else {
//                            print("avp = No winner-img div found in this item.")
//                            return nil
//                        }
//                        return fullUrl
//                    }
//                }
//            } else {
//                print("avp - No winner-img div found in this item.")
//                return nil
//            }
//        } catch {
//            print("avp - No winner-img div found in this item.")
//            return nil
//        }
//        print("avp - No winner-img div found in this item.")
//        return nil
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
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            
            let document = try SwiftSoup.parse(htmlContent)
            // MARK: Extract UCI races
            if let uciSection = try document.select("div.mt30:has(h3:contains(UCI races))").first() {
                print("UCI races section found")
                if let uciTable = try uciSection.select("table.basic").first() {
                    let uciRows = try uciTable.select("tbody tr")
                    print("UCI Races:")
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
//                assertionFailure()
            }
            
            if let nationalSection = try document.select("div.mt30:has(h3:contains(National races))").first() {
                print("National races section found")
                if let nationalTable = try nationalSection.select("table.basic").first() {
                    let nationalRows = try nationalTable.select("tbody tr")
                    print("National Races:")
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
                    print("No National table found")
                }
            } else {
                print("No National races section found")
            }
            
            if let nationalSection = try document.select("div.mt30:has(h3:contains(CX races))").first() {
                print("CX races section found")
                if let nationalTable = try nationalSection.select("table.basic").first() {
                    let nationalRows = try nationalTable.select("tbody tr")
                    print("CX Races:")
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
                    print("No CX table found")
                }
            } else {
                print("No CX races section found")
            }
            
        } catch {
            assertionFailure(error.localizedDescription)
        }
        return sections
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
