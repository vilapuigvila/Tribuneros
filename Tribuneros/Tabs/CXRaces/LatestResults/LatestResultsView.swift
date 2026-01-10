//
//  LatestResultsView.swift
//  Tribuneros
//
//  Created by albert vila on 9/1/26.
//

import SwiftUI

struct LatestResultsView: View {
    let races: DTO.CX24Homepage
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            TribuneruText(
                content: "Latest Cyclocross Results",
                style: .size20WeightBold
            )
            .padding(.bottom, 6)
            
            if let firstRace = firstRaceFromFirstSection {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        CachedImageView(imageUrl: firstRace.countryFlagURL, cornerRadius: 1)
                            .frame(width: 14)
                        
                        TribuneruText(
                            content: firstRace.title,
                            style: .size14WeightRegular,
                            lineLimit: 2
                        )
                        
                        Spacer(minLength: 0)
                    }
                    
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                            TribuneruText(
                                content: firstRace.date,
                                style: .size12WeightRegular,
                                color: .gray,
                                lineLimit: 1
                            )
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.gray)
                            TribuneruText(
                                content: firstRace.location,
                                style: .size12WeightRegular,
                                color: .gray,
                                lineLimit: 1
                            )
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 6)
                    
                    VStack(spacing: 12) {
                        ForEach(firstRace.categories.prefix(2).indices, id: \.self) { idx in
                            let category = firstRace.categories[idx]
                            CategoryResultsView(category: category)
                        }
                    }

                    HStack(spacing: 6) {
                        Spacer(minLength: 0)
                        TribuneruText(content: "more info..", style: .size12WeightRegular, color: .cyan, lineLimit: 1)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.cyan)
                    }
                    .padding(.top, 2)
                }
                .padding(12)
                .background(Color.tribuneru(.greenCardBackground))
                .cornerRadius(8)
                .onTapGesture {
                    action()
                }
            } else {
                TribuneruText(
                    content: "No results found.",
                    style: .size16WeightBold,
                    color: .red,
                    lineLimit: 2
                )
            }
        }
    }
    
    private struct FirstRaceInfo {
        let title: String
        let countryFlagURL: URL?
        let date: String
        let location: String
        let categories: [DTO.CX24Homepage.Category]
    }
    
    private var firstRaceFromFirstSection: FirstRaceInfo? {
        guard
            let section = races.sections.first,
            let race = section.races.first
        else {
            return nil
        }
        return .init(
            title: race.title,
            countryFlagURL: race.countryFlagURL,
            date: race.date,
            location: race.location,
            categories: race.categories
        )
    }
    
    private struct CategoryResultsView: View {
        let category: DTO.CX24Homepage.Category
        
        var body: some View {
            let podiums = Array(category.podium.prefix(3))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TribuneruText(
                        content: category.title.uppercased(),
                        style: .size12WeightRegular,
                        color: .gray
                    )
                    
                    Spacer(minLength: 0)
                }
                
                HStack(alignment: .top, spacing: 12) {
                    CachedImageView(
                        imageUrl: category.winnerImageURL,
                        cornerRadius: 0
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    
                    VStack(spacing: 0) {
                        ForEach(podiums.indices, id: \.self) { idx in
                            let podium = podiums[idx]
                            PodiumRow(podium: podium)
                            
                            if idx < podiums.count - 1 {
                                TribunerosDivider(height: 0.5, color: .gray.opacity(0.2))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private struct PodiumRow: View {
        let podium: DTO.CX24Homepage.Podium
        
        var body: some View {
            HStack(spacing: 10) {
                TribuneruText(
                    content: "\(podium.position)",
                    style: .size12WeightRegular,
                    color: .gray
                )
                .frame(width: 18, alignment: .leading)
                
                CachedImageView(
                    imageUrl: podium.countryFlagURL,
                    cornerRadius: 1
                )
                .frame(width: 16, height: 16)
                
                TribuneruText(
                    content: podium.rider,
                    style: .size12WeightRegular,
                    lineLimit: 1
                )
                
                Spacer(minLength: 0)
                
                TribuneruText(
                    content: podium.time,
                    style: .size12WeightRegular,
                    color: .gray,
                    lineLimit: 1
                )
            }
            .padding(.vertical, 6)
        }
    }
}
