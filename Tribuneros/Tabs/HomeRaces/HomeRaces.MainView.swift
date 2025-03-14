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
    }
}

extension HomeRaces {
    
    struct MainView: View {
        private let heightCardView: Double = 140
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
                    NavigationStack {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                
                                /// - Next to Finish -
                                if representable.sections.nextToFinish.isEmpty {
                                    buildNoResultsCardView("Next to fihish")
                                } else {
                                    NextToFinishRaceView(races: representable.sections.nextToFinish)
                                        .background(Color.green.opacity(0.2))
                                        .frame(height: heightCardView)
                                        .cornerRadius(8)
                                }
                                
                                /// - Results today -
                                if representable.sections.racesFinished.isEmpty {
                                    buildNoResultsCardView("Results today")
                                } else {
                                    RaceFinishedCardView(
                                        title: "Results today",
                                        races: representable.sections.racesFinished
                                    ) {
                                        print("avvp - spoiler action")
                                    } showResultsAction: {
                                        print("avvp - show")
                                    }
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                
                                /// - Results yesterday -
                                if representable.sections.yesterdayResults.isEmpty {
                                    buildNoResultsCardView("Results yesterday")
                                } else {
                                    RaceFinishedCardView(
                                        title: "Results Yesterday",
                                        races: representable.sections.yesterdayResults
                                    ) {
                                        print("avvp - spoiler action")
                                    } showResultsAction: {
                                        print("avvp - show")
                                    }
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                        }
                        .navigationTitle("PRO CYCLING STATS")
                    }
                case .error(let errorView):
                    Text("Error: \(errorView)")
                }
            }
            .onAppear {
                action(.onAppear)
            }
        }
        
        private func buildNoResultsCardView(_ race: String) -> some View {
            EmptyResultsCardView(title: "\(race)", info: "No info available")
                .frame(height: heightCardView)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
    }
}

// MARK: - Previews -

#Preview("Loaded") {
    let nextToFinish: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Home", category: "UCI", raceType: "2.UWT", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Donne", category: "UCI", raceType: "2.UWT", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "paris Nice", category: "UCI", raceType: "2.UWT", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Tirreno", category: "UCI", raceType: "2.UWT", distance: "215")
    ]
    let todayFinished: [HomeRaces.Representable.RaceFinished] = [
        HomeRaces.Representable.RaceFinished(
            race: "Paris-Nice etapa 2",
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
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "it", name: "Joshua Tarlin", team: "Visma lease a bike", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "be", name: "Pipo Ganna", team: "Soudal Quick step", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "uk", name: "Pipo Ganna", team: "Lidl Trek", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno Adriatico",
            winnerImgURL: nil,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Visma | Lease a bike", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "au", name: "Team Jayco Alula", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "de", name: "Red Bull - Bora - Hansgrohe", team: "", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Flandes ...",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "be", name: "Victor Campenaerts", team: "Visma | Lease a bike", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "no", name: "Tobias Foss", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "fr", name: "Julien Alaphilipe", team: "Tudor", time: "24:12")
            ],
            isCancel: false
        )
    ]
    let repre = HomeRaces.Representable(
        sections: HomeRaces.Representable.Section(
            title: "",
            nextToFinish: nextToFinish,
            racesFinished: todayFinished,
            yesterdayResults: yesterdayResults
        )
    )
    HomeRaces.MainView(state: .loaded(repre)) { _ in
        
    }
}


#Preview("Loading") {
    HomeRaces.MainView(state: .loading) { _ in  }
}


struct DebugBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content.background(color)
    }
}

//extension View {
//    func debugBackground(_ color: Color = .green) -> some View {
//        if true {
//            self as! ModifiedContent<Self, DebugBackgroundModifier>
//        } else {
//            modifier(DebugBackgroundModifier(color: color))
//        }
//    }
//}
