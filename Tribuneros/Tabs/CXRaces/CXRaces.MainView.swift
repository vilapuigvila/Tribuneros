//
//  CXRaces.MainView.swift
//  Tribuneros
//
//  Created by albert vila on 5/1/26.
//

import SwiftUI

extension CXRaces {
    
    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets
        private let columns = [
            GridItem(.flexible(), spacing: 0)
        ]
        
        let state: CXRaces.ViewState
        let action: (CXRaces.Action) -> Void
        
        var body: some View {
            Group {
                switch state {
                case .idle:
                    Text("idle ...")
                case .loading:
                    LoaderView(title: "Requesting latest results..")
                case .error(let error):
                    Text("Error: \(error.localizedDescription)")
                case .loaded(let representable):
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 1) {
                            /// calendar
                            if representable.nextThreeEvents().isEmpty {
                                TribuneruText(content: "Calendar is empty.. something went wrong 😑", style: .size16WeightBold)
                            } else {
                                TribuneruText(content: "Next races", style: .size20WeightBold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 12)
                                VStack(spacing: 0) {
                                    ForEach(representable.nextThreeEvents().indices, id: \.self) { idx in
                                        let event = representable.nextThreeEvents()[idx]
                                        HStack(spacing: 0) {
                                            TribuneruText(
                                                content: event.date,
                                                style: .size12WeightRegular
                                            )
                                            .frame(maxWidth: 84, alignment: .leading)
//                                            .debugBackground()
                                            
                                            CachedImageView(
                                                imageUrl: event.flagURL,
                                                cornerRadius: 1
                                            )
                                            .frame(width: 20)
                                            .padding(.trailing, 12)
                                            
                                            TribuneruText(
                                                content: event.race,
                                                style: .size12WeightRegular
                                            )
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 12)
                                        .padding(.leading, 12)
                                        .padding(.trailing, 4)
                                        
                                    }
                                    TribuneruText(content: "more races..", style: .size10WeightRegular, color: .cyan)
                                        .frame(maxWidth: .infinity , alignment: .trailing)
                                        .padding(.vertical, 6)
                                        .padding(.trailing, 8)
                                }
                                .background(Color.tribuneru(.greenCardBackground))
                                .cornerRadius(8)
                                .onTapGesture {
                                    action(.didTapOnNextRaces)
                                }
                            }
                            
                            /// latests results
                            if let latestResult = representable.races.sections.first {
                                ForEach(latestResult.races.indices, id: \.self) { idx in
                                    HStack {
                                        
                                    }
                                }
                            }
                            
                            Color.clear
                                .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                        }
                        .padding()
                    }
                    .background(.black)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                action(.didAppeared)
            }
        }
    }
}

#if DEBUG

// MARK: - Mocks -

extension CXRaces.Representable {
    static var mock: Self {
        let calendarEvents: [DTO.CXCalendarEvent] = [
            .init(
                date: "31-12-2099",
                race: "CX World Cup",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                winnerName: "Rider One"
            ),
            .init(
                date: "01-01-2100",
                race: "Belgian National Championships Mol",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                winnerName: "Rider Two"
            ),
            .init(
                date: "02-01-2100",
                race: "Belgian National Championships Beringen or Mol",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                winnerName: "Rider Three"
            )
        ]
        
        let races = DTO.CX24Homepage(
            sections: [
                .init(
                    title: "Latest results",
                    races: [
                        .init(
                            title: "Mock GP",
                            country: "Belgium",
                            countryFlagURL: nil,
                            date: "31-12-2099",
                            location: "Antwerp",
                            raceURL: nil,
                            categories: [
                                .init(
                                    title: "Elite Men",
                                    categoryURL: nil,
                                    winnerImageURL: nil,
                                    podium: [
                                        .init(position: 1, rider: "Rider One", riderURL: nil, country: "Belgium", countryFlagURL: nil, time: "1:02:03"),
                                        .init(position: 2, rider: "Rider Two", riderURL: nil, country: "Netherlands", countryFlagURL: nil, time: "+0:10"),
                                        .init(position: 3, rider: "Rider Three", riderURL: nil, country: "France", countryFlagURL: nil, time: "+0:25")
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        
        return .init(calendarEvents: calendarEvents, races: races)
    }
}

extension CXRaces.ViewState {
    static var mock: Self {
        .loaded(.mock)
    }
}

// MARK: - Previews -

#Preview("Loaded") {
    CXRaces.MainView(state: .mock) { _ in }
}

#endif
