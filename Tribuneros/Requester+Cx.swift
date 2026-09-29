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

private let cacheTimeinterval = 24 * 60 * 60

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
/*
    private static func _readCxDocument<D: Decodable>(_ name: String, as type: D.Type) async throws -> D {
        try await Firestore.firestore()
            .collection("cx")
            .document(name)
            .getDocument()
            .data(as: type)
    }*/
    
    private static func readCxDocument<D: Decodable>(_ name: String, as type: D.Type) async throws -> D {
        let ref = Firestore.firestore().collection("cx").document(name)
        if let cached = try? await ref.getDocument(source: .cache),
           let updatedAt = cached.get("updatedAt") as? Timestamp,
           Date().timeIntervalSince(updatedAt.dateValue()) < Double(cacheTimeinterval) {
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
                    let results = await getCxDetail(
                        .results,
                        url: categoryURL,
                        as: ResultsDocument.self
                    )?.results
                    return (
                        category.title,
                        results?.map { $0.with(raceVideosURL: raceVideosURL) }
                    )
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

    // MARK: - Calendar event detail -

    /// Loads what the calendar-event detail shows beyond the Firestore calendar row: the race
    /// page (history of winners), and, from race day on, the Men Elite results and a video.
    static func getCxEventDetail(_ event: DTO.CXCalendarEvent, hasStarted: Bool) async -> DTO.CXEventDetail {
        async let page = getCxDetail(
            .race,
            url: event.raceURL,
            as: DTO.CXRacePage.self
        )
        async let results = fetchCxEventResults(hasStarted ? event.resultsURL : nil)
        async let video = fetchCxEventVideo(hasStarted && event.videoURL != nil ? event.resultsURL : nil)
        return await .init(page: page, results: results, videoURL: video)
    }

    private static func fetchCxEventResults(_ url: URL?) async -> [DTO.CX24Homepage.CategoryResult] {
        await getCxDetail(
            .results,
            url: url,
            as: ResultsDocument.self
        )?.results ?? []
    }

    private static func fetchCxEventVideo(_ url: URL?) async -> URL? {
        guard let url else { return nil }
        return await getYoutubeRaceURL(url)
    }

    // MARK: - Rider page -

    /// Loads the winner's rider page and, when `resultsURL` is given, their row (position 1) from
    /// that edition's results.
    static func getCxWinnerDetail(riderURL: URL?, resultsURL: URL?) async -> DTO.CXWinnerDetail {
        async let page = getCxRiderPage(riderURL)
        async let results = fetchCxEventResults(resultsURL)
        return await .init(
            page: page,
            result: results.first { $0.position == "1" }
        )
    }

    static func getCxRiderPage(_ riderURL: URL?) async -> DTO.CXRiderPage? {
        await getCxDetail(
            .rider,
            url: riderURL,
            as: DTO.CXRiderPage.self
        )
    }

    // MARK: - Detail page cache -

    /// A cyclocross24 page parsed and cached in Firestore by the `cxDetail` Cloud Function.
    enum CxDetailKind: String {
        case rider, race, results

        var collection: String {
            switch self {
            case .rider: "cxRiders"
            case .race: "cxRaces"
            case .results: "cxResults"
            }
        }

        /// Mirrors the function's refresh policy; `nil` means a stored copy never goes stale.
        var maxAge: TimeInterval? {
            switch self {
            case .rider: Double(cacheTimeinterval)
            case .race: Double(7 * cacheTimeinterval)
            case .results: nil
            }
        }

        /// The document id for a cyclocross24 link: the slug of `/rider/<slug>/` or `/race/<slug>/`,
        /// or the number of a results page, `/race/<id>/`. Anything else has no cached page.
        func id(for url: URL?) -> String? {
            guard let url, url.host()?.hasSuffix("cyclocross24.com") == true else { return nil }
            let components = url.path().split(separator: "/").map(String.init)
            guard components.count >= 2,
                  components[1].wholeMatch(of: /[a-z0-9-]{1,100}/) != nil else { return nil }
            let id = components[1]
            let isNumeric = id.wholeMatch(of: /[0-9]{1,9}/) != nil
            switch self {
            case .rider: return components[0] == "rider" ? id : nil
            case .race: return components[0] == "race" && !isNumeric ? id : nil
            case .results: return components[0] == "race" && isNumeric ? id : nil
            }
        }

        func isFresh(updatedAt: Date?, now: Date = Date()) -> Bool {
            guard let updatedAt else { return false }
            guard let maxAge else { return true }
            return now.timeIntervalSince(updatedAt) < maxAge
        }
    }

    private struct ResultsDocument: Decodable {
        let results: [DTO.CX24Homepage.CategoryResult]
    }

    /// Reads the cached page from Firestore. A missing copy is built by `cxDetail`; a stale one is
    /// returned at once while `cxDetail` refreshes it for next time.
    private static func getCxDetail<D: Decodable>(
        _ kind: CxDetailKind,
        url: URL?,
        as type: D.Type
    ) async -> D? {
        guard let id = kind.id(for: url) else { return nil }
        let ref = Firestore.firestore().collection(kind.collection).document(id)

        var cached: D?
        do {
            var snapshot = try? await ref.getDocument(source: .cache)
            if snapshot?.exists != true || !kind.isFresh(updatedAt: snapshot?.cxUpdatedAt) {
                snapshot = try await ref.getDocument()
            }
            if let snapshot, snapshot.exists {
                cached = try snapshot.data(as: type)
                if kind.isFresh(updatedAt: snapshot.cxUpdatedAt) {
                    return cached
                }
            }
        } catch {
            reportCxDetailError(error, "Failed to read \(kind.collection)/\(id)")
        }

        if let cached {
            Task.detached(priority: .background) {
                _ = try? await requestCxDetail(kind, id: id)
            }
            return cached
        }
        do {
            return try JSONDecoder().decode(type, from: try await requestCxDetail(kind, id: id))
        } catch CxDetailError.unavailable {
            // cyclocross24 has no such page (yet), e.g. results before the race ends; logged server-side.
            return nil
        } catch {
            reportCxDetailError(error, "cxDetail \(kind.rawValue)/\(id) failed")
            return nil
        }
    }

    private enum CxDetailError: Error {
        case unavailable
        case status(Int)
    }

    private static func requestCxDetail(_ kind: CxDetailKind, id: String) async throws -> Data {
        var components = URLComponents(url: cxDetailURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "kind", value: kind.rawValue),
            URLQueryItem(name: "id", value: id)
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return data
        case 502: throw CxDetailError.unavailable
        case let status: throw CxDetailError.status(status ?? 0)
        }
    }

    private static var cxDetailURL: URL {
        #if DEBUG
        if isFirebaseEmulatorEnabled {
            return URL(string: "http://127.0.0.1:5001/tribunerus-4a0ee/europe-west1/cxDetail")!
        }
        #endif
        return URL(string: "https://europe-west1-tribunerus-4a0ee.cloudfunctions.net/cxDetail")!
    }

    private static func reportCxDetailError(_ error: Error, _ message: String) {
        let nsError = error as NSError
        let isOffline = nsError.code == NSURLErrorNotConnectedToInternet
            || (nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.unavailable.rawValue)
        guard !Task.isCancelled, !isOffline else { return }
        nonFatalCrashlytics(
            false,
            "\(message): \(error.localizedDescription)"
        )
    }

    // MARK: - Local emulators -

    /// DEBUG runs launched with `FIREBASE_EMULATOR=1` read Firestore and call `cxDetail` on the local
    /// Firebase emulators (`firebase emulators:start`) instead of the live project.
    static let isFirebaseEmulatorEnabled: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.environment["FIREBASE_EMULATOR"] == "1"
        #else
        false
        #endif
    }()

    /// Must run before anything else touches Firestore.
    static func useFirebaseEmulatorIfEnabled() {
        guard isFirebaseEmulatorEnabled else { return }
        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.cacheSettings = MemoryCacheSettings()
        Firestore.firestore().settings = settings
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
}

private extension DocumentSnapshot {
    var cxUpdatedAt: Date? {
        (get("updatedAt") as? Timestamp)?.dateValue()
    }
}

private extension DTO.CX24Homepage.CategoryResult {
    func with(raceVideosURL: URL?) -> Self {
        .init(
            position: position,
            rider: rider,
            age: age,
            team: team,
            time: time,
            countryFlagURL: countryFlagURL,
            raceVideosURL: raceVideosURL,
            riderURL: riderURL
        )
    }
}
