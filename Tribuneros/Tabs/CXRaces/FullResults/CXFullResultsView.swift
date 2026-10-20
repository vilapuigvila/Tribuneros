//
//  CXFullResultsView.swift
//  Tribuneros
//
//  The full Men Elite results of a calendar race (route `cxZone(.fullResults)`). See
//  `CXRaces.FullResults`.
//

import SwiftUI

struct CXFullResultsView: View {
    private typealias FullResults = CXRaces.FullResults

    @StateObject private var viewModel: FullResults.ViewModel<FullResults.InteractorImpl>

    init(
        event: DTO.CXCalendarEvent,
        results: [DTO.CX24Homepage.CategoryResult],
        router: Router
    ) {
        _viewModel = StateObject(
            wrappedValue: FullResults.ViewModel(
                router: router,
                interactor: FullResults.InteractorImpl(
                    event: event,
                    results: results
                )
            )
        )
    }

    var body: some View {
        let state = viewModel.stateView
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MudPageHeader(
                    title: state.title,
                    subtitle: state.subtitle
                )
                switch state.body {
                case .loading:
                    rows(FullResults.ViewState.Row.placeholders)
                        .redacted(reason: .placeholder)
                        .disabled(true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.tr("Loading the results"))
                case .loaded(let rows):
                    self.rows(rows)
                case .unavailable(let message):
                    MudMessageCard(message: message)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.mudPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle(L10n.tr("Results"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
    }

    private func rows(_ rows: [FullResults.ViewState.Row]) -> some View {
        MudRowsCard(items: rows) { row in
            Button {
                viewModel.action(.openRow(row.id))
            } label: {
                HStack(spacing: 10) {
                    MudPositionBadge(position: row.position)
                    VaporFlagView(url: row.flagURL)
                    VStack(alignment: .leading, spacing: 2) {
                        TribuneruText(
                            content: row.rider,
                            style: .vaporRaceNameResult,
                            color: .tribuneru(.mudTextPrimary),
                            lineLimit: 1
                        )
                        if !row.team.isEmpty {
                            TribuneruText(
                                content: row.team,
                                style: .vaporMeta,
                                color: .tribuneru(.mudTextSecondary),
                                lineLimit: 1
                            )
                        }
                    }
                    Spacer(minLength: 0)
                    TribuneruText(
                        content: row.time,
                        style: .vaporFinishTime,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                    MudChevron()
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("full-results-row-\(row.position)")
        }
    }
}
