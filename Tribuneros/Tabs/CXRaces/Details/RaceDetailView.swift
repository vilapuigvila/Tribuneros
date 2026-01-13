//
//  RaceDetailView.swift
//  Tribuneros
//
//  Created by albert vila on 13/1/26.
//

import SwiftUI
import SwiftSoup

struct RaceDetailView: View {
    let race: DTO.CX24Homepage.Race
    @State private var categoryResults: [String: [DTO.CX24Homepage.CategoryResult]] = [:]
    @State private var selectedCategory: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerView
                
                if isLoading {
                    LoaderView(title: "Loading results...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    TribuneruText(
                        content: "Error: \(error)",
                        style: .size14WeightRegular,
                        color: .red
                    )
                    .padding()
                } else {
                    categoryTabsView
                    resultsListView
                }
                
                Spacer()
            }
            .padding()
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .task {
            await loadCategoryResults()
        }
    }
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                CachedImageView(imageUrl: race.countryFlagURL, cornerRadius: 1)
                    .frame(width: 20)
                
                TribuneruText(
                    content: race.title,
                    style: .size16WeightSemiBold
                )
            }
            
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    TribuneruText(
                        content: race.date,
                        style: .size14WeightRegular,
                        color: .gray
                    )
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.gray)
                    TribuneruText(
                        content: race.location,
                        style: .size14WeightRegular,
                        color: .gray
                    )
                }
            }
        }
    }
    
    private var categoryTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(race.categories.indices, id: \.self) { index in
                    let category = race.categories[index]
                    CategoryTabButton(
                        title: category.title.uppercased(),
                        isSelected: selectedCategory == index
                    ) {
                        selectedCategory = index
                    }
//                    Rectangle()
//                        .frame(width: 0.5)
//                        .foregroundStyle(.gray.opacity(0.5))
                }
            }
        }
    }
    
    private var resultsListView: some View {
        VStack(spacing: 0) {
            if selectedCategory < race.categories.count {
                let category = race.categories[selectedCategory]
                let results = categoryResults[category.title] ?? []
                
                if results.isEmpty {
                    TribuneruText(
                        content: "No results available",
                        style: .size14WeightRegular,
                        color: .gray
                    )
                    .padding(.top, 20)
                } else {
                    resultsHeaderRow
                    
                    ForEach(results.indices, id: \.self) { index in
                        ResultRow(result: results[index])
                            .frame(height: 64)
                        
                        if index < results.count - 1 {
                            TribunerosDivider(
                                height: 0.5,
                                color: .gray.opacity(0.2)
                            )
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.tribuneru(.greenCardBackground))
        .cornerRadius(8)
    }
    
    private var resultsHeaderRow: some View {
        HStack(spacing: 0) {
            TribuneruText(
                content: "#",
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(width: 16, alignment: .leading)
            
            TribuneruText(
                content: "Rider",
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            
            TribuneruText(
                content: "Age",
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(width: 40, alignment: .center)
            
            TribuneruText(
                content: "Team",
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(width: 92, alignment: .leading)
            
            TribuneruText(
                content: "Time",
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.bottom, 4)
    }
    
    private func loadCategoryResults() async {
        isLoading = true
        errorMessage = nil
        
        var results: [String: [DTO.CX24Homepage.CategoryResult]] = [:]
        
        for category in race.categories {
            guard let categoryURL = category.categoryURL else { continue }
            
            do {
                let data = try await URLSession.shared.data(from: categoryURL).0
                guard let htmlContent = String(data: data, encoding: .utf8) else {
                    throw NSError(domain: "Invalid data encoding", code: 0, userInfo: nil)
                }
                let document = try SwiftSoup.parse(htmlContent)
                let categoryResults = try parseCx24CategoryResults(document)
                results[category.title] = categoryResults
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        
        categoryResults = results
        isLoading = false
    }
    
    private func parseCx24CategoryResults(_ document: Document) throws -> [DTO.CX24Homepage.CategoryResult] {
        // Try different selectors - the site might use different classes
        var rows = try document.select("tr.r1_row").array()
        
        // If no r1_row found, try generic table rows
        if rows.isEmpty {
            rows = try document.select("table tr").array()
        }
        
        // Debug: print what we found
        print("DEBUG: Found \(rows.count) rows")
        
        return try rows.compactMap { row -> DTO.CX24Homepage.CategoryResult? in
            let cells = try row.select("td").array()
            
            // Debug first few rows
            if cells.count > 0 {
                print("DEBUG: Row has \(cells.count) cells")
            }
            
            guard cells.count >= 5 else { return nil }
            
            let position = try cells[0].text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !position.isEmpty, Int(position) != nil else { return nil }
            
            let riderCell = cells[1]
            let rider = try riderCell.select("a").first()?.text().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                ?? riderCell.text().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            
            let flagImg = try riderCell.select("img.flag").first()
            let flagSrc = try flagImg?.attr("src") ?? ""
            let countryFlagURL = cx24AbsoluteURL(flagSrc)
            
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
                countryFlagURL: countryFlagURL
            )
        }
    }
    
    private func cx24AbsoluteURL(_ href: String) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let baseURL = URL(string: "https://cyclocross24.com")!
        if trimmed.hasPrefix("//") {
            return URL(string: "https:" + trimmed)
        }
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
    }
}

private struct CategoryTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            TribuneruText(
                content: title,
                style: .size14WeightSemiBold,
                color: isSelected ? .black : .white
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                isSelected
                ? Color.tribuneru(.green(brightness: 0.5))
                : Color.tribuneru(.greenCardBackground)
            )
        }
        .cornerRadius(2.5)
    }
}

private struct ResultRow: View {
    let result: DTO.CX24Homepage.CategoryResult
    
    var body: some View {
        HStack(spacing: 0) {
            TribuneruText(
                content: result.position,
                style: .size12WeightRegular
            )
            .frame(width: 16, alignment: .leading)
            
            HStack(spacing: 6) {
                if let flagURL = result.countryFlagURL {
                    CachedImageView(imageUrl: flagURL, cornerRadius: 1)
                        .frame(width: 16)
                }
                
                TribuneruText(
                    content: result.rider,
                    style: .size12WeightRegular,
                    lineLimit: 1
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            TribuneruText(
                content: result.age,
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(width: 40, alignment: .center)
            
            TribuneruText(
                content: result.team,
                style: .size12WeightRegular,
                color: .gray,
                lineLimit: 1
            )
            .frame(width: 92, alignment: .leading)
            
            TribuneruText(
                content: result.time,
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG
/*
#Preview("Race Detail") {
//    NavigationStack {
        Text("hihi")
        /*
        RaceDetailView(
            race: .init(
                title: "UCI World Cup Zonhoven (CDM)",
                country: "Belgium",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                date: "4 January 2026",
                location: "Zonhoven, Belgium",
                raceURL: URL(string: "https://cyclocross24.com/race/otegem/"),
                categories: [
                    .init(
                        title: "Men Elite",
                        categoryURL: URL(string: "https://cyclocross24.com/race/18063/"),
                        winnerImageURL: nil,
                        podium: []
                    ),
                    .init(
                        title: "Women Elite",
                        categoryURL: URL(string: "https://cyclocross24.com/race/18063/"),
                        winnerImageURL: nil,
                        podium: []
                    )
                ]
            )
        )*/
//    }
}
*/
#endif
