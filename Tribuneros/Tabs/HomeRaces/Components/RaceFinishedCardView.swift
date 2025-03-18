//
//  RaceFinishedCardView.swift
//  Tribuneros
//
//  Created by albert vila on 11/3/25.
//

import SwiftUI

struct RaceFinishedCardView: View {
    @State private var flagPng: String = ""
    
    let title: String
    let races: [HomeRaces.Representable.RaceFinished]
    let spoilerModeAction: () -> Void
    let showResultsAction: () -> Void
    
    var body: some View {
        VStack(spacing: Sizes.spacingVerticalRace) {
            HeaderRaceCardView(
                title: title,
                spoilerModeAction: spoilerModeAction,
                showResultsAction: showResultsAction
            )
            
            ForEach(races) { race in
                VStack(spacing: 2) {
                    HStack(alignment: .top, spacing: 8) {
                        AsyncImageView(url: race.winnerImgURL, cornerRadius: 4)
                            .frame(width: 45)
//                          .frame(height: 112*0.41)
                            .padding(.leading, 8)
                            .scaleEffect(Sizes.scaleEffect)
                        
                        VStack(alignment: .leading, spacing: Sizes.spacingVerticalLabelsInRace) {
                            Text(race.race)
                                .lineLimit(1)
                                .font(.system(size: 14, weight: .heavy, design: .default))
                                .padding(.bottom, 2)
                                .background(.yellow.opacity(Sizes.debugOpacity))
                            ForEach(race.podium) { podium in
                                HStack(spacing: 2) {
                                    Text(podium.position)
                                        .lineLimit(1)
                                        .font(.system(size: Sizes.fontSizeLabelsInfo, weight: .regular, design: .monospaced))
                                      
                                    /// Flag
                                    AsyncImageView(url: URL(string: "https://flagcdn.com/w40/\(podium.countryCode).png")!)
                                        .frame(width: 12, height: 8)
                                        .padding(.horizontal, 6)
                                    
                                    /// Name
                                    Text(podium.name)
                                        .lineLimit(1)
                                        .font(.system(size: Sizes.fontSizeLabelsInfo, weight: .bold, design: .monospaced))
                                        .frame(width: podium.team.isEmpty ? (200+(Sizes.spacingVerticalLabelsInRace*2)) : 130, alignment: .leading)
                                        .background(.yellow.opacity(Sizes.debugOpacity))
                                    
                                    /// Team
                                    if !podium.team.isEmpty {
                                        Text(podium.team)
                                            .lineLimit(1)
                                            .font(.system(size: Sizes.fontSizeLabelsInfo-1, weight: .semibold, design: .monospaced))
                                            .frame(width: 70, alignment: .leading)
                                            .background(.yellow.opacity(Sizes.debugOpacity))
                                    }
                                    
                                    /// Time
                                    Text(podium.time)
                                        .lineLimit(1)
                                        .font(.system(size: Sizes.fontSizeLabelsInfo-1, weight: .regular, design: .monospaced))
                                        .frame(width: 46, alignment: .leading)
                                        .background(.yellow.opacity(Sizes.debugOpacity))
                                }
                            }
                        }
//                      .background(Color.yellow.opacity(0.2))
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .padding(.vertical, 4)
                
                Divider()
            }
//          .background(Color.purple.opacity(0.4))
        }
    }
    
    private enum Sizes {
        static let spacingVerticalLabelsInRace: CGFloat = 8
        static let spacingVerticalRace: CGFloat = 8
        static let fontSizeLabelsInfo: CGFloat = 13
        static let debugOpacity: Double = 0.1
        static let scaleEffect: Double = 0.9
    }
}

//#Preview {
//    RaceFinishedCardView(races: [])
//}
