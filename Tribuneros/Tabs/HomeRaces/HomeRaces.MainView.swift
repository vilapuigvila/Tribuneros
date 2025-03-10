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
                                    NextToFinishView(races: representable.sections.nextToFinish)
                                        .background(Color.green.opacity(0.2))
                                        .frame(height: heightCardView)
                                        .cornerRadius(8)
                                } else {
                                    buildNoResultsCardView()
                                }
                                if !representable.sections.racesFinished.isEmpty {
                                    Text("results")
                                } else {
                                    buildNoResultsCardView()
                                }
                                if !representable.sections.yesterdayResults.isEmpty {
                                    Text("results")
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
//        private let paddingHorizontal = 8.0
//        private func buildNextToFinish(_ races: [HomeRaces.Representable.RaceNext]) -> some View {
//            GeometryReader { proxy in
//                VStack(spacing: 0) {
//                    buildTitleNextToFinishCardView()
//                    
//                    buildHeaderNextToFinishSection(proxy.size.width)
//                        .padding(.top, 6)
//                        .padding(.bottom, 2)
//	                    .frame(width: proxy.size.width)
//                    
//                    Spacer()
//                    
//                    ForEach(Array(races.prefix(2))) { item in
//                        VStack(spacing: 0) {
//                            HStack(spacing: 0) {
//                                buildTextForRaceFinishedValue(item.eta, width: proxy.size.width * 0.14)
//                                buildTextForRaceFinishedValue(item.duration, width: proxy.size.width * 0.09)
//                                    .foregroundStyle(.purple)
//                                buildTextForRaceFinishedValue(item.name, width: proxy.size.width * 0.54)
//                                buildTextForRaceFinishedValue(item.category, width: proxy.size.width * 0.0925)
//                                buildTextForRaceFinishedValue(item.distance, width: proxy.size.width * 0.0925)
//                            }
//                            .frame(width: proxy.size.width)
//                            Spacer()
//                        }
//                    }
//                    Spacer()
//                    
//                    Text("+ info")
//                        .font(.system(size: 9, weight: .bold, design: .default))
//                        .foregroundStyle(.link)
//                        .frame(alignment: .bottomLeading)
//                        .offset(y: -6)
//                }
//            }
//            .background(Color.green.opacity(0.2))
//            .frame(height: heightCardView)
//            .cornerRadius(8)
//        }
        
        private func buildNoResultsCardView() -> some View {
            Text("No results")
                .frame(height: heightCardView)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
        }
//        
//        private func buildTitleNextToFinishCardView() -> some View {
//            Group {
//                HStack {
//                    Text("Next to finish")
//                        .font(.system(size: 16, weight: .bold, design: .default))
//                        .padding(.top, 12)
//                        .padding(.horizontal, paddingHorizontal)
//                    Spacer()
//                }
//                Rectangle()
//                    .fill(Color.gray.opacity(0.3))
//                    .frame(height: 0.5)
//                    .frame(maxWidth: .infinity)
//                    .padding(.horizontal, paddingHorizontal)
//                    .padding(.top, 12)
//            }
//        }
        
//        private func buildTextForRaceFinishedValue(_ text: String, width: CGFloat) -> some View {
//            Text(text)
//                .font(.system(size: 11, weight: .bold, design: .default))
//                .lineLimit(1)
//                .frame(width: width, alignment: .leading)
//        }
        
//        private func buildTextForHeaderView(_ text: String, width: CGFloat) -> some View {
//            Text(text)
//                .font(.system(size: 11, weight: .regular, design: .monospaced))
//                .foregroundStyle(.gray)
//                .frame(width: width, alignment: .leading)
//                .background(.gray.opacity(0.1))
//        }
        
//        private func buildHeaderNextToFinishSection(_ width: CGFloat) -> some View {
//            HStack(spacing: 0) {
//                buildTextForHeaderView("ETA", width: width * 0.23)
//                buildTextForHeaderView("Race", width: width * 0.53)
//                buildTextForHeaderView("CAT.", width: width * 0.0925)
//                buildTextForHeaderView("KM", width: width * 0.0925)
//            }
//        }
    }
}

#Preview("Loaded") {
    let nextToFinish: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Home", category: "UCI", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Donne", category: "UCI", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "paris Nice", category: "UCI", distance: "215"),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Tirreno", category: "UCI", distance: "215")
    ]
    let repre = HomeRaces.Representable(
        sections: HomeRaces.Representable.Section(
            title: "",
            nextToFinish: nextToFinish,
            racesFinished: [],
            yesterdayResults: []
        )
    )
    HomeRaces.MainView(state: .loaded(repre)) { _ in
        
    }
}


#Preview("Loading") {
    HomeRaces.MainView(state: .loading) { _ in  }
}
