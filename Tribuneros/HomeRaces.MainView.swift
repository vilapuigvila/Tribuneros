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
//            GridItem(.flexible())
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
                                    buildNextToFinish(representable.sections.nextToFinish)
                                } else {
                                    Text("No results")
                                }
                                if representable.sections.racesFinished.isEmpty {
                                    Text("No results")
                                } else {
                                    Text("No results")
                                }
                                if representable.sections.yesterdayResults.isEmpty {
                                    Text("No results")
                                } else {
                                    Text("No results")
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
        private let paddingHorizontal = 8.0
        private func buildNextToFinish(_ races: [HomeRaces.Representable.RaceNext]) -> some View {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    buildTitleNextToFinishCardView()
                    
                    buildHeaderNextToFinishSection(proxy.size.width)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
	                    .frame(width: proxy.size.width)
                    
                    Spacer()
                    
                    ForEach(Array(races.prefix(2))) { item in
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text("\(item.eta)")
                                    .font(.system(size: 11, weight: .bold, design: .default))
                                    .lineLimit(1)
                                    .frame(width: proxy.size.width * 0.14, alignment: .leading)
//                                    .background(.yellow.opacity(0.1))
                                Text("\(item.duration)")
                                    .font(.system(size: 11, weight: .bold, design: .default))
                                    .foregroundStyle(.purple)
                                    .lineLimit(1)
                                    .frame(width: proxy.size.width * 0.09, alignment: .leading)
//                                    .background(.yellow.opacity(0.3))

                                Text(item.name)
                                    .font(.system(size: 11, weight: .bold, design: .default))
                                    .lineLimit(1)                                    .frame(width: proxy.size.width * 0.54, alignment: .leading)
//                                    .background(.yellow.opacity(0.1))
                                
                                Text(item.category)
                                    .font(.system(size: 11, weight: .bold, design: .default))
                                    .lineLimit(1)
                                    .frame(width: proxy.size.width * 0.0925, alignment: .leading)
//                                    .background(.yellow.opacity(0.1))
                                
                                Text(item.distance)
                                    .font(.system(size: 11, weight: .bold, design: .default))
                                    .lineLimit(1)
                                    .frame(width: proxy.size.width * 0.0925, alignment: .leading)
//                                    .background(.yellow.opacity(0.1))

                            }
                            .frame(width: proxy.size.width)
                            
                            Spacer()
                        }
                    }
                    Spacer()
                    
//                    if races.count > 2 {
                        Text("+ info")
                            .font(.system(size: 9, weight: .bold, design: .default))
                            .foregroundStyle(.link)
                            .frame(alignment: .bottomLeading)
                            .offset(y: -6)
//                    }
//                    Spacer()
                }
            }
            .background(Color.green.opacity(0.2))
            .frame(height: heightCardView)
            .cornerRadius(8)
            
        }
        
        private func buildTitleNextToFinishCardView() -> some View {
            Group {
                HStack {
                    Text("Next to finish")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .padding(.top, 12)
                        .padding(.horizontal, paddingHorizontal)
                    Spacer()
                }
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, paddingHorizontal)
                    .padding(.top, 12)
            }
        }
        
        private func buildHeaderNextToFinishSection(_ width: CGFloat) -> some View {
            HStack(spacing: 0) {
                Text("ETA")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.gray)
                    .frame(width: width * 0.23, alignment: .leading)
//                            .background(.yellow.opacity(0.1))
                
                Text("Race")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.gray)
                    .frame(width: width * 0.53, alignment: .leading)
                
                Text("CAT.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.gray)
                    .frame(width: width * 0.0925, alignment: .leading)
                Text("KM")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.gray)
                    .frame(width: width * 0.0925, alignment: .leading)
            }
        }
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
