//
//  RaceFinishedCardView.swift
//  Tribuneros
//
//  Created by albert vila on 11/3/25.
//

import SwiftUI

struct RaceFinishedCardView: View {
    @State private var imageExists: Bool = true
    
    let title: String
    let races: [HomeRaces.Representable.RaceFinished]
    let paddingLabelsInRace: CGFloat = 4
    let fontSizeLabelsInfo: CGFloat = 10
    let debugOpacity: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            buildTitleNextToFinishCardView(title)
            
            ForEach(races) { race in
                VStack(spacing: 2) {
                    HStack(alignment: .top, spacing: 8) {
                        AsyncImageView(url: race.winnerImgURL)
                            .frame(width: 35)
//                          .frame(height: 112*0.41)
                            .padding(.leading, 8)
                            .scaleEffect(0.95)
                        
                        VStack(alignment: .leading, spacing: paddingLabelsInRace) {
                            Text(race.race)
                                .lineLimit(1)
                                .font(.system(size: 11, weight: .bold, design: .default))
                                .padding(.bottom, 2)
                            ForEach(race.podium) { podium in
                                HStack(spacing: 6) {
                                    Text(podium.position)
                                        .lineLimit(1)
                                        .font(.system(size: fontSizeLabelsInfo, weight: .regular, design: .monospaced))
                                    if UIImage(named: podium.countryCode) == nil {
                                        let _ = print("avvp 🔥 🔥 🔥 🔥 missing asset - \(podium.countryCode)")
                                    }
                                    Image(podium.countryCode)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 12, height: 8)
                                        .clipped()

                                    Text(podium.name)
                                        .lineLimit(1)
                                        .font(.system(size: fontSizeLabelsInfo, weight: .semibold, design: .monospaced))
                                        .frame(width: podium.team.isEmpty ? (200+(paddingLabelsInRace*2)) : 130, alignment: .leading)
                                        .background(.yellow.opacity(debugOpacity))
                                    
                                    if !podium.team.isEmpty {
                                        Text(podium.team)
                                            .lineLimit(1)
                                            .font(.system(size: fontSizeLabelsInfo, weight: .regular, design: .monospaced))
                                            .frame(width: 70, alignment: .leading)
                                            .background(.yellow.opacity(debugOpacity))
                                    }
                                    Text(podium.time)
                                        .lineLimit(1)
                                        .font(.system(size: fontSizeLabelsInfo, weight: .regular, design: .monospaced))
                                        .frame(width: 46, alignment: .leading)
                                        .background(.yellow.opacity(debugOpacity))
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
    
    private func buildTitleNextToFinishCardView(_ title: String) -> some View {
        Group {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
                Spacer()
            }
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 12)
        }
    }
}

//#Preview {
//    RaceFinishedCardView(races: [])
//}
