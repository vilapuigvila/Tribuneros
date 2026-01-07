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
                            CalendarView(representable: representable) {
                                action(.didTapOnNextRaces)
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
    
    private struct CalendarView: View {
        let representable: CXRaces.Representable
        let action: () -> Void
        
        var body: some View {
            VStack(alignment: .leading) {
                TribuneruText(content: "Next races", style: .size20WeightBold)
                    .padding(.bottom, 12)
                
                if representable.nextThreeEvents().isEmpty {
                    TribuneruText(
                        content: "👨‍🚒 Calendar is empty.. something went wrong",
                        style: .size16WeightBold,
                        color: .red,
                        lineLimit: 2
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(representable.nextThreeEvents().indices, id: \.self) { idx in
                            let event = representable.nextThreeEvents()[idx]
                            HStack(spacing: 0) {
                                TribuneruText(
                                    content: event.date,
                                    style: .size14WeightRegular
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
                                    style: .size14WeightRegular
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                            .padding(.leading, 12)
                            .padding(.trailing, 4)
                            
                        }
                        TribuneruText(content: "more races..", style: .size12WeightRegular, color: .cyan)
                            .frame(maxWidth: .infinity , alignment: .trailing)
                            .padding(.vertical, 6)
                            .padding(.trailing, 8)
                    }
                    .background(Color.tribuneru(.greenCardBackground))
                    .cornerRadius(8)
                    .onTapGesture {
                        action()
                    }
                }
            }
        }
    }
}

#if DEBUG

// MARK: - Mocks -

extension CXRaces.Representable {
    static var mockEmpty: Self {
        .init(calendarEvents: [], races: .init(sections: []))
    }
    
    static var mock: Self {
        let calendarEvents: [DTO.CXCalendarEvent] = [
            .init(
                date: "31-12-2099",
                race: "CX World Cup",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                winnerName: "Rider One",
                isCancelled: false,
                raceID: 99901,
                raceSlug: "cx-world-cup",
                raceURL: URL(string: "https://cyclocross24.com/race/cx-world-cup/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/99901/"),
                videoURL: URL(string: "https://cyclocross24.com/race/99901/#video"),
                websiteURL: URL(string: "https://www.ucicyclocrossworldcup.com"),
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/rider-one/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: "01-01-2100",
                race: "Belgian National Championships Mol",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                winnerName: "Rider Two",
                isCancelled: false,
                raceID: 99902,
                raceSlug: "mol",
                raceURL: URL(string: "https://cyclocross24.com/race/mol/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/99902/"),
                videoURL: nil,
                websiteURL: nil,
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/rider-two/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: "02-01-2100",
                race: "Belgian National Championships Beringen or Mol",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                winnerName: "Rider Three",
                isCancelled: false,
                raceID: 99903,
                raceSlug: "beringen-or-mol",
                raceURL: URL(string: "https://cyclocross24.com/race/beringen-or-mol/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/99903/"),
                videoURL: nil,
                websiteURL: nil,
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/rider-three/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
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
#Preview("Loaded Empty data") {
    CXRaces.MainView(state: .loaded(.mockEmpty)) { _ in }
}

#endif
