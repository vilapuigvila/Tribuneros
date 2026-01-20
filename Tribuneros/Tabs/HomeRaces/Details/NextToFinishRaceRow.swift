//
//  NextToFinishRaceRow.swift
//  Tribuneros
//
//  Created by albert vila on 29/4/25.
//

import SwiftUI

struct NextToFinishRaceRow: View {
    let race: HomeRaces.Representable.RaceNext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AsyncImageView(url: URL(string: "https://flagcdn.com/w40/\(race.flagCode).png"))
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                
                TribuneruText(
                    content: race.name,
                    style: .size16WeightSemiBold
                )
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    TagView(text: "ETA - \(race.eta)")
                    TagView(text: "Duration - \(race.duration)")
                    TagView(text: "\(race.distance) - Kms")
                    TagView(text: race.category)
                    TagView(text: race.raceType)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(2)
    }
    
    struct TagView: View {
        let text: String
        
        var body: some View {
            Group {
                if text.isEmpty {
                    EmptyView()
                } else {
                    TribuneruText(
                        content: text,
                        style: .size13WeightRegular
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
        }
    }
}

#Preview {
    VStack {
        NextToFinishRaceRow(
            race: HomeRaces.Representable.RaceNext(
                eta: "12:12",
                duration: "2H.",
                name: "Tour du Lord Grand Depart",
                category: "UCI",
                raceType: "WE",
                distance: "123",
                urlPath: nil,
                flagCode: "fr"
            )
        )
    }
    .background(Color.tribuneru(.greenCardBackground))
}
