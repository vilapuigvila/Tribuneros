//
//  TomorrowRaceCardView.swift
//  Tribuneros
//
//  Created by albert vila on 18/3/25.
//

import SwiftUI

struct TomorrowRaceCardView: View {
    let races: [HomeRaces.Representable.RaceTomorrow]
    
    var body: some View {
        buildNextToFinish(races)
    }
    
    private let paddingHorizontal = 8.0

    private func buildNextToFinish(_ races: [HomeRaces.Representable.RaceTomorrow]) -> some View {
        VStack(spacing: 0) {
            HeaderRaceCardView(
                title: "Races tomorrow",
                isSpoilerModeOn: false
            )
            VStack(spacing: 12) {
                GeometryReader { geo in
                    buildHeaderNextToFinishSection(geo.size.width)
                }
                .padding(.top, 4)
                .padding(.bottom, 6)
                
                ForEach(Array(races.prefix(4))) { item in
                    GeometryReader { geo in
                        HStack(spacing: Constants.spacingLabels) {
                            buildTextForRaceFinishedValue(item.start, width: geo.size.width*Constants.startMultiplier)
                            buildTextForRaceFinishedValue(item.name, width: geo.size.width*Constants.raceMultiplier)
                            buildTextForRaceFinishedValue(item.eta, width: geo.size.width*Constants.etaMultiplier)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                Spacer()
                
                if races.count > 4 {
                    TribuneruText(content: "+ info", style: .size11WeightRegular, color: .cyan)
                        .font(.system(size: 9, weight: .bold, design: .default))
                        .frame(alignment: .bottomLeading)
                        .offset(y: -8)
                }
            }
//            .frame(maxHeight: _isSpoilerModeOn ? .infinity : 0)
//            .opacity(_isSpoilerModeOn ? 1 : 0)
            .padding(.horizontal, 8)
//            .clipped()
        }
    }
    
    private func buildTextForHeaderView(_ text: String, width: CGFloat) -> some View {
        TribuneruText(content: text, style: .size13WeightRegular, color: .gray)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .frame(width: width, alignment: .leading)
//            .background(.gray.opacity(0.1))
    }
        
    private func buildHeaderNextToFinishSection(_ width: CGFloat) -> some View {
        HStack(spacing: Constants.spacingLabels) {
            buildTextForHeaderView("START", width: width * Constants.startMultiplier)
            buildTextForHeaderView("RACE", width: width * Constants.raceMultiplier)
            buildTextForHeaderView("ETA", width: width * Constants.etaMultiplier)
        }
    }
    
    private func buildTextForRaceFinishedValue(_ text: String, width: CGFloat) -> some View {
        TribuneruText(content: text, style: .size13WeightRegular)
            .font(.system(size: 11, weight: .bold, design: .default))
            .lineLimit(1)
//            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(width: width, alignment: .leading)
            .debugBackground()
    }
    
    private enum Constants {
        static let startMultiplier: CGFloat = 0.14
        static let raceMultiplier: CGFloat = 0.71
        static let etaMultiplier: CGFloat = 0.14
        static let spacingLabels: CGFloat = 2.0
    }
}

// MARK: - Preview -

#Preview {
    let races = [
        HomeRaces.Representable.RaceTomorrow(start: "11:10", eta: "15:45", name: "Paris-Roubaix", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "12:10", eta: "16:45", name: "Milan-Torino", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "13:10", eta: "16:45", name: "Nokere-Amstelhan", url: nil)
    ]
    VStack {
        TomorrowRaceCardView(races: races)
            .background(Color.green.opacity(0.2))
            .cornerRadius(8)
        
        Spacer()
    }
    .frame(maxHeight: 160)
}

/*
struct SingleAxisGeometryReader<Content: View>: View {
    private struct SizeKey: PreferenceKey {
        static var defaultValue: CGFloat { 10 }
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    @State private var size: CGFloat = SizeKey.defaultValue
    var axis: Axis = .horizontal
    var alignment: Alignment = .center
    let content: (CGFloat)->Content

    var body: some View {
        content(size)
            .frame(maxWidth:  axis == .horizontal ? .infinity : nil,
                   maxHeight: axis == .vertical   ? .infinity : nil,
                   alignment: alignment)
            .background(GeometryReader {
                proxy in
                Color.clear.preference(key: SizeKey.self, value: axis == .horizontal ? proxy.size.width : proxy.size.height)
            }).onPreferenceChange(SizeKey.self) { size = $0 }
    }
}
*/
