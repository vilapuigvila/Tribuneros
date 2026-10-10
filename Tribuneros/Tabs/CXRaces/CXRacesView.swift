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
                CXAllRacesView(events: viewModel.stateView.result.calendarEvents) { event in
                    viewModel.action(.didTapOnCalendarEvent(event))
                }
                .navigationTitle(L10n.tr("All races"))
            case .cxZone(.eventDetail(let event)):
                CXEventDetailView(
                    event: event,
                    openPastWinner: { winner in
                        viewModel.action(.didTapOnPastWinnerRider(winner))
                    },
                    openResultRider: { result in
                        viewModel.action(.didTapOnResultRider(result))
                    },
                    openWinner: { winner in
                        viewModel.action(.didTapOnWinner(winner, from: event))
                    }
                ) { url in
                    viewModel.action(.didTapOnLink(url))
                }
            case .cxZone(.winnerDetail(let winner, let from)):
                CXWinnerDetailView(
                    winner: winner,
                    openRace: { event in
                        viewModel.action(.didTapOnWinnerRace(event, openedFrom: from))
                    },
                    openRaceResult: { result, rider in
                        viewModel.action(.didTapOnRiderResult(result, rider: rider))
                    }
                ) { url in
                    viewModel.action(.didTapOnLink(url))
                }
            case .cxZone(.latestResults):
                LatestAllResultsView(
                    races: viewModel.stateView.result.races,
                    openRider: { podium in
                        viewModel.action(.didTapOnPodiumRider(podium))
                    }
                ) { race in
                    viewModel.action(.didTapOnRaceDetail(race))
                }
                .navigationTitle(L10n.tr("Latest results"))
            case .cxZone(.raceDetail(let race)):
                RaceDetailView(race: race) { result in
                    viewModel.action(.didTapOnResultRider(result))
                }
//                    .navigationTitle("Race Details")
            case .cxZone(.standings):
                CXStandingsListView(standings: viewModel.stateView.result.standings) { standing in
                    viewModel.action(.didTapOnStandingRider(standing))
                }
                .navigationTitle(L10n.tr("Standings"))
            case .cxZone(.riderDetail(let context)):
                CXRiderDetailView(
                    context: context,
                    openRace: { race in
                        viewModel.action(.didTapOnRaceDetail(race))
                    },
                    openEvent: { event in
                        viewModel.action(.didTapOnCalendarEvent(event))
                    },
                    openRaceResult: { result, rider in
                        viewModel.action(.didTapOnRiderResult(result, rider: rider))
                    }
                ) { url in
                    viewModel.action(.didTapOnLink(url))
                }
            case .detail(.race(let urlInfo)):
                SafariView(url: URL(string: urlInfo))
            default:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.tr("CX ZONE"))
    }
}
