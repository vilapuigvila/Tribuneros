//
//  CXRacesView.swift
//  Tribuneros
//
//  Created by albert vila on 5/1/26.
//

import SwiftUI

struct CXRacesRacesView: View {
    @ObservedObject var viewModel: CXRaces.ViewModel<CXRaces.InteractorImpl>
    @State private var lensSeries: CXRaces.RaceSeries?

    var body: some View {
        CXRaces.MainView(
            state: viewModel.stateView,
            selectedSeries: $lensSeries
        ) {
            switch $0 {
            case .didAppeared:
                viewModel.action(.didAppeared)
            default:
                viewModel.action($0)
            }
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            let _ = AppLogger.navigation.debug("\(destination)")
            switch destination {
            case .cxZone(.allRaces(let series)):
                CXAllRacesView(
                    events: viewModel.stateView.result.calendarEvents,
                    initialSeries: series,
                    onSeriesChange: { picked in
                        // "All" has no chip on the CX Zone page, so it keeps the current one.
                        if let picked {
                            lensSeries = picked
                        }
                    }
                ) { event in
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
                    },
                    openFullResults: { results in
                        viewModel.action(.didTapOnFullResults(event, results: results))
                    }
                ) { url in
                    viewModel.action(.didTapOnExternalLink(url))
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
                ) { rider in
                    viewModel.action(.didTapOnAllRiderResults(rider))
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
                RaceDetailView(
                    race: race,
                    openVideo: { url in
                        viewModel.action(.didTapOnExternalLink(url))
                    }
                ) { result in
                    viewModel.action(.didTapOnResultRider(result))
                }
            case .cxZone(.standings):
                CXStandingsListView(
                    standings: viewModel.stateView.result.standings,
                    openRider: { standing in
                        viewModel.action(.didTapOnStandingRider(standing))
                    },
                    openRanking: { context in
                        viewModel.action(.didTapOnRanking(context))
                    }
                )
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
                    },
                    openRanking: { context in
                        viewModel.action(.didTapOnRanking(context))
                    }
                ) { rider in
                    viewModel.action(.didTapOnAllRiderResults(rider))
                }
            case .cxZone(.fullResults(let event, let results)):
                CXFullResultsView(
                    event: event,
                    results: results,
                    router: viewModel.router
                )
            case .cxZone(.riderResults(let rider)):
                CXRiderResultsView(
                    rider: rider,
                    calendar: viewModel.stateView.result.calendarEvents,
                    router: viewModel.router
                )
            case .cxZone(.ranking(let context)):
                CXRankingView(
                    context: context,
                    router: viewModel.router
                )
            default:
                EmptyView()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(L10n.tr("CX ZONE"))
        .toolbar(.hidden, for: .navigationBar)
    }
}
