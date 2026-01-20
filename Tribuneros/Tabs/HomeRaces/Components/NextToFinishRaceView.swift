//
//  NextToFinishView.swift
//  Tribuneros
//
//  Created by albert vila on 10/3/25.
//

import SwiftUI

struct NextToFinishRaceView: View {
    @State private var isFullList: Bool = false
    @State private var infoBtnOpacity: Bool = true
    
    let races: [HomeRaces.Representable.RaceNext]
    let onTap: (Int) -> Void
    
    var body: some View {
        buildNextToFinish(races)
    }
    
    var filteredRaces: [HomeRaces.Representable.RaceNext] {
        if isFullList {
            races
        } else {
            Array(races.prefix(2))
        }
    }
    
    private func buildNextToFinish(_ races: [HomeRaces.Representable.RaceNext]) -> some View {
        VStack(spacing: 12) {
            HeaderRaceCardView(
                title: "Today - Next to finish",
                isSpoilerModeOn: false
            )
            VStack(spacing: 12) {
                ForEach(Array(filteredRaces.enumerated()), id: \.element.id) { index, item in
                    NextToFinishRaceRow(race: item)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onTap(index)
                        }
                    TribunerosDivider()
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, races.count > 2 ? 0 : 16)
            
            if races.count > 2 {
                Button {
                    infoBtnOpacity = false
                    
                    withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
                        isFullList.toggle()
                    }
                    withAnimation(.easeInOut(duration: 0.3).delay(0.3)) {
                        infoBtnOpacity = true
                    }
                } label: {
                    TribuneruText(
                        content: isFullList ? "Show less" : "More info",
                        style: .size13WeightRegular,
                        color: .cyan.opacity(0.8)
                    )
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.6), lineWidth: 0.5)
                            .opacity(infoBtnOpacity ? 1 : 0)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
        }
    }
    
    private func buildTextForHeaderView(_ text: String, width: CGFloat) -> some View {
        TribuneruText(content: text, style: .size13WeightRegular, color: .gray)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .background(.gray.opacity(0.2))
            .frame(width: width, alignment: .leading)
    }
        
    private func buildHeaderNextToFinishSection(_ width: CGFloat) -> some View {
        HStack(spacing: 0) {
            buildTextForHeaderView("ETA", width: width * 0.23)
            buildTextForHeaderView("Race", width: width * 0.54)
            buildTextForHeaderView("CAT.", width: width * 0.0925)
            buildTextForHeaderView("KM", width: width * 0.0925)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.gray.opacity(0.6), lineWidth: 0.5)
                .padding()
        )
    }
    
    private func buildTextForRaceFinishedValue(_ text: String, width: CGFloat) -> some View {
        TribuneruText(content: text, style: .size14WeightSemiBold)
            .font(.system(size: 13, weight: .bold, design: .default))
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
//            .debugBackground()
    }
}

extension HomeRaces.Representable.RaceNext {
    static var mockList: [HomeRaces.Representable.RaceNext] {
        [
            .init(
                eta: "12:34",
                duration: "2H",
                name: "Paris-Nice",
                category: "UCI",
                raceType: "2.UWT",
                distance: "190",
                urlPath: nil,
                flagCode: ""
            ),
            .init(
                eta: "13:34",
                duration: "2:35H",
                name: "Tour Romandia",
                category: "UCI",
                raceType: "2.UWT",
                distance: "190",
                urlPath: nil,
                flagCode: ""
            ),
            .init(
                eta: "12:31",
                duration: "3H",
                name: "Tour du France",
                category: "UCI",
                raceType: "2.UWT",
                distance: "230",
                urlPath: nil,
                flagCode: ""
            ),
            .init(
                eta: "02:31",
                duration: "3H",
                name: "Tour du Suissa",
                category: "UCI",
                raceType: "2.UWT",
                distance: "230",
                urlPath: nil,
                flagCode: ""
            ),
            .init(
                eta: "09:31",
                duration: "3H",
                name: "Amstel Gold Race",
                category: "UCI",
                raceType: "2.UWT",
                distance: "230",
                urlPath: nil,
                flagCode: ""
            ),
            .init(
                eta: "12:12",
                duration: "3H",
                name: "Tour du Flandes",
                category: "UCI",
                raceType: "2.UWT",
                distance: "230",
                urlPath: nil,
                flagCode: ""
            )
        ]
    }
}


#Preview {
    ScrollView {
        NextToFinishRaceView(races: HomeRaces.Representable.RaceNext.mockList) { index in
            
        }
        .background(Color.tribuneru(.greenCardBackground))
        .cornerRadius(8)
    }
    .padding()
}
