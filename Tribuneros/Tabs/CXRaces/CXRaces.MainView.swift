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
                    TribuneruText(content: "idle ...", style: .size14WeightRegular)
                        .font(.body)
                case .loading:
                    LoaderView(title: "Requesting latest results..")
                case .error(let error):
                    TribuneruText(content: "Error: \(error.localizedDescription)", style: .size14WeightRegular)
                        .font(.body)
                case .loaded(let representable):
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            /// calendar
                            CalendarView(representable: representable) {
                                action(.didTapOnNextRaces)
                            }
                            
                            /// latests results
                            LatestResultsView(races: representable.races) {
                                action(.didTapOnLatestResults)
                            }

                            /// standings
                            CyclocrossStandingsSectionView(standings: representable.standings) {
                                action(.didTapOnStandings)
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
    static var mockEmpty: Self {
        .init(calendarEvents: [], races: .init(sections: []), standings: .init(items: []))
    }
    
    static var mock: Self {
        let calendarEvents: [DTO.CXCalendarEvent] = [
            .init(
                date: "31-12-2099",
                race: "CX World Cup",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                winnerName: "Mathieu Van der Poel",
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
                            title: "UCI World Cup Zonhoven (CDM)",
                            country: "Belgium",
                            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                            date: "4 January 2026",
                            location: "Zonhoven, Belgium",
                            raceURL: nil,
                            categories: [
                                .init(
                                    title: "Men Elite",
                                    categoryURL: nil,
                                    winnerImageURL: URL(string: "https://cyclocross24.com/images/rider/mathieu-van-der-poel-kL0.png"),
                                    podium: [
                                        .init(
                                            position: 1,
                                            rider: "VAN DER POEL Mathieu",
                                            riderURL: nil,
                                            country: "Belgium",
                                            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png")!,
                                            time: "59:36"
                                        ),
                                        .init(
                                            position: 2,
                                            rider: "DEL GROSSO Tibor",
                                            riderURL: nil,
                                            country: "Netherlands",
                                            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png")!,
                                            time: "0:45"
                                        ),
                                        .init(
                                            position: 3,
                                            rider: "VERSTRYNGE Emiel",
                                            riderURL: nil,
                                            country: "Belgium",
                                            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                                            time: "1:03"
                                        )
                                    ]
                                ),
                                .init(
                                    title: "Women Elite",
                                    categoryURL: nil,
                                    winnerImageURL: URL(string: "https://cyclocross24.com/cx24logo.jpg"),
                                    podium: [
                                        .init(
                                            position: 1,
                                            rider: "ALVARADO Ceylin Del Carmen",
                                            riderURL: nil,
                                            country: "Netherlands",
                                            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png")!,
                                            time: "51:33"
                                        ),
                                        .init(
                                            position: 2,
                                            rider: "BRAND Lucinda",
                                            riderURL: nil,
                                            country: "Netherlands",
                                            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png")!,
                                            time: "0:23"
                                        ),
                                        .init(
                                            position: 3,
                                            rider: "PIETERSE Puck",
                                            riderURL: nil,
                                            country: "Netherlands",
                                            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png")!,
                                            time: "0:49"
                                        )
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        
        let uciMenElite: [DTO.CXStandings.Leader] = [
            .init(
                position: 1,
                rider: "VANTHOURENHOUT Michael",
                riderURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                points: "2058"
            ),
            .init(
                position: 2,
                rider: "VAN DER POEL Mathieu",
                riderURL: URL(string: "https://cyclocross24.com/rider/mathieu-van-der-poel/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "2040"
            ),
            .init(
                position: 3,
                rider: "NYS Thibau",
                riderURL: URL(string: "https://cyclocross24.com/rider/thibau-nys/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                points: "1953"
            ),
            .init(
                position: 4,
                rider: "NIEUWENHUIS Joris",
                riderURL: URL(string: "https://cyclocross24.com/rider/joris-nieuwenhuis/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "1912"
            ),
            .init(
                position: 5,
                rider: "VANDEPUTTE Niels",
                riderURL: URL(string: "https://cyclocross24.com/rider/niels-vandeputte/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                points: "1903"
            )
        ]
        
        let uciWomenElite: [DTO.CXStandings.Leader] = [
            .init(
                position: 1,
                rider: "VAN EMPEL Fem",
                riderURL: URL(string: "https://cyclocross24.com/rider/fem-van-empel/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "2121"
            ),
            .init(
                position: 2,
                rider: "ALVARADO Ceylin del Carmen",
                riderURL: URL(string: "https://cyclocross24.com/rider/ceylin-del-carmen-alvarado/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "2084"
            ),
            .init(
                position: 3,
                rider: "WORST Annemarie",
                riderURL: URL(string: "https://cyclocross24.com/rider/annemarie-worst/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "2002"
            ),
            .init(
                position: 4,
                rider: "BRAND Lucinda",
                riderURL: URL(string: "https://cyclocross24.com/rider/lucinda-brand/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "1988"
            ),
            .init(
                position: 5,
                rider: "PIETERSE Puck",
                riderURL: URL(string: "https://cyclocross24.com/rider/puck-pieterse/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "1965"
            )
        ]
        
        let uciMenJunior: [DTO.CXStandings.Leader] = [
            .init(
                position: 1,
                rider: "Rider One",
                riderURL: URL(string: "https://cyclocross24.com/rider/rider-one/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                points: "1780"
            ),
            .init(
                position: 2,
                rider: "Rider Two",
                riderURL: URL(string: "https://cyclocross24.com/rider/rider-two/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/France.png"),
                points: "1692"
            ),
            .init(
                position: 3,
                rider: "Rider Three",
                riderURL: URL(string: "https://cyclocross24.com/rider/rider-three/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Italy.png"),
                points: "1630"
            ),
            .init(
                position: 4,
                rider: "Rider Four",
                riderURL: URL(string: "https://cyclocross24.com/rider/rider-four/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                points: "1591"
            ),
            .init(
                position: 5,
                rider: "Rider Five",
                riderURL: URL(string: "https://cyclocross24.com/rider/rider-five/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Spain.png"),
                points: "1533"
            )
        ]

        let standings = DTO.CXStandings(
            items: [
                .init(
                    title: "UCI Ranking Cyclocross",
                    url: URL(string: "https://cyclocross24.com/uciranking/"),
                    logoURL: URL(string: "https://cyclocross24.com/images/flag/32/UCI.png"),
                    categories: [
                        .init(
                            title: "Men Elite",
                            url: URL(string: "https://cyclocross24.com/uciranking/2025-2026/ME/"),
                            leaders: uciMenElite,
                            leaderImageURL: URL(string: "https://cyclocross24.com/images/rider/michael-vanthourenhout-sX4.png")
                        ),
                        .init(
                            title: "Women Elite",
                            url: URL(string: "https://cyclocross24.com/uciranking/2025-2026/WE/"),
                            leaders: uciWomenElite,
                            leaderImageURL: nil
                        ),
                        .init(
                            title: "Men Junior",
                            url: URL(string: "https://cyclocross24.com/uciranking/2025-2026/MJ/"),
                            leaders: uciMenJunior,
                            leaderImageURL: nil
                        )
                    ]
                ),
                .init(
                    title: "UCI World Cup",
                    url: URL(string: "https://cyclocross24.com/standings/uci-world-cup/"),
                    logoURL: nil,
                    categories: []
                ),
                .init(
                    title: "Superprestige",
                    url: URL(string: "https://cyclocross24.com/standings/superprestige/"),
                    logoURL: nil,
                    categories: []
                ),
                .init(
                    title: "X2O Badkamers Trofee",
                    url: URL(string: "https://cyclocross24.com/standings/x2o-trofee/"),
                    logoURL: nil,
                    categories: []
                )
            ]
        )
        
        return .init(calendarEvents: calendarEvents, races: races, standings: standings)
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
