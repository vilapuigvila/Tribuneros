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
                                if !representable.sections.nextToFinish.isEmpty {
                                    NextToFinishRaceView(races: representable.sections.nextToFinish)
                                        .background(Color.green.opacity(0.2))
                                        .frame(height: heightCardView)
                                        .cornerRadius(8)
                                } else {
                                    buildNoResultsCardView()
                                }
                                if !representable.sections.racesFinished.isEmpty {
                                    VStack(spacing: 2) {
                                        buildTitleNextToFinishCardView("Results today")
                                        
                                        ForEach(representable.sections.racesFinished) { race in
                                            GeometryReader { geometry in
                                                
                                            }
                                            VStack(spacing: 0) {
                                                HStack(alignment: .top, spacing: 8) {
                                                    AsyncImageView(url: race.winnerImgURL)
                                                        .frame(width: 35, height: 112*0.41)
                                                        .padding(.leading, 8)
                                                    
                                                    VStack(alignment: .leading, spacing: 0) {
                                                        Text(race.race)
                                                            .font(.system(size: 11, weight: .bold, design: .default))
                                                            .lineLimit(1)
                                                        ForEach(race.podium) { podium in
                                                            HStack(spacing: 6) {
                                                                Text(podium.position)
                                                                    .font(.system(size: 9, weight: .regular, design: .default))
                                                                Text(podium.name)
                                                                    .font(.system(size: 9, weight: .regular, design: .default))
                                                                Text(podium.team)
                                                                    .font(.system(size: 9, weight: .regular, design: .default))
                                                            }
                                                        }
                                                        Spacer()
                                                    }
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                            .padding(.top, 4)
//                                            Spacer()
                                        }
                                        .background(Color.purple.opacity(0.2))
//                                        .padding(.top, 4)
                                    }
                                    .background(Color.green.opacity(0.2))
//                                    .frame(height: heightCardView)
                                    .cornerRadius(8)
                                } else {
                                    buildNoResultsCardView()
                                }
                                if !representable.sections.yesterdayResults.isEmpty {
                                    VStack(spacing: 2) {
                                        buildTitleNextToFinishCardView("Results yesterday")
                                        
                                        ForEach(representable.sections.yesterdayResults) { race in
                                            VStack(spacing: 0) {
                                                HStack(alignment: .top, spacing: 8) {
                                                    AsyncImageView(url: race.winnerImgURL)
                                                        .frame(width: 35, height: 112*0.41)
//                                                        .aspectRatio(contentMode: .fit)
//                                                        .padding(.vertical, 16)
                                                        .padding(.leading, 8)
                                                    
                                                    VStack(alignment: .leading, spacing: 0) {
                                                        Text(race.race)
                                                            .lineLimit(1)
                                                            .font(.system(size: 11, weight: .bold, design: .default))
                                                        ForEach(race.podium) { podium in
                                                            HStack(spacing: 6) {
                                                                Text(podium.position)
                                                                    .font(.system(size: 9, weight: .regular, design: .default))
                                                                Text(podium.name)
                                                                    .font(.system(size: 9, weight: .regular, design: .default))
                                                                Text(podium.team)
                                                                    .font(.system(size: 9, weight: .regular, design: .default))
                                                            }
                                                        }
                                                        Spacer()
                                                    }
                                                    Spacer()
                                                }
                                                Spacer()
                                            }
                                            .padding(.top, 4)
//                                            Spacer()
                                        }
//                                        .background(Color.purple.opacity(0.2))
//                                        .padding(.top, 4)
                                    }
                                    .background(Color.green.opacity(0.2))
//                                    .frame(height: heightCardView)
                                    .cornerRadius(8)
                                } else {
                                    buildNoResultsCardView()
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
        
        private func buildNoResultsCardView() -> some View {
            Text("No results")
                .frame(height: heightCardView)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
        
        private func buildTitleNextToFinishCardView(_ title: String) -> some View {
            Group {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .padding(.top, 12)
                        .padding(.horizontal, 8)
                    Spacer()
                }
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
            }
        }
    }
}

#Preview("Loaded") {
    let nextToFinish: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Home", category: "UCI", raceType: "2.UWT", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Donne", category: "UCI", raceType: "2.UWT", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "paris Nice", category: "UCI", raceType: "2.UWT", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Tirreno", category: "UCI", raceType: "2.UWT", distance: "215")
    ]
    let finished: [HomeRaces.Representable.RaceFinished] = [
        HomeRaces.Representable.RaceFinished(
            race: "Paris-Nice fjdkjfdk fjdkjf dfjdkfj fjdkfjdkf 1212ds21sd fdf fdf f",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, name: "Pipo Ganna", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, name: "Pipo Ganna", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, name: "Pipo Ganna", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, name: "Matthieu", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, name: "Derek Gee", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, name: "Adam Yates", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        )
    ]
    let repre = HomeRaces.Representable(
        sections: HomeRaces.Representable.Section(
            title: "",
            nextToFinish: nextToFinish,
            racesFinished: finished,
            yesterdayResults: []
        )
    )
    HomeRaces.MainView(state: .loaded(repre)) { _ in
        
    }
}


#Preview("Loading") {
    HomeRaces.MainView(state: .loading) { _ in  }
}
