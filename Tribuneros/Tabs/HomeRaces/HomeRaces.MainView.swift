//
//  HomeRaces.MainView.swift
//  Tribuneros
//
//  Created by albert vila on 10/3/25.
//

import SwiftUI

struct HomeRacesView: View {
    @ObservedObject var viewModel: HomeRacesViewModel<HomeRacesInteractorImpl>
    
    var body: some View {
        HomeRaces.MainView(state: viewModel.stateView) {
            viewModel.action($0)
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            let _ = print("avvp [Navigation] - \(destination)")
            switch destination {
            case .nextToFinishRace(let index):
                if let urlPath = viewModel.stateView.result.sections.nextToFinish[index].urlPath {
                    NextToFinishRaceDetail(urlInfo: urlPath)
                } else {
                    EmptyView()
                }
//                .navigationTitle("NEXT TO FINISH")
            case .detail: // avpv not use delete
                EmptyView()
            }
        }
        .navigationTitle("PRO CYCLING STATS")
    }
}

extension HomeRaces {
    
    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets
        
        private let heightCardView: Double = 100
        private let spacingRows: Double = 16
        private let columns = [
            GridItem(.flexible(), spacing: 0)
        ]
        
        let state: HomeRaces.ViewState
        let action: (HomeRaces.Action) -> Void
        
        var body: some View {
            Group {
                switch state {
                case .idle:
                    Text("Hello, World!")
                case .loading:
                    ProgressView()
                case .loaded(let representable):
//                    NavigationStack {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: spacingRows) {
                                
                                /// - Next to Finish -
                                buildNextToFinishView(representable)
                                
                                /// - Results today -
                                buildResultsTodayView(representable)
                                
                                /// - Results yesterday -
                                buildResultsYesterdayView(representable)
                                
                                /// - Tomorrow races -
                                buildTomorrowRaces(representable)
                                
                                Color.clear
                                    .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                            }
                            .padding()
                    }
                    .background(.black)
                    
                case .error(let errorView):
                    Text("Error: \(errorView)")
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                action(.onAppear)
            }
        }
        
        private func buildTomorrowRaces(_ representable: Representable) -> some View {
            Group {
                if representable.sections.tomorrowRaces.isEmpty {
                    buildNoResultsCardView("Races tomorrow", info: "No Races", delaySlideInfo: 0)
                } else {
                    TomorrowRaceCardView(races: representable.sections.tomorrowRaces)
	                    .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }
            }
        }
        
        private func buildNextToFinishView(_ representable: Representable) -> some View {
            Group {
                if representable.sections.nextToFinish.isEmpty {
                    buildNoResultsCardView("Next to fihish", info: "No info yet", delaySlideInfo: 2)
                } else {
                    NextToFinishRaceView(races: representable.sections.nextToFinish) { index in
                        action(.navigate(.nextToFinishRace(index: index)))
                    }
                    .background(Color.tribuneru(.greenCardBackground))
                    .cornerRadius(8)
                }
            }
        }
        
        private func buildResultsTodayView(_ representable: Representable) -> some View {
            Group {
                if representable.sections.racesFinished.isEmpty {
                    buildNoResultsCardView("Results today", info: "No Info yet", delaySlideInfo: 4)
                } else {
                    RaceFinishedCardView(
                        title: "Results today",
                        races: representable.sections.racesFinished,
                        isSpoilerModeOnSubject: .init(representable.sections.spoilerMode.isSpoilerModeResultsToday)
                    ) {
                        action(.spoilerModeResultToday)
                    }
                    .background(Color.tribuneru(.greenCardBackground))
                    .cornerRadius(8)
                }
            }
        }
        
        @ViewBuilder
        private func buildResultsYesterdayView(_ representable: Representable) -> some View {
            if representable.sections.yesterdayResults.isEmpty {
                buildNoResultsCardView("Results yesterday", info: "No Races", delaySlideInfo: 6)
            } else {
                RaceFinishedCardView(
                    title: "Results Yesterday",
                    races: representable.sections.yesterdayResults,
                    isSpoilerModeOnSubject: .init(representable.sections.spoilerMode.isSpoilerModeResultsYesterday)
                ) {
                    action(.spoilerModeResultYesterday)
                }
                .background(Color.tribuneru(.greenCardBackground))
                .cornerRadius(8)
            }
        }
        
        private func buildNoResultsCardView(_ race: String, info: String, delaySlideInfo: Double) -> some View {
            EmptyResultsCardView(title: "\(race)", info: info, delaySlideInfo: delaySlideInfo)
                .frame(height: heightCardView)
                .frame(maxWidth: .infinity)
                .background(Color.tribuneru(.blueMissingInfoBackground))
                .cornerRadius(8)
        }
    }
}

// MARK: - Previews -

#Preview("Loaded") {
    let nextToFinish: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Home", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: ""),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Donne", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: ""),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "paris Nice", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: ""),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Tirreno", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: "")
    ]
    let todayFinished: [HomeRaces.Representable.RaceFinished] = [
        HomeRaces.Representable.RaceFinished(
            race: "Paris-Nice",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "it", name: "Pipo Ganna", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "be", name: "Pipo Ganna", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "uk", name: "Pipo Ganna", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno",
            raceDetails: "General classification",
            winnerImgURL: nil,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Matthieu", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "ir", name: "Ben Healy", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "nl", name: "Adam Yates", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Paris-Roubaix",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "au", name: "Wout van", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "", name: "Remco enve", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "", name: "Pipo Ganna", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        )
    ]
    let yesterdayResults: [HomeRaces.Representable.RaceFinished] = [
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno Adriatico etapa 2",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "it", name: "Joshua Tarlin", team: "Visma lease a bike", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "be", name: "Pipo Ganna", team: "Soudal Quick step", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "uk", name: "Primoz Roglic", team: "Lidl Trek", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno Adriatico",
            raceDetails: "Stage 4",
            winnerImgURL: nil,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Visma | Lease a bike", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "au", name: "Team Jayco Alula", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "de", name: "Red Bull - Bora - Hansgrohe", team: "", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "A traves de Flandes",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "be", name: "Victor Campenaerts", team: "Visma | Lease a bike", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "no", name: "Tobias Foss", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "fr", name: "Julien Alaphilipe", team: "Tudor", time: "24:12")
            ],
            isCancel: false
        )
    ]
    let tomorrowRaces = [
        HomeRaces.Representable.RaceTomorrow(start: "12:00", eta: "", name: "Bruge-Le Panne", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "12:04", eta: "", name: "Bruge-Le Panne", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "12:30", eta: "", name: "Bruge-Le Panne", url: nil)
    ]
    let repre = HomeRaces.Representable(
        sections: HomeRaces.Representable.Section(
            title: "",
            spoilerMode: .empty,
            nextToFinish: [], // nextToFinish,
            racesFinished: todayFinished,
            yesterdayResults: yesterdayResults,
            tomorrowRaces: tomorrowRaces
        )
    )
    HomeRaces.MainView(state: .loaded(repre)) { _ in
        
    }
}


#Preview("Loading") {
    HomeRaces.MainView(state: .loading) { _ in  }
}
