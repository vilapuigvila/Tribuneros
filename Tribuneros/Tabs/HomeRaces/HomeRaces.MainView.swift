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
            let sections = viewModel.stateView.result.sections
            switch destination {
            case .nextToFinishRace(let index):
                if sections.nextToFinish.indices.contains(index),
                   let urlPath = sections.nextToFinish[index].urlPath {
                    NextToFinishRaceDetail(urlInfo: urlPath)
                } else {
                    EmptyView()
                }
            case .todayRaces:
                TodayRacesListView(races: sections.nextToFinish) {
                    viewModel.action($0)
                }
            case .yesterdayResults:
                YesterdayResultsListView(
                    races: sections.yesterdayResults,
                    isSpoilerModeOn: sections.spoilerMode.isSpoilerModeResultsYesterday
                ) {
                    viewModel.action($0)
                }
            default:
                EmptyView()
            }
        }
        .navigationTitle("Races")
        .toolbar(.hidden, for: .navigationBar)
    }
}

extension HomeRaces {

    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets
        @State private var retryCount = 0
        // onAppear also fires when popping back from a detail; only the first one fetches.
        @State private var hasAppeared = false

        let state: HomeRaces.ViewState
        let action: (HomeRaces.Action) -> Void

        var body: some View {
            Group {
                switch state {
                case .idle, .loading:
                    // Nothing has arrived yet: the real layout drawn with stand-in data.
                    content(
                        .placeholders,
                        isPlaceholder: true
                    )
                    .redacted(reason: .placeholder)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Loading the races")
                case .loaded(let representable):
                    content(representable)
                case .error(let errorView):
                    VStack(spacing: 20) {
                        Spacer(minLength: safeAreaInsets.top + 20)
                        switch errorView {
                        case .emtpyData:
                            ErrorCardView.emptyData(
                                showTryAgainButton: retryCount < 3
                            ) {
                                retryCount += 1
                                action(.onAppear)
                            }
                        default:
                            ErrorCardView.generic(
                                message: "\(errorView)",
                                showTryAgainButton: retryCount < 3
                            ) {
                                retryCount += 1
                                action(.onAppear)
                            }
                        }
                        Spacer(minLength: safeAreaInsets.bottom + 20)
                    }
                    .padding(.horizontal)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true
                action(.onAppear)
            }
        }

        /// A placeholder page still scrolls; only its cards are disabled.
        private func content(
            _ representable: Representable,
            isPlaceholder: Bool = false
        ) -> some View {
            let sections = representable.sections
            return ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HomeScreenHeader(date: Date())

                    TodaySection(
                        races: sections.nextToFinish,
                        action: action
                    )

                    ResultsTodaySection(
                        races: sections.racesFinished,
                        isSpoilerModeOn: sections.spoilerMode.isSpoilerModeResultsToday,
                        action: action
                    )

                    YesterdaySection(
                        races: sections.yesterdayResults,
                        isSpoilerModeOn: sections.spoilerMode.isSpoilerModeResultsYesterday,
                        action: action
                    )

                    HistorySection()

                    Color.clear
                        .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .disabled(isPlaceholder)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .overlay(alignment: .top) {
                StatusBarScrim()
            }
        }
    }
}

// MARK: - Previews -

#Preview("Loaded") {
    HomeRaces.MainView(state: .loaded(.mockFull)) { _ in }
}

#Preview("Loading") {
    HomeRaces.MainView(state: .loading) { _ in  }
}
