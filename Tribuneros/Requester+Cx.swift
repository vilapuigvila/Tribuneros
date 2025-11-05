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
    private static let baseStringURL = "https://cyclocross24.com/"
    
    static func getCxEvents() async throws {
        let url = URL(string: "https://cyclocross24.com/")!
        
        let data = try await URLSession.shared.data(from: url).0
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
        }
        let document = try SwiftSoup.parse(htmlContent)
        parseLatestResults(document)
        
    }
    
    private static func parseLatestResults(_ document: Document) {
        let title = try? document.select("h3.h3").first()?.text() ?? "Unknown race"
        let flag = try? document.select("div.race_info_left img.flag").first()?.attr("title") ?? ""
        let info = try? document.select("div.race_info_bar").text()
            
            // e.g. "16 October 2025 Ardooie, Belgium"
        let parts = info?.split(separator: " ").map(String.init) ?? []
        let date = parts.prefix(3).joined(separator: " ") // first 3 words
        let location = info?.replacingOccurrences(of: date, with: "").trimmingCharacters(in: .whitespaces)
        
        // MARK: - 2️⃣ Extract categories (Men Elite, Women Elite, etc.)
        do {
            let frontImages = try document.select("div.front_image")
            var categories: [DTO.CXResult] = []
            
            for front in frontImages {
                let categoryName = try front.select("a").text()
                
                // Find all <div class="fp_result"> after this front_image
                var results: [DTO.CXResult.RaceResult] = []
                var element = try front.nextElementSibling()
                
                while let el = element, try !el.className().contains("front_image") {
                    if el.hasClass("fp_result") {
                        let position = try el.text().split(separator: "\n").first.map(String.init) ?? ""
                        let riderName = try el.select("div.fp_rider a").text()
                        let country = try el.select("div.fp_flag img").attr("title")
                        let time = try el.select("div.fp_time").text()
                        let result = DTO.CXResult.RaceResult(position: position, rider: riderName, country: country, time: time)
                        results.append(result)
                    }
                    element = try el.nextElementSibling()
                }
                
                categories.append(DTO.CXResult(category: categoryName, results: results))
            }
            
            // podiums
            var podiums: [DTO.CategoryPodium] = []
            for front in try document.select("div.front_image").array() {
                let category = try front.select("a").text()
                var riders: [DTO.PodiumRider] = []

                var node = try front.nextElementSibling()
                while let el = node, try !el.className().contains("front_image") {
                    if el.hasClass("fp_result") {
                        let posText = el.ownText()
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let position = Int(posText) ?? 0
                        let name = try el.select("div.fp_rider a").text()
                        let country = try el.select("div.fp_flag img").attr("title")
                        let time = try el.select("div.fp_time").text()

                        riders.append(DTO.PodiumRider(position: position, name: name, country: country, time: time))
                        if riders.count == 3 { break } // only podium
                    }
                    node = try el.nextElementSibling()
                }

                if !riders.isEmpty {
                    podiums.append(DTO.CategoryPodium(name: category, riders: riders))
                }
            }
            let race = DTO.CXRace(
                title: title ?? "",
                date: date,
                location: location ?? "",
                flag: flag ?? "",
                categories: categories
            )
            print("avpv - \(race)")
            print("avpv - \(podiums)")
            
        } catch {
            nonFatalCrashlytics(false, error.localizedDescription)
        }
    }
    
}


extension DTO {
    struct CXResult: Equatable, Sendable {
        let category: String
        let results: [RaceResult]
        
        struct RaceResult: Equatable, Sendable {
            let position: String
            let rider: String
            let country: String
            let time: String
        }
    }
    
    struct CXRace: Equatable, Sendable {
        let title: String
        let date: String
        let location: String
        let flag: String
        let categories: [CXResult]
    }
    struct PodiumRider: Equatable, Sendable {
        let position: Int
        let name: String
        let country: String
        let time: String
    }

    struct CategoryPodium: Equatable, Sendable {
        let name: String
        let riders: [PodiumRider]
    }
    /*
    struct CXRaceResult: Codable, Equatable, Sendable {
        let raceName: String
        let date: String
        let location: String
        let categories: [CXCategory]
    }

    struct CXCategory: Codable, Equatable, Sendable {
        let name: String
        let winner: String
        let winnerCountry: String
        let winnerImage: String
    }*/
}

extension Data {
    
    var prettyPrintedJSON: NSString {
        if let object = try? JSONSerialization.jsonObject(with: self, options: []),
            let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
            let prettyPrintedString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
            return prettyPrintedString
                
        } else if let prettyPrintedString = NSString(data: self, encoding: String.Encoding.utf8.rawValue) {
            return prettyPrintedString
        } else {
            return "⚠️ Data can't be serialized for log, maybe no JSON response?)"
        }
    }
    
    var toDictionary: [String: Any]? {
        guard let json = try? JSONSerialization
            .jsonObject(with: self, options: .mutableContainers) as? [String: Any] else {
            return nil
        }
        return json
    }
}
