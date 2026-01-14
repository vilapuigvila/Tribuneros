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

    static func getCxStandings() async throws -> DTO.CXStandings {
        do {
            let data = try await URLSession.shared.data(from: cx24BaseURL).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            let document = try SwiftSoup.parse(htmlContent)
            let base = try parseCx24StandingsLinks(document)

            var items = base.items
            await withTaskGroup(of: (Int, DTO.CXStandings.Item).self) { group in
                for (idx, item) in items.enumerated() {
                    guard let url = item.url else { continue }
                    group.addTask {
                        do {
                            return (
                                idx,
                                try await enrichStandingsItem(item, url: url, includeLeaderImage: idx == 0)
                            )
                        } catch {
                            nonFatalCrashlytics(false, error.localizedDescription)
                            return (idx, item)
                        }
                    }
                }

                for await (idx, updated) in group {
                    items[idx] = updated
                }
            }

            return DTO.CXStandings(items: items)
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

    private static func parseCx24StandingsLinks(_ document: Document) throws -> DTO.CXStandings {
        let footerLinks = try document
            .select("ul:has(li.footer_title:matchesOwn((?i)^Standings$)) a[href]")
            .array()

        let links = footerLinks.isEmpty
            ? try document.select("a[href^=/uciranking/], a[href^=/standings/]").array()
            : footerLinks

        var seenTitles = Set<String>()
        let items: [DTO.CXStandings.Item] = try links.compactMap { anchor in
            let title = try anchor.text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, seenTitles.insert(title).inserted else { return nil }
            let href = try anchor.attr("href")
            return DTO.CXStandings.Item(title: title, url: cx24AbsoluteURL(href), logoURL: nil, categories: [])
        }

        func score(_ item: DTO.CXStandings.Item) -> Int {
            guard let path = item.url?.path.lowercased() else { return 1 }
            return path.contains("uciranking") ? 0 : 1
        }

        let orderedItems = items
            .enumerated()
            .sorted { lhs, rhs in
                let l = score(lhs.element)
                let r = score(rhs.element)
                if l != r { return l < r }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        return DTO.CXStandings(items: orderedItems)
    }

    private static func enrichStandingsItem(
        _ item: DTO.CXStandings.Item,
        url: URL,
        includeLeaderImage: Bool
    ) async throws -> DTO.CXStandings.Item {
        let data = try await URLSession.shared.data(from: url).0
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
        }
        let document = try SwiftSoup.parse(htmlContent)

        let normalizedTitle = normalizedStandingsTitle((try? document.select("h1.main_title").first()?.text()) ?? item.title)
        let logoURL = parseStandingsLogo(document)
            ?? (url.path.contains("uciranking") ? cx24AbsoluteURL("/images/flag/32/UCI.png") : nil)

        let (categoriesBaseAll, selectedIndexAll) = try parseStandingsCategories(document)
        let categoriesBase = Array(categoriesBaseAll.prefix(3))
        let selectedIndex = min(selectedIndexAll, max(0, categoriesBase.count - 1))
        let currentLeaders = try parseStandingsLeaders(document)

        var categories: [DTO.CXStandings.Category] = []
        categories.reserveCapacity(categoriesBase.count)

        for (idx, baseCategory) in categoriesBase.enumerated() {
            if idx == selectedIndex {
                categories.append(
                    .init(
                        title: baseCategory.title,
                        url: baseCategory.url,
                        leaders: currentLeaders,
                        leaderImageURL: nil
                    )
                )
            } else if let categoryURL = baseCategory.url {
                do {
                    let data = try await URLSession.shared.data(from: categoryURL).0
                    guard let html = String(data: data, encoding: .utf8) else {
                        throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
                    }
                    let doc = try SwiftSoup.parse(html)
                    let leaders = try parseStandingsLeaders(doc)
                    categories.append(.init(title: baseCategory.title, url: baseCategory.url, leaders: leaders, leaderImageURL: nil))
                } catch {
                    categories.append(.init(title: baseCategory.title, url: baseCategory.url, leaders: [], leaderImageURL: nil))
                    nonFatalCrashlytics(false, error.localizedDescription)
                }
            } else {
                categories.append(.init(title: baseCategory.title, url: baseCategory.url, leaders: [], leaderImageURL: nil))
            }
        }

        if includeLeaderImage, !categories.isEmpty {
            var selected = categories[selectedIndex]
            if let riderURL = selected.leaders.first?.riderURL {
                selected = .init(
                    title: selected.title,
                    url: selected.url,
                    leaders: selected.leaders,
                    leaderImageURL: try? await fetchRiderAvatarURL(riderURL)
                )
                categories[selectedIndex] = selected
            }
        }

        return .init(
            title: normalizedTitle,
            url: item.url,
            logoURL: logoURL ?? item.logoURL,
            categories: categories
        )
    }

    private static func normalizedStandingsTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let beforeDash = title.components(separatedBy: " - ").first {
            title = beforeDash
        }
        if let yearRange = title.range(
            of: "\\b\\d{4}\\s*[-–]\\s*\\d{4}\\b",
            options: .regularExpression
        ) {
            title.removeSubrange(yearRange)
        }
        title = title
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title
    }

    private static func parseStandingsLogo(_ document: Document) -> URL? {
        let logo = (try? document.select("div.standings_logo img").first())
            ?? (try? document.select(".rid_land img.flag").first())
        let src = (try? logo?.attr("data-src")) ?? (try? logo?.attr("src"))
        return cx24AbsoluteURL(src ?? "")
    }

    private static func parseStandingsCategories(_ document: Document) throws -> (categories: [(title: String, url: URL?)], selectedIndex: Int) {
        let tabEls = try document.select("a.cx-cat[href]").array()
        if !tabEls.isEmpty {
            var categories: [(String, URL?)] = []
            categories.reserveCapacity(tabEls.count)

            var selectedIndex = 0
            for (idx, el) in tabEls.enumerated() {
                let title = try el.text().trimmingCharacters(in: .whitespacesAndNewlines)
                let href = try el.attr("href")
                categories.append((title, cx24AbsoluteURL(href)))
                let className = (try? el.attr("class")) ?? ""
                if className.contains("c10") && className.contains("t10") {
                    selectedIndex = idx
                }
            }
            return (categories, selectedIndex)
        }

        let optionEls = try document.select("select[name=cat] option[value]").array()
        var categories: [(String, URL?)] = []
        categories.reserveCapacity(optionEls.count)

        var selectedIndex = 0
        for (idx, el) in optionEls.enumerated() {
            let title = try el.text().trimmingCharacters(in: .whitespacesAndNewlines)
            let href = try el.attr("value")
            categories.append((title, cx24AbsoluteURL(href)))
            if el.hasAttr("selected") {
                selectedIndex = idx
            }
        }
        return (categories, selectedIndex)
    }

    private static func parseStandingsLeaders(_ document: Document) throws -> [DTO.CXStandings.Leader] {
        let rows = try document.select("tr.r1_row").array()
        guard !rows.isEmpty else { return [] }

        let topRows = Array(rows.prefix(5))
        return try topRows.compactMap { row in
            if let positionText = try row.select("td.r1_uci_position").first()?.text(),
               let position = Int(positionText.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                let riderAnchor = try row.select("a.rurl").first()
                let rider = try riderAnchor?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let riderURL = cx24AbsoluteURL(try riderAnchor?.attr("href") ?? "")

                let flagImg = try row.select("img.flag").first()
                let flagURL = cx24AbsoluteURL(try flagImg?.attr("src") ?? "")

                let points = try row.select("td.r1_uci_points").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !rider.isEmpty else { return nil }

                return DTO.CXStandings.Leader(
                    position: position,
                    rider: rider,
                    riderURL: riderURL,
                    countryFlagURL: flagURL,
                    points: points
                )
            } else if let positionText = try row.select("td.stand_position, td.cx24_column.stand_position").first()?.text(),
                      let position = Int(positionText.trimmingCharacters(in: .whitespacesAndNewlines))
            {
                let riderAnchor = try row.select("a.rurl").first()
                let rider = try riderAnchor?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let riderURL = cx24AbsoluteURL(try riderAnchor?.attr("href") ?? "")

                let flagImg = try row.select("img.flag").first()
                let flagURL = cx24AbsoluteURL(try flagImg?.attr("src") ?? "")

                let points = try row.select("td.stand_points, td.cx24_column.stand_points").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !rider.isEmpty else { return nil }

                return DTO.CXStandings.Leader(
                    position: position,
                    rider: rider,
                    riderURL: riderURL,
                    countryFlagURL: flagURL,
                    points: points
                )
            }
            return nil
        }
    }

    private static func fetchRiderAvatarURL(_ riderURL: URL) async throws -> URL? {
        let data = try await URLSession.shared.data(from: riderURL).0
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
        }
        let document = try SwiftSoup.parse(htmlContent)
        let img = try document.select("img.rider-avatar__image").first()
            ?? (try document.select("img[src*=/images/rider/]").first())
        let src = try img?.attr("src") ?? ""
        return cx24AbsoluteURL(src)
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
