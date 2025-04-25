//
//  NextToFinishListView.swift
//  Tribuneros
//
//  Created by albert vila on 24/4/25.
//

import SwiftUI

struct NextToFinishListView: View {
    
    let races: [HomeRaces.Representable.RaceNext]
    let didSelectRow: (Int) -> Void
    
    var body: some View {
        ScrollView {
            GeometryReader { proxy in
                VStack {
                    let _ = print("avvp - \(proxy.size.width)")
                    buildHeaderNextToFinishSection(proxy.size.width)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                        .frame(width: proxy.size.width)
                    
                    Spacer()
                    
                    ForEach(Array(races.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 16) {
                            HStack(spacing: 0) {
                                buildTextForRaceFinishedValue(item.eta, width: proxy.size.width * 0.12)
                                buildTextForRaceFinishedValue(item.duration, width: proxy.size.width * 0.11, fontSize: 10)
                                    .foregroundStyle(.purple)
                                    .multilineTextAlignment(.center)
                                    .debugBackground()
                                buildTextForRaceFinishedValue(item.name, width: proxy.size.width * 0.54)
                                buildTextForRaceFinishedValue(item.category, width: proxy.size.width * 0.0925)
                                buildTextForRaceFinishedValue(item.distance, width: proxy.size.width * 0.0925)
                            }.onTapGesture {
                                didSelectRow(index)
                            }
                            Spacer()
                        }
                    }
                }
                .background(Color.cardInfoBackground)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(.black)
    }
    
    private func buildHeaderNextToFinishSection(_ width: CGFloat) -> some View {
        HStack(spacing: 0) {
            buildTextForHeaderView("ETA", width: width * 0.23)
            buildTextForHeaderView("Race", width: width * 0.54)
            buildTextForHeaderView("CAT.", width: width * 0.0925)
            buildTextForHeaderView("KM", width: width * 0.0925)
        }
    }
    
    private func buildTextForRaceFinishedValue(_ text: String, width: CGFloat, fontSize: CGFloat = 14.0) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .default))
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
    }
    
    private func buildTextForHeaderView(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .regular, design: .monospaced))
            .foregroundStyle(.gray)
            .frame(width: width, alignment: .leading)
    }
}

#Preview {
    let races: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(eta: "12:34", duration: "2H", name: "Paris-Nice", category: "UCI", raceType: "2.UWT", distance: "190", urlPath: nil),
        HomeRaces.Representable.RaceNext(eta: "12:31", duration: "3H", name: "Tour du France", category: "UCI", raceType: "2.UWT", distance: "230", urlPath: nil),
        HomeRaces.Representable.RaceNext(eta: "12:31", duration: "3H", name: "Giro", category: "UCI", raceType: "2.UWT", distance: "230", urlPath: nil),
        HomeRaces.Representable.RaceNext(eta: "12:31", duration: "3H", name: "Romandia", category: "UCI", raceType: "2.UWT", distance: "230", urlPath: nil),
        HomeRaces.Representable.RaceNext(eta: "12:31", duration: "3H", name: "Tour swizertland", category: "UCI", raceType: "2.UWT", distance: "230", urlPath: nil),
        HomeRaces.Representable.RaceNext(eta: "12:31", duration: "3H", name: "Volta Cat", category: "UCI", raceType: "2.UWT", distance: "230", urlPath: nil)
    ]
    NextToFinishListView(races: races) { _ in
        
    }
}
