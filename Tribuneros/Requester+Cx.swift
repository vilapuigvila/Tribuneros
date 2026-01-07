//
//  Requester+Cx.swift
//  Tribuneros
//
//  Created by albert vila on 16/10/25.
//

import Foundation
#if canImport(FoundationXML)
import FoundationXML // Necessary for XML parsing on certain platforms
#endif
import `SwiftSoup` // Add SwiftSoup for HTML parsing

extension Requester {
    private static let cx24BaseURL = URL(string: "https://cyclocross24.com")!
    
    static func getCxEvents() async throws -> DTO.CX24Homepage {
        do {
            let data = try await URLSession.shared.data(from: cx24BaseURL).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            let document = try SwiftSoup.parse(htmlContent)
            let cx = try parseCx24Homepage(document)
            return cx
        } catch {
            if (error as NSError).code != -1009 {
                nonFatalCrashlytics(false, error.localizedDescription)
            }
            throw error
        }
    }
    
    static func getCxAllCalendarEvents(season: String = "2025-2026", category: String = "ME") async throws -> [DTO.CXCalendarEvent] {
        let url = URL(string: "https://cyclocross24.com/calendar/\(season)/\(category)/")!
        do {
            let data = try await URLSession.shared.data(from: url).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            let document = try SwiftSoup.parse(htmlContent)
            let calendar = try parseCx24CalendarEvents(document)
            return calendar
        } catch {
            if (error as NSError).code != -1009 {
                nonFatalCrashlytics(false, error.localizedDescription)
            }
            throw error
        }
    }
    
    private static func parseCx24Homepage(_ document: Document) throws -> DTO.CX24Homepage {
        let sectionElements = try document.select("div.raceday:has(div.race_block)").array()
        let sections: [DTO.CX24Homepage.Section] = try sectionElements.map { sectionEl in
            let title = try sectionEl.select(".fp_title").first()?.text() ?? ""
            let raceBlocks = try sectionEl.select("div.race_block").array()
            let races: [DTO.CX24Homepage.Race] = try raceBlocks.compactMap { raceBlockEl in
                try parseCx24RaceBlock(raceBlockEl)
            }
            return DTO.CX24Homepage.Section(title: title, races: races)
        }
        
        return DTO.CX24Homepage(sections: sections)
    }
    
    private static func parseCx24RaceBlock(_ raceBlock: Element) throws -> DTO.CX24Homepage.Race? {
        guard let raceInfo = try raceBlock.select("div.race_info").first() else {
            return nil
        }
        
        let title = try raceInfo.select("h3.h3").first()?.text() ?? ""
        
        let flagImg = try raceInfo.select("div.race_info_left img.flag").first()
        let country = try flagImg?.attr("title") ?? ""
        let countryFlagURL = cx24AbsoluteURL(try flagImg?.attr("src") ?? "")
        
        let infoText = try raceInfo.select("div.race_info_bar").first()?.text() ?? ""
        let tokens = infoText.split(whereSeparator: \.isWhitespace).map(String.init)
        let date = tokens.prefix(3).joined(separator: " ")
        let location = tokens.dropFirst(3).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        let racePath = try raceInfo.select("a[href^=/race/]").first()?.attr("href") ?? ""
        let raceURL = cx24AbsoluteURL(racePath)
        
        let categoryEls = try raceBlock.select("div.race_category").array()
        let categories = try categoryEls.map { try parseCx24Category($0) }
        
        return DTO.CX24Homepage.Race(
            title: title,
            country: country,
            countryFlagURL: countryFlagURL,
            date: date,
            location: location,
            raceURL: raceURL,
            categories: categories
        )
    }
    
