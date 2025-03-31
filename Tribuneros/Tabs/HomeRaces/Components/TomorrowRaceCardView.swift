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
        GeometryReader { geometry in
//            let _ = print("avvp - \(geometry.size)")
            buildNextToFinish(races, width: geometry.size.width)
        }
    }
    
    private let paddingHorizontal = 8.0
    private func buildNextToFinish(_ races: [HomeRaces.Representable.RaceTomorrow], width: Double) -> some View {
        VStack(spacing: 0) {
            HeaderRaceCardView(title: "Races tomorrow")
            
            VStack(spacing: 0) {
                buildHeaderNextToFinishSection(width)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity)
                
                Spacer()
                
                ForEach(Array(races.prefix(4))) { item in
                    VStack(spacing: 0) {
                        HStack(spacing: 2) {
                            buildTextForRaceFinishedValue(item.start, width: width * 0.14) // 0.14
                            buildTextForRaceFinishedValue(item.name, width: width * 0.71) // 0.71
                            buildTextForRaceFinishedValue(item.eta, width: width * 0.14) // 0.14
                                .foregroundStyle(.purple)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Spacer().frame(height: 10)
                }
                Spacer()
                
                Text("+ info")
                    .font(.system(size: 9, weight: .bold, design: .default))
                    .foregroundStyle(.link)
                    .frame(alignment: .bottomLeading)
                    .offset(y: -6)
            }
            .padding(.horizontal, 8)
        }
    }
    
    private func buildTextForHeaderView(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(.gray)
            .frame(width: width, alignment: .leading)
//            .background(.gray.opacity(0.1))
    }
        
    private func buildHeaderNextToFinishSection(_ width: CGFloat) -> some View {
        HStack(spacing: 0) {
            buildTextForHeaderView("START", width: width * 0.14)
            buildTextForHeaderView("RACE", width: width * 0.71)
            buildTextForHeaderView("ETA", width: width * 0.14)
        }
    }
    
    private func buildTextForRaceFinishedValue(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .default))
            .lineLimit(1)
            .frame(width: width, alignment: .leading)
            .background(.gray.opacity(0.1))
    }
}

#Preview {
    let races = [
        HomeRaces.Representable.RaceTomorrow(start: "11:10", eta: "15:45", name: "Paris-Roubais", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "12:10", eta: "16:45", name: "Milan-Torino", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "13:10", eta: "16:45", name: "Nokere-Amstelhan", url: nil)
    ]
    GeometryReader { proxy in
        TomorrowRaceCardView(races: races)
            .frame(height: 150)
            .background(.gray.opacity(0.1))
        
        Spacer()
    }
//    .safeAreaPadding(.top)
//    .edgesIgnoringSafeArea(.all)
}

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
