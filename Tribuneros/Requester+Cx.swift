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
import FirebaseFirestore

extension Service {
    private static let cx24BaseURL = URL(string: "https://cyclocross24.com")!
    
    static func getCxEvents() async throws -> DTO.CX24Homepage {
        try await readCxDocument("homepage", as: DTO.CX24Homepage.self)
    }

    static func getCxStandings() async throws -> DTO.CXStandings {
        try await readCxDocument("standings", as: DTO.CXStandings.self)
    }

    static func getCxAllCalendarEvents() async throws -> [DTO.CXCalendarEvent] {
        try await readCxDocument("calendar", as: CalendarDocument.self).events
    }

    private struct CalendarDocument: Decodable {
        let events: [DTO.CXCalendarEvent]
    }

    private static func _readCxDocument<D: Decodable>(_ name: String, as type: D.Type) async throws -> D {
        try await Firestore.firestore()
            .collection("cx")
            .document(name)
            .getDocument()
            .data(as: type)
    }
    
    private static func readCxDocument<D: Decodable>(_ name: String, as type: D.Type) async throws -> D {
        let ref = Firestore.firestore().collection("cx").document(name)
        if let cached = try? await ref.getDocument(source: .cache),
           let updatedAt = cached.get("updatedAt") as? Timestamp,
           Date().timeIntervalSince(updatedAt.dateValue()) < 24 * 60 * 60 {
            return try cached.data(as: type)
        }
        return try await ref.getDocument().data(as: type)
    }
    
