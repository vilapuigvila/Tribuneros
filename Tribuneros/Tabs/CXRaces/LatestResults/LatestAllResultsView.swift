//
//  LatestAllResultsView.swift
//  Tribuneros
//
//  Created by albert vila on 7/1/26.
//

import SwiftUI

struct LatestAllResultsView: View {
    let races: DTO.CX24Homepage
    let action: (URL?) -> Void
    
    var body: some View {
        List {
            ForEach(races.sections.indices, id: \.self) { sectionIndex in
                let section = races.sections[sectionIndex]
                Section {
                    ForEach(section.races.indices, id: \.self) { raceIndex in
                        let race = section.races[raceIndex]
                        RaceRowView(race: race)
                            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                action(race.raceURL)
                            }
                    }
                } header: {
                    TribuneruText(content: section.title, style: .size14WeightSemiBold, color: .cyan)
                        .textCase(nil)
                        .padding(.top, 8)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.black)
        .preferredColorScheme(.dark)
    }
}

private struct RaceRowView: View {
    let race: DTO.CX24Homepage.Race
//    print("avpv - share card from preview")
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                CachedImageView(imageUrl: race.countryFlagURL, cornerRadius: 1)
                    .frame(width: 14)
                
                TribuneruText(content: race.title, style: .size14WeightRegular, lineLimit: 2)
                
                Spacer(minLength: 0)
            }
            
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                    TribuneruText(
                        content: race.date,
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
                        content: race.location,
                        style: .size12WeightRegular,
                        color: .gray,
                        lineLimit: 1
                    )
                }
                
                Spacer(minLength: 0)
            }
            
            VStack(spacing: 12) {
                ForEach(race.categories.prefix(2).indices, id: \.self) { idx in
                    let category = race.categories[idx]
                    CategoryResultsView(category: category)
                }
            }
        }
        .padding(12)
        .background(Color.tribuneru(.greenCardBackground))
        .cornerRadius(8)
    }
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
                CachedImageView(imageUrl: category.winnerImageURL, cornerRadius: 999)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                
                VStack(spacing: 0) {
                    ForEach(podiums.indices, id: \.self) { idx in
                        let podium = podiums[idx]
                        PodiumRow(podium: podium)
                        
                        if idx < podiums.count - 1 {
                            TribunerosDivider(
                                height: 0.5,
                                color: .gray.opacity(0.2)
                            )
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
            
            CachedImageView(imageUrl: podium.countryFlagURL, cornerRadius: 1)
                .frame(width: 16)
            
            TribuneruText(content: podium.rider, style: .size12WeightRegular, lineLimit: 1)
            
            Spacer(minLength: 0)
            
            TribuneruText(content: podium.time, style: .size12WeightRegular, color: .gray, lineLimit: 1)
        }
        .padding(.vertical, 6)
    }
}

#if DEBUG

#Preview("Latest all results") {
    NavigationStack {
        LatestAllResultsView(races: CXRaces.Representable.mock.races) { _ in
            
        }
        .navigationTitle("Latest results")
    }
}

#endif
