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
                        LazyVGrid(columns: columns, spacing: 16) {
                            /// calendar
                            CalendarView(representable: representable) {
                                action(.didTapOnNextRaces)
                            }
                            
                            /// latests results
                            LatestResultsView(races: representable.races)
                            
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
    
    private struct LatestResultsView: View {
        let races: DTO.CX24Homepage
        
        var body: some View {
            VStack(alignment: .leading) {
                TribuneruText(
                    content: "Latest Cyclocross Results",
                    style: .size20WeightBold
                )
                .padding(.bottom, 6)
                
                if let firstRace = firstRaceFromFirstSection {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            CachedImageView(imageUrl: firstRace.countryFlagURL, cornerRadius: 1)
                                .frame(width: 14)
                            
                            TribuneruText(
                                content: firstRace.title,
                                style: .size14WeightRegular,
                                lineLimit: 2
                            )
                            
                            Spacer(minLength: 0)
                        }
                        
                        HStack(spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                                TribuneruText(
                                    content: firstRace.date,
                                    style: .size12WeightRegular,
                                    color: .gray,
                                    lineLimit: 1
                                )
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(.gray)
                                TribuneruText(
                                    content: firstRace.location,
                                    style: .size12WeightRegular,
                                    color: .gray,
                                    lineLimit: 1
                                )
                            }
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.bottom, 6)
                        
                        VStack(spacing: 12) {
                            ForEach(firstRace.categories.prefix(2).indices, id: \.self) { idx in
                                let category = firstRace.categories[idx]
                                CategoryResultsView(category: category)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.tribuneru(.greenCardBackground))
                    .cornerRadius(8)
                } else {
                    TribuneruText(
                        content: "No results found.",
                        style: .size16WeightBold,
                        color: .red,
                        lineLimit: 2
                    )
                }
            }
        }
        
        private struct FirstRaceInfo {
            let title: String
            let countryFlagURL: URL?
            let date: String
            let location: String
            let categories: [DTO.CX24Homepage.Category]
        }
        
        private var firstRaceFromFirstSection: FirstRaceInfo? {
            guard
                let section = races.sections.first,
                let race = section.races.first
            else {
                return nil
            }
            return .init(
                title: race.title,
                countryFlagURL: race.countryFlagURL,
                date: race.date,
                location: race.location,
                categories: race.categories
            )
        }
        
        private struct CategoryResultsView: View {
            let category: DTO.CX24Homepage.Category
            
            var body: some View {
                let podiums = Array(category.podium.prefix(3))
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TribuneruText(
                            content: category.title.uppercased(),
                            style: .size12WeightRegular,
                            color: .gray
                        )
                        
                        Spacer(minLength: 0)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        CachedImageView(imageUrl: category.winnerImageURL, cornerRadius: 0)
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                        
                        VStack(spacing: 0) {
                            ForEach(podiums.indices, id: \.self) { idx in
                                let podium = podiums[idx]
                                PodiumRow(podium: podium)
                                
                                if idx < podiums.count - 1 {
                                    TribunerosDivider(height: 0.5, color: .gray.opacity(0.2))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        private struct PodiumRow: View {
            let podium: DTO.CX24Homepage.Podium
            
            var body: some View {
                HStack(spacing: 10) {
                    TribuneruText(
                        content: "\(podium.position)",
                        style: .size12WeightRegular,
                        color: .gray
                    )
                    .frame(width: 18, alignment: .leading)
                    
                    CachedImageView(
                        imageUrl: podium.countryFlagURL,
                        cornerRadius: 1
                    )
                    .frame(width: 16, height: 16)
                    
                    TribuneruText(
                        content: podium.rider,
                        style: .size12WeightRegular,
                        lineLimit: 1
                    )
                    
                    Spacer(minLength: 0)
                    
                    TribuneruText(
                        content: podium.time,
                        style: .size12WeightRegular,
                        color: .gray,
                        lineLimit: 1
                    )
                }
                .padding(.vertical, 6)
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