    private static func extractFirstYouTubeVideoID(from html: String) -> String? {
        let patterns = [
            "\"videoId\":\"([a-zA-Z0-9_-]{11})\"",
            "watch\\?v=([a-zA-Z0-9_-]{11})",
            "embed/([a-zA-Z0-9_-]{11})"
        ]
        let range = NSRange(html.startIndex..<html.endIndex, in: html)

        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern)
            if let match = regex?.firstMatch(in: html, range: range),
               let idRange = Range(match.range(at: 1), in: html) {
                return String(html[idRange])
            }
        }

        return nil
    }
    
    static func getYoutubeRaceURL(_ raceURL: URL) async -> URL? {
        do {
            let raceRequest = URLRequest(
                url: raceURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            let data = try await URLSession.shared.data(for: raceRequest).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            let document = try SwiftSoup.parse(htmlContent)
            if let embedIframe = try document
                .select("iframe[data-src*=youtube.com/embed], iframe[src*=youtube.com/embed]")
                .first() {
                let dataSrc = try embedIframe.attr("data-src")
                let src = try embedIframe.attr("src")
                let embedURLString = dataSrc.isEmpty ? src : dataSrc
                if let videoId = extractFirstYouTubeVideoID(from: embedURLString),
                   let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
                    return url
                }
            }
            let title = try document.select("h1, h3").text()
            let query = title + " cyclocross"
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            let searchURLStrings = [
                "https://www.youtube.com/results?search_query=\(encodedQuery ?? "")",
                "https://m.youtube.com/results?search_query=\(encodedQuery ?? "")"
            ]
            var lastError: Error?

            for searchURLString in searchURLStrings {
                guard let searchURL = URL(string: searchURLString) else { continue }
                var searchRequest = URLRequest(
                    url: searchURL,
                    cachePolicy: .reloadIgnoringLocalCacheData,
                    timeoutInterval: 30
                )
                searchRequest.setValue(
                    "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                    forHTTPHeaderField: "User-Agent"
                )
                searchRequest.setValue(
                    "en-US,en;q=0.9",
                    forHTTPHeaderField: "Accept-Language"
                )

                do {
                    let youtubeURLData = try await URLSession.shared.data(for: searchRequest).0
                    let html = String(decoding: youtubeURLData, as: UTF8.self)
                    if let videoId = extractFirstYouTubeVideoID(from: html),
                       let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") {
                        return url
                    }
                } catch {
                    lastError = error
                }
            }

            if let lastError, (lastError as NSError).code != -1009 {
                nonFatalCrashlytics(
                    false,
                    "Failed to fetch race videos: \(lastError.localizedDescription)"
                )
            }
            return nil
        } catch {
            if (error as NSError).code != -1009 {
                nonFatalCrashlytics(
                    false,
                    "Failed to fetch race videos: \(error.localizedDescription)"
                )
            }
            return nil
        }
        
    }

    static func getCxRaceCategoryResults(_ race: DTO.CX24Homepage.Race) async throws -> [String: [DTO.CX24Homepage.CategoryResult]] {
        var allResults: [String: [DTO.CX24Homepage.CategoryResult]] = [:]
        var raceVideosURL: URL?

        if let raceURL = race.raceURL {
            raceVideosURL = await getYoutubeRaceURL(raceURL)
        }
        
        await withTaskGroup(of: (String, [DTO.CX24Homepage.CategoryResult]?).self) { group in
            for category in race.categories {
                guard let categoryURL = category.categoryURL else { continue }
                
                group.addTask {
                    do {
                        let data = try await URLSession.shared.data(from: categoryURL).0
                        guard let htmlContent = String(data: data, encoding: .utf8) else {
                            throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
                        }
                        let document = try SwiftSoup.parse(htmlContent)
                        let results = try parseCx24CategoryResults(
                            document,
                            raceVideosURL: raceVideosURL
                        )
                        return (category.title, results)
                    } catch {
                        nonFatalCrashlytics(false, "Failed to fetch category results: \(error.localizedDescription)")
                        return (category.title, nil)
                    }
                }
            }
            for await (categoryTitle, results) in group {
                if let results = results {
                    allResults[categoryTitle] = results
                }
            }
        }
        return allResults
    }
    
    private static func parseCx24CategoryResults(
        _ document: Document,
        raceVideosURL: URL?
    ) throws -> [DTO.CX24Homepage.CategoryResult] {
        // Try different selectors - the site might use different classes
        var rows = try document.select("tr.r1_row").array()
        
        // If no r1_row found, try generic table rows
        if rows.isEmpty {
            rows = try document.select("table tr").array()
        }
        
        return try rows.compactMap { row -> DTO.CX24Homepage.CategoryResult? in
            let cells = try row.select("td").array()
            guard cells.count >= 5 else { return nil }
            
            let position = try cells[0].text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !position.isEmpty, Int(position) != nil else { return nil }
            
            let riderCell = cells[1]
            let rider = try riderCell.select("a").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines)
                ?? riderCell.text().trimmingCharacters(in: .whitespacesAndNewlines)
            
            let flagImg = try riderCell.select("img.flag").first()
            let countryFlagURL = cx24AbsoluteURL(try flagImg?.attr("src") ?? "")
            
            let age = try cells[2].text().trimmingCharacters(in: .whitespacesAndNewlines)
            let team = try cells[3].text().trimmingCharacters(in: .whitespacesAndNewlines)
            let time = try cells[4].text().trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard !rider.isEmpty else { return nil }
            
            return DTO.CX24Homepage.CategoryResult(
                position: position,
                rider: rider,
                age: age,
                team: team,
                time: time,
                countryFlagURL: countryFlagURL,
                raceVideosURL: raceVideosURL
            )
        }
    }
/*
    private static func parseCx24RaceVideosURL(_ document: Document) throws -> URL? {
        let directLink = try document
            .select("div.race_videos a[href], div.race_video a[href], td.r1_race_videos a[href], td.r1_race_yt a[href]")
            .first()
        if let href = try directLink?.attr("href"), let url = cx24AbsoluteURL(href) {
            return url
        }

        let labelSelectors = [
            "td:matchesOwn((?i)^Race videos?$)",
            "th:matchesOwn((?i)^Race videos?$)",
            "div:matchesOwn((?i)^Race videos?$)",
            "span:matchesOwn((?i)^Race videos?$)"
        ]

        for selector in labelSelectors {
            if let label = try document.select(selector).first() {
                if let link = try label.parent()?.select("a[href]").first()
                    ?? label.nextElementSibling()?.select("a[href]").first()
                    ?? label.parent()?.nextElementSibling()?.select("a[href]").first()
                {
                    let href = try link.attr("href")
                    if let url = cx24AbsoluteURL(href) {
                        return url
                    }
                }
            }
        }

        let fallbackLink = try document
            .select("a[href*=\"youtube.com\"], a[href*=\"youtu.be\"], a[href*=\"vimeo.com\"]")
            .first()
        let href = try fallbackLink?.attr("href") ?? ""
        return cx24AbsoluteURL(href)
    }*/

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
}
