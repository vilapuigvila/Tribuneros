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

struct StationModel: Decodable, Hashable, Sendable {
    let name: String
    let key: String
    let value: String
    let date: String?
}

struct Requester {
    static func cycle() {
        let url = URL(string: "https://www.procyclingstats.com/calendar/uci/today")!

        // Create a URLSession data task to fetch the HTML
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Check for errors and ensure we have data
            guard let data = data, error == nil,
                  let html = String(data: data, encoding: .utf8) else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            do {
                let document = try SwiftSoup.parse(html)
                
                // MARK: Extract UCI races
                if let uciSection = try document.select("div.mt30:has(h3:contains(UCI races))").first() {
                    print("UCI races section found")
                    if let uciTable = try uciSection.select("table.basic").first() {
                        let uciRows = try uciTable.select("tbody tr")
                        print("UCI Races:")
                        for row in uciRows {
                            let cells = try row.select("td")
                            // Expecting 5 columns: Race, Class, Cat, Winner, Exp. finish
                            if cells.count >= 5 {
                                let race = try cells.get(0).text()
                                let classification = try cells.get(1).text()
                                let cat = try cells.get(2).text()
                                let winner = try cells.get(3).text()
                                let expFinish = try cells.get(4).text()
                                
                                print("Race: \(race)")
                                print("Class: \(classification)")
                                print("Cat: \(cat)")
                                print("Winner: \(winner)")
                                print("Exp. finish: \(expFinish)")
                                print("----")
                            }
                        }
                    } else {
                        print("No UCI table found")
                    }
                } else {
                    print("No UCI races section found")
                }
                
            } catch {
                print("Error parsing HTML: \(error)")
            }
        }.resume()
    }
    
    static func requestStation(code: String, date: Date? = nil) async throws -> [StationModel] {
        assert(!code.isEmpty)
        cycle()
        let currentDate = date ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
        let formattedDate = formatter.string(from: currentDate)
        // 2025-02-01T07:00Z
        let urlString = "https://www.meteo.cat/observacions/xema/dades?codi=\(code)&dia=\(formattedDate)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }
        
        do {
            let data = try await URLSession.shared.data(from: url).0
            guard let htmlContent = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
            }
            let document = try SwiftSoup.parse(htmlContent)
            
            let stationName: String = {
                guard let fitxa = try? document.select("#fitxa-ema").first(),
                      let value = try? fitxa.select("h2").first()?.text() ?? "not found"
                else {
                    return "not found"
                }
                return value
            }()
            
            // Step 4: Select the table with the "Resum diari" data (the first <table> element)
            guard let table = try document.select("table").first() else {
                throw NSError(domain: "Invalid HTML structure", code: 0, userInfo: nil)
            }
            var items: [StationModel] = []
            
            // Step 5: Select all rows in the table (excluding the header)
            let rows = try table.select("tr")
            
            for row in rows {
                // Get the columns (either <th> for title or <td> for values)
                let columns = try row.select("th, td")
                
                // Skip rows with no useful data
                if columns.isEmpty() { continue }

                if columns.size() == 2 {
                    let title = try columns.get(0).text()
                    let value = try columns.get(1).text()
                    
                    // Step 6: Print the title and value in the desired format
                    print("\(title)\t\(value)")
                    items.append(StationModel(name: stationName, key: title, value: value, date: nil))
                }
                
                // Extract the title (first column) and value (second column)
                if columns.size() == 3 {
                    let title = try columns.get(0).text()
                    let value = try columns.get(1).text()
                    let value2 = try columns.get(2).text()
                    
                    items.append(StationModel(name: stationName, key: title, value: value, date: value2))
                }
            }
            return items
        } catch {
            assertionFailure()
            throw error
        }
    }
    
    static func fetchStations() async -> [Station] {
        do {
            let data = try await URLSession.shared.data(from: URL(string: "https://www.meteo.cat/observacions/xema")!).0
            guard let html = String(data: data, encoding: .utf8) else {
                assertionFailure()
                return []
            }
            return parseStations(from: html)
            
        } catch {
            assertionFailure(error.localizedDescription)
            return []
        }
    }

    // Function to parse the stations from the HTML using SwiftSoup
    static func parseStations(from html: String) -> [Station] {
        do {
            let doc = try SwiftSoup.parse(html)
            
            let scripts = try doc.select("script").array()
            var jsonString: String?

            for script in scripts {
                let scriptText = try script.html()
                if scriptText.contains("var meta =") {
                    if let range = scriptText.range(of: #"var meta ="#, options: .regularExpression) {
                        jsonString = String(scriptText[range.upperBound...])
                    }
                }
            }
            guard let json = jsonString else {
                assertionFailure()
                return []
            }
            
            if let jsonStart = json.range(of: "{"), let jsonEnd = json.range(of: "};") {
                let jsonSubstring = json[jsonStart.lowerBound..<jsonEnd.upperBound]
                var jsonString = String(jsonSubstring).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if jsonString.last == ";" {
                    jsonString = String(jsonString.dropLast())
                }
                guard let jsonData = jsonString.data(using: .utf8) else {
                    assertionFailure()
                    return []
                }
                do {
                    // ✅ Decode into a dictionary of stations
                    return try JSONDecoder().decode(Stations.self, from: jsonData).map { $0.value }
                } catch {
                    assertionFailure()
                    return []
                }
            } else {
                return []
            }
        } catch {
            assertionFailure()
            return []
        }
    }
}
