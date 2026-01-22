//
//  CXRacesView.swift
//  Tribuneros
//
//  Created by albert vila on 5/1/26.
//

import SwiftUI

struct CXRacesRacesView: View {
    @ObservedObject var viewModel: CXRaces.ViewModel<CXRaces.InteractorImpl>
    
    var body: some View {
        CXRaces.MainView(state: viewModel.stateView) {
            switch $0 {
            case .didAppeared:
                viewModel.action(.didAppeared)
            default:
                viewModel.action($0)
            }
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            let _ = print("avvp [Navigation] - \(destination)")
            switch destination {
            case .cxZone(.allRaces):
                CXAllRacesView(events: viewModel.stateView.result.calendarEvents) { url in
                    viewModel.action(.didTapOnRace(url))
                }
                .navigationTitle("All races")
            case .cxZone(.latestResults):
                LatestAllResultsView(races: viewModel.stateView.result.races) { race in
                    viewModel.action(.didTapOnRaceDetail(race))
                }
                .navigationTitle("Latest results")
            case .cxZone(.raceDetail(let race)):
                RaceDetailView(race: race)
//                    .navigationTitle("Race Details")
            case .cxZone(.standings):
                CXStandingsListView(standings: viewModel.stateView.result.standings)
                    .navigationTitle("Standings")
            case .detail(.race(let urlInfo)):
                SafariView(url: URL(string: urlInfo))
            default:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("CX ZONE")
    }
}
