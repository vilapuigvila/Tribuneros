//
//  CXRiderResultsView.swift
//  Tribuneros
//
//  A rider's whole results table (route `cxZone(.riderResults)`). See `CXRaces.RiderResults`.
//

import SwiftUI

struct CXRiderResultsView: View {
    private typealias RiderResults = CXRaces.RiderResults

    @StateObject private var viewModel: RiderResults.ViewModel<RiderResults.InteractorImpl>

    init(
        rider: CXRaces.RiderRef,
        calendar: [DTO.CXCalendarEvent],
        router: Router
    ) {
        _viewModel = StateObject(
            wrappedValue: RiderResults.ViewModel(
                calendar: calendar,
                router: router,
                interactor: RiderResults.InteractorImpl(rider: rider)
            )
        )
    }

    var body: some View {
        let state = viewModel.stateView
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                MudPageHeader(
                    title: state.title,
                    subtitle: state.subtitle
                )
                switch state.body {
                case .loading:
                    seasons(RiderResults.ViewState.Season.placeholders)
                        .redacted(reason: .placeholder)
                        .disabled(true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.tr("Loading the rider"))
                case .loaded(let seasons):
                    self.seasons(seasons)
                case .unavailable(let message):
                    MudMessageCard(message: message)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.mudPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle(L10n.tr("All results"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
    }

    private func seasons(_ seasons: [RiderResults.ViewState.Season]) -> some View {
        LazyVStack(alignment: .leading, spacing: 26) {
            ForEach(seasons) { season in
                MudPanel(title: season.title) {
                    MudRowsCard(items: season.rows) { row in
                        Button {
                            viewModel.action(.openResult(row.id))
                        } label: {
                            HStack(spacing: 10) {
                                MudPositionBadge(position: row.position)
                                VStack(alignment: .leading, spacing: 2) {
                                    TribuneruText(
                                        content: row.race,
                                        style: .vaporRaceNameResult,
                                        color: .tribuneru(.mudTextPrimary),
                                        lineLimit: 1
                                    )
                                    TribuneruText(
                                        content: row.date,
                                        style: .vaporMonoMeta,
                                        color: .tribuneru(.mudTextSecondary),
                                        lineLimit: 1
                                    )
                                }
                                Spacer(minLength: 0)
                                if row.isTappable {
                                    MudChevron()
                                }
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!row.isTappable)
                    }
                }
            }
        }
    }
}
