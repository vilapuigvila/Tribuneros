//
//  CXRankingView.swift
//  Tribuneros
//
//  A full ranking or series standings table (route `cxZone(.ranking)`). See `CXRaces.Ranking`.
//

import SwiftUI

struct CXRankingView: View {
    private typealias Ranking = CXRaces.Ranking

    @StateObject private var viewModel: Ranking.ViewModel<Ranking.InteractorImpl>

    init(
        context: CXRaces.RankingContext,
        router: Router
    ) {
        _viewModel = StateObject(
            wrappedValue: Ranking.ViewModel(
                router: router,
                interactor: Ranking.InteractorImpl(context: context)
            )
        )
    }

    var body: some View {
        let state = viewModel.stateView
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MudPageHeader(
                    title: state.title,
                    subtitle: L10n.tr("Standings").uppercased(with: L10n.locale),
                    logoURL: state.logoURL
                )
                if let chips = state.chips {
                    chipsRow(chips)
                }
                switch state.body {
                case .loading:
                    VStack(alignment: .leading, spacing: 20) {
                        if state.chips == nil {
                            chipsRow(Ranking.ViewState.Chip.placeholders)
                        }
                        rows(Ranking.ViewState.Row.placeholders)
                    }
                    .redacted(reason: .placeholder)
                    .disabled(true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.tr("Loading the ranking"))
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
        .navigationTitle(L10n.tr("Ranking"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
    }

    private func chipsRow(_ chips: [Ranking.ViewState.Chip]) -> some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(spacing: 6) {
                ForEach(chips) { chip in
                    Button {
                        viewModel.action(.selectCategory(chip.id))
                    } label: {
                        TribuneruText(
                            content: chip.title.uppercased(with: L10n.locale),
                            style: .vaporSpoilerChip,
                            color: .tribuneru(chip.isSelected ? .mudAccent : .mudTextPrimary),
                            lineLimit: 1
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                chip.isSelected
                                    ? Color.tribuneru(.mudAccent).opacity(0.14)
                                    : Color.tribuneru(.mudCardSurface)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                chip.isSelected
                                    ? Color.tribuneru(.mudAccent).opacity(0.4)
                                    : Color.tribuneru(.mudTextPrimary).opacity(0.08),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ranking-chip-\(chip.title)")
                    .accessibilityAddTraits(chip.isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func rows(_ rows: [Ranking.ViewState.Row]) -> some View {
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
                        if let team = row.team {
                            TribuneruText(
                                content: team,
                                style: .vaporMeta,
                                color: .tribuneru(.mudTextSecondary),
                                lineLimit: 1
                            )
                        }
                    }
                    Spacer(minLength: 0)
                    TribuneruText(
                        content: row.points,
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
            .accessibilityIdentifier("ranking-row-\(row.position)")
        }
    }
}
