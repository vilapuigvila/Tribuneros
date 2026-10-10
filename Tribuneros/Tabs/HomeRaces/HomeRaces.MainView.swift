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
                    NextToFinishRaceDetail(
                        urlInfo: urlPath,
                        watchKey: HomeRaces.WhereToWatch.RaceKey(race: sections.nextToFinish[index])
                    )
                } else {
                    EmptyView()
                }
            case .todayRaces:
                TodayRacesListView(races: sections.nextToFinish) {
                    viewModel.action($0)
                }
            case .yesterdayResults:
                YesterdayResultsListView(
                    races: sections.yesterdayResults
                ) {
                    viewModel.action($0)
                }
            case .raceResultDetail(let raceFinished):
                RaceFinishedDetailView(
                    raceFinished: raceFinished,
                    router: viewModel.router
                )
            case .racePreview(let preview):
                RacePreviewDetailView(
                    preview: preview,
                    router: viewModel.router
                )
            case .liveRace(let context):
                LiveRaceDetailView(
                    context: context,
                    router: viewModel.router
                )
            case .whereToWatch(let raceKey):
                WhereToWatchView(
                    raceKey: raceKey,
                    router: viewModel.router
                )
            case .historyResults:
                HistoryResultsListView(races: sections.historyResults) {
                    viewModel.action($0)
                }
            default:
                EmptyView()
            }
        }
        .navigationTitle(L10n.tr("Races"))
        // iOS 26 keeps a hidden large title inside the scroll view; inline avoids its collapse tracking.
        .navigationBarTitleDisplayMode(.inline)
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
                    .accessibilityLabel(L10n.tr("Loading the races"))
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
                                message: errorView.message,
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
                    VStack(alignment: .leading, spacing: 8) {
                        HomeScreenHeader(date: Date())
                            .padding(.top, 16)
                        if let staleCopy = representable.staleCopy {
                            StaleCopyNotice(staleCopy: staleCopy)
                        }
                    }

                    TodaySection(
                        races: sections.nextToFinish,
                        isCompact: !sections.previews.isEmpty,
                        action: action
                    )

                    if !sections.previews.isEmpty {
                        PreviewsSection(
                            previews: sections.previews,
                            action: action
                        )
                    }

                    ResultsTodaySection(
                        races: sections.racesFinished,
                        firstFinishExpected: sections.firstFinishExpected,
                        isHintAnchor: representable.showSpoilerHint && !sections.racesFinished.isEmpty,
                        action: action
                    )

                    YesterdaySection(
                        races: sections.yesterdayResults,
                        isHintAnchor: representable.showSpoilerHint && sections.racesFinished.isEmpty && !sections.yesterdayResults.isEmpty,
                        action: action
                    )

                    HistorySection(
                        races: sections.historyResults,
                        action: action
                    )

                    Color.clear
                        .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .disabled(isPlaceholder)
                .overlayPreferenceValue(SpoilerHintAnchorKey.self) { anchor in
                    GeometryReader { proxy in
                        if representable.showSpoilerHint,
                           let anchor {
                            let rect = proxy[anchor]
                            let fitsBelow = proxy.frame(in: .global).minY + rect.maxY + 204 < UIScreen.main.bounds.height - 120
                            SpoilerHintCallout(pointsUp: fitsBelow) {
                                action(.dismissSpoilerHint)
                            }
                            .position(
                                x: min(
                                    max(rect.midX, 140),
                                    proxy.size.width - 140
                                ),
                                y: fitsBelow ? rect.maxY + 98 : rect.minY - 98
                            )
                        }
                    }
                }
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
