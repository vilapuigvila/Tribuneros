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
            .padding(8)
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .task {
            isLoading = true
            errorMessage = nil
            do {
                categoryResults = try await Requester.getCxRaceCategoryResults(race)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
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
                                height: 1,
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

#Preview("Race Detail") {
    NavigationStack {
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
                        categoryURL: URL(string: "https://cyclocross24.com/race/18062/"),
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
        )
    }
}

#endif
