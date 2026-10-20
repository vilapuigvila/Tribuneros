//
//  Service+Press.swift
//  Tribuneros
//

import Foundation
import SwiftSoup
import Alfy

extension Service {

    private static let pressUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    private static let pressArticleLimit = 30
    private static let pressSummaryLimit = 240

    /// A site's latest headlines; `nil` when no feed can be found, loaded or parsed, or it is empty.
    static func getPressFeed(for siteURL: URL) async -> DTO.PressFeed? {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            return PaddockMock.pressFeed(for: siteURL)
        }
        #endif
        var candidates: [URL] = []
        do {
            let homepage = try await fetchPressData(siteURL)
            if let html = String(data: homepage, encoding: .utf8),
               let discovered = pressFeedURL(fromHomepage: html, siteURL: siteURL) {
                candidates.append(discovered)
            }
        } catch {
            reportPressError(error, "Press homepage")
        }
        for path in ["/feed/", "/rss/", "/sitemap/news.xml"] {
            if let guess = URL(string: path, relativeTo: siteURL)?.absoluteURL, !candidates.contains(guess) {
                candidates.append(guess)
            }
        }
        for (index, candidate) in candidates.enumerated() {
            do {
                let data = try await fetchPressData(candidate)
                if let feed = parsePressFeed(data) {
                    return feed
                }
            } catch {
                // Only the discovered address is worth a report; the others are guesses.
                if index == 0, candidates.count > 3 {
                    reportPressError(error, "Press feed")
                }
            }
        }
        return nil
    }

    private static func fetchPressData(_ url: URL) async throws -> Data {
        let (data, _) = try await Requester
            .makeRequest(url.absoluteString)
            .header(.custom(headerField: "User-Agent", value: pressUserAgent))
            .ttl(60 * 30)
            .cacheControlBehavior(.ignoreServer)
            .send()
        return data
    }

    private static func reportPressError(_ error: Error, _ context: String) {
        if !isOffline(error) {
            nonFatalCrashlytics(false, "\(context): \(error.localizedDescription)")
        }
    }

    // MARK: - Discovery -

    /// The first RSS or Atom `<link rel="alternate">` of a homepage, comment feeds skipped.
    static func pressFeedURL(fromHomepage html: String, siteURL: URL) -> URL? {
        guard let document = try? SwiftSoup.parse(html),
              let links = try? document.select("link[rel=alternate]")
        else {
            return nil
        }
        for link in links.array() {
            let type = ((try? link.attr("type")) ?? "").lowercased()
            let href = ((try? link.attr("href")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let title = ((try? link.attr("title")) ?? "").lowercased()
            guard type.contains("rss+xml") || type.contains("atom+xml"),
                  !href.isEmpty,
                  !title.contains("comment"),
                  !href.lowercased().contains("comment"),
                  let url = URL(string: href, relativeTo: siteURL)?.absoluteURL,
                  url.scheme == "http" || url.scheme == "https"
            else {
                continue
            }
            return url
        }
        return nil
    }

    // MARK: - Parsing -

    /// RSS 2.0, Atom or a Google News sitemap; newest first, at most 30; `nil` when there is no article.
    static func parsePressFeed(_ data: Data) -> DTO.PressFeed? {
        let reader = PressFeedReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        parser.shouldProcessNamespaces = false
        _ = parser.parse()
        var seen = Set<URL>()
        let articles = reader.articles.filter { seen.insert($0.url).inserted }
        guard !articles.isEmpty else {
            return nil
        }
        let sorted = articles.enumerated().sorted { lhs, rhs in
            switch (lhs.element.date, rhs.element.date) {
            case let (left?, right?) where left != right:
                return left > right
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            default:
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
        return DTO.PressFeed(articles: Array(sorted.prefix(pressArticleLimit)))
    }

    /// Tags stripped, entities decoded, whitespace collapsed, cut at a word near 240 characters.
    static func pressSummary(_ raw: String) -> String? {
        let text = ((try? SwiftSoup.parse(raw).text()) ?? raw)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else {
            return nil
        }
        guard collapsed.count > pressSummaryLimit else {
            return collapsed
        }
        var cut = String(collapsed.prefix(pressSummaryLimit))
        if let space = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: space) > pressSummaryLimit / 2 {
            cut = String(cut[..<space])
        }
        return cut.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:.-")) + "…"
    }

    static func pressDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) {
            return date
        }
        if let date = ISO8601DateFormatter().date(from: trimmed) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, d MMM yyyy HH:mm:ss Z",
            "dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd"
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }
}