    private static func parseCx24Category(_ category: Element) throws -> DTO.CX24Homepage.Category {
        let categoryAnchor = try category.select("div.fp_category > a").first()
        let rawTitle = categoryAnchor?.ownText() ?? ""
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryURL = cx24AbsoluteURL(try categoryAnchor?.attr("href") ?? "")
        
        let winnerImageURL = cx24AbsoluteURL(try category.select("img.fp_image_winner").first()?.attr("src") ?? "")
        
        let podiumRows = try category.select("div.fp_rider_bar").array().prefix(3)
        let podium: [DTO.CX24Homepage.Podium] = try podiumRows.map { row in
            let positionText = try row.select("div.fp_result").first()?.text() ?? ""
            let position = Int(positionText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            
            let riderAnchor = try row.select("div.fp_rider a").first()
            let riderName = try riderAnchor?.text() ?? ""
            let riderURL = cx24AbsoluteURL(try riderAnchor?.attr("href") ?? "")
            
            let riderFlagImg = try row.select("div.fp_flag img.flag").first()
            let riderCountry = try riderFlagImg?.attr("title") ?? ""
            let riderFlagURL = cx24AbsoluteURL(try riderFlagImg?.attr("src") ?? "")
            
            let time = try row.select("div.fp_time").first()?.text() ?? ""
            
            return DTO.CX24Homepage.Podium(
                position: position,
                rider: riderName,
                riderURL: riderURL,
                country: riderCountry,
                countryFlagURL: riderFlagURL,
                time: time
            )
        }
        
        return DTO.CX24Homepage.Category(
            title: title,
            categoryURL: categoryURL,
            winnerImageURL: winnerImageURL,
            podium: podium
        )
    }
    
    private static func parseCx24CalendarEvents(_ document: Document) throws -> [DTO.CXCalendarEvent] {
        try document
            .select("tr.r1_row.ri_calendar")
            .array()
            .compactMap { row -> DTO.CXCalendarEvent? in
                let isCancelled = row.hasClass("race_cancelled") || ((try? row.select("div.cancel").first()) != nil)

                let date = try row.select("td.r1_cal_date").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let raceTd = try row.select("td.r1_cal_rider").first()
                let raceAnchor = try raceTd?.select("a[href^=/race/]").first()
                let race = try raceAnchor?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let racePath = try raceAnchor?.attr("href") ?? ""
                let raceURL = cx24AbsoluteURL(racePath)
                let raceSlug = cx24RaceCode(fromRacePath: racePath)

                let className = try row.select("td.r1_cal_class").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let flagImg = try raceTd?.select("img.flag").first()
                let flagURL = cx24AbsoluteURL(try flagImg?.attr("src") ?? "")
                let raceCountry = (try flagImg?.attr("title"))?.trimmingCharacters(in: .whitespacesAndNewlines)

                let winnerTd = try row.select("td.r1_cal_winner").first()
                let resultsAnchor = try winnerTd?.select("a[title=Results][href^=/race/]").first()
                    ?? winnerTd?.select("a[href^=/race/]").first()
                let resultsPath = try resultsAnchor?.attr("href") ?? ""
                let resultsURL = cx24AbsoluteURL(resultsPath)
                let raceID = cx24RaceID(fromRacePath: resultsPath)

                let videoPath = try row.select("td.r1_cal_yt a[href$=#video]").first()?.attr("href") ?? ""
                let videoURL = cx24AbsoluteURL(videoPath)

                let websiteHref = try row.select("td.r1_cal_web a[href]").first()?.attr("href") ?? ""
                let websiteURL = cx24AbsoluteURL(websiteHref)

                let winnerAnchor = try winnerTd?.select("a.rurl[href^=/rider/]").first()
                let winner = try winnerAnchor?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let winnerURL = cx24AbsoluteURL(try winnerAnchor?.attr("href") ?? "")

                let winnerFlagImg = try winnerTd?.select("img.flag").first()
                let winnerCountry = (try winnerFlagImg?.attr("title"))?.trimmingCharacters(in: .whitespacesAndNewlines)
                let winnerFlagURL = cx24AbsoluteURL(try winnerFlagImg?.attr("src") ?? "")

                guard !date.isEmpty, !race.isEmpty else { return nil }
                
                return DTO.CXCalendarEvent(
                    date: date,
                    race: race,
                    raceClass: className,
                    flagURL: flagURL,
                    winnerName: winner,
                    isCancelled: isCancelled,
                    raceID: raceID,
                    raceSlug: raceSlug,
                    raceURL: raceURL,
                    resultsURL: resultsURL,
                    videoURL: videoURL,
                    websiteURL: websiteURL,
                    raceCountry: raceCountry,
                    winnerURL: winnerURL,
                    winnerCountry: winnerCountry,
                    winnerFlagURL: winnerFlagURL
                )
            }
    }

    private static func cx24AbsoluteURL(_ href: String) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("//") {
            return URL(string: "https:" + trimmed)
        }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: trimmed, relativeTo: cx24BaseURL)?.absoluteURL
    }

    private static func cx24RaceCode(fromRacePath href: String) -> String? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let components = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count >= 2, components[0] == "race" else { return nil }
        return String(components[1])
    }

    private static func cx24RaceID(fromRacePath href: String) -> Int? {
        guard let code = cx24RaceCode(fromRacePath: href) else { return nil }
        return Int(code)
    }
}
