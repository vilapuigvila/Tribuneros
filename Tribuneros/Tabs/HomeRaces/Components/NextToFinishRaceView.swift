//
//  NextToFinishView.swift
//  Tribuneros
//
//  Created by albert vila on 10/3/25.
//

import SwiftUI

struct NextToFinishRaceView: View {
    let races: [HomeRaces.Representable.RaceNext]
    
    var body: some View {
        buildNextToFinish(races)
            .frame(height: 140)
    }
    
    private let paddingHorizontal = 8.0
    private func buildNextToFinish(_ races: [HomeRaces.Representable.RaceNext]) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HeaderRaceCardView(title: "Next to finish")
                
                buildHeaderNextToFinishSection(proxy.size.width)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .frame(width: proxy.size.width)
                
                Spacer()
                
                ForEach(Array(races.prefix(2))) { item in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            buildTextForRaceFinishedValue(item.eta, width: proxy.size.width * 0.14)
                            buildTextForRaceFinishedValue(item.duration, width: proxy.size.width * 0.09)
                                .foregroundStyle(.purple)
                            buildTextForRaceFinishedValue(item.name, width: proxy.size.width * 0.54)
                            buildTextForRaceFinishedValue(item.category, width: proxy.size.width * 0.0925)
                            buildTextForRaceFinishedValue(item.distance, width: proxy.size.width * 0.0925)
                        }
                        .frame(width: proxy.size.width)
                        Spacer()
                    }
                }
                Spacer()
                
                Text("+ info")
                    .font(.system(size: 9, weight: .bold, design: .default))
                    .foregroundStyle(.link)
                    .frame(alignment: .bottomLeading)
                    .offset(y: -6)
            }
        }
    }
    
    private func buildTextForHeaderView(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.gray)
            .frame(width: width, alignment: .leading)
        //                .background(.gray.opacity(0.1))
    }
        
    private func buildHeaderNextToFinishSection(_ width: CGFloat) -> some View {
        HStack(spacing: 0) {
            buildTextForHeaderView("ETA", width: width * 0.23)
            buildTextForHeaderView("Race", width: width * 0.54)
            buildTextForHeaderView("CAT.", width: width * 0.0925)
            buildTextForHeaderView("KM", width: width * 0.0925)
        }
    }
    
    private func buildTextForRaceFinishedValue(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .default))
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
    }
}

#Preview {
    let races: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(eta: "12:34", duration: "2H", name: "Paris-Nice", category: "UCI", raceType: "2.UWT", distance: "190", isSpoilerModeOn: false),
        HomeRaces.Representable.RaceNext(eta: "12:31", duration: "3H", name: "Tour du France", category: "UCI", raceType: "2.UWT", distance: "230", isSpoilerModeOn: false)
    ]
    NextToFinishRaceView(races: races)
    Spacer()
}