/// One pass over RSS `item`, Atom `entry` or sitemap `url` elements, keyed by raw (prefixed) names.
private final class PressFeedReader: NSObject, XMLParserDelegate {

    private struct Draft {
        var title = ""
        var link = ""
        var date = ""
        var summary = ""
        var image = ""
    }

    private(set) var articles: [DTO.PressFeed.Article] = []
    private var root: String?
    private var draft: Draft?
    private var text = ""

    private var entryName: String {
        switch root {
        case "feed":
            return "entry"
        case "urlset":
            return "url"
        default:
            return "item"
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if root == nil {
            root = elementName
        }
        text = ""
        if elementName == entryName {
            draft = Draft()
            return
        }
        guard draft != nil else {
            return
        }
        switch elementName {
        case "link" where root == "feed":
            let rel = attributeDict["rel"] ?? "alternate"
            if rel == "alternate", let href = attributeDict["href"], draft?.link.isEmpty == true {
                draft?.link = href
            }
        case "media:content", "media:thumbnail":
            let isImage = elementName == "media:thumbnail"
                || (attributeDict["medium"] ?? "image") == "image"
                && !(attributeDict["type"] ?? "image/").hasPrefix("video")
            if isImage, draft?.image.isEmpty == true, let url = attributeDict["url"] {
                draft?.image = url
            }
        case "enclosure":
            if draft?.image.isEmpty == true,
               (attributeDict["type"] ?? "").hasPrefix("image"),
               let url = attributeDict["url"] {
                draft?.image = url
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer { text = "" }
        guard let current = draft else {
            return
        }
        if elementName == entryName {
            finish(current)
            draft = nil
            return
        }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return
        }
        switch (root ?? "", elementName) {
        case (_, "title"), (_, "news:title"):
            if draft?.title.isEmpty == true || elementName == "news:title" {
                draft?.title = value
            }
        case (_, "link"), (_, "loc"):
            if draft?.link.isEmpty == true {
                draft?.link = value
            }
        case (_, "pubDate"), (_, "dc:date"), (_, "published"), (_, "news:publication_date"):
            draft?.date = value
        case ("feed", "updated"):
            if draft?.date.isEmpty == true {
                draft?.date = value
            }
        case (_, "description"), ("feed", "summary"):
            draft?.summary = value
        case (_, "image:loc"):
            if draft?.image.isEmpty == true {
                draft?.image = value
            }
        default:
            break
        }
    }

    private func finish(_ draft: Draft) {
        func web(_ string: String) -> URL? {
            guard let url = URL(string: string), url.scheme == "http" || url.scheme == "https" else {
                return nil
            }
            return url
        }
        let title = Service.pressSummary(draft.title) ?? ""
        guard !title.isEmpty, let url = web(draft.link) else {
            return
        }
        // Some feeds only carry the picture inside the description HTML.
        let embeddedImage = draft.summary.range(
            of: #"<img[^>]+src="([^"]+)""#,
            options: .regularExpression
        ).flatMap { range -> String? in
            let tag = String(draft.summary[range])
            return tag.components(separatedBy: "src=\"").last?.components(separatedBy: "\"").first
        }
        articles.append(
            DTO.PressFeed.Article(
                title: title,
                url: url,
                date: Service.pressDate(draft.date),
                imageURL: web(draft.image) ?? embeddedImage.flatMap(web),
                summary: Service.pressSummary(draft.summary)
            )
        )
    }
}
