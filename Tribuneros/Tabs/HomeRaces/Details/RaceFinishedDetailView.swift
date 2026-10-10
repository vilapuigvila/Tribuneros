//
//  RaceFinishedDetailView.swift
//  Tribuneros
//
//  The race result screen opened from a Results today, Yesterday or History card (route
//  `raceResultDetail`). See `HomeRaces.RaceResult` for what it shows and where it comes from.
//

import SwiftUI

struct RaceFinishedDetailView: View {
    private typealias RaceResult = HomeRaces.RaceResult

    @StateObject private var viewModel: RaceResult.ViewModel<RaceResult.InteractorImpl>

    init(
        raceFinished: HomeRaces.Representable.RaceFinished,
        router: Router,
        loadPage: @escaping (URL) async -> DTO.RaceResultPage? = {
            await Service.getCachedRaceResultPage(url: $0)
        }
    ) {
        _viewModel = StateObject(
            wrappedValue: RaceResult.ViewModel(
                race: raceFinished,
                router: router,
                interactor: RaceResult.InteractorImpl(
                    descriptor: RaceResult.Descriptor(
                        name: raceFinished.race,
                        details: raceFinished.raceDetails,
                        url: raceFinished.raceURL
                    ),
                    loadPage: loadPage
                )
            )
        )
    }

    var body: some View {
        let state = viewModel.stateView
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(state)

                if let imageURL = state.winnerImgURL {
                    CachedImageView(
                        imageUrl: imageURL,
                        cornerRadius: 12,
                        presentation: .racePhoto
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !state.classifications.isEmpty {
                    ClassificationChips(
                        classifications: state.classifications,
                        selected: state.selected
                    ) {
                        viewModel.action(.select($0))
                    }
                }

                ResultTable(table: state.table)

                if state.fullResultsURL != nil {
                    Button {
                        viewModel.action(.openFullResults)
                    } label: {
                        VaporCard {
                            VaporMoreInfoLink(title: L10n.tr("View full results"))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle(L10n.tr("Race Result"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
    }

    private func header(_ state: RaceResult.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: state.title,
                style: .vaporHeading,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 3
            )
            .accessibilityAddTraits(.isHeader)

            if !state.subtitle.isEmpty {
                TribuneruText(
                    content: state.subtitle,
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}

// MARK: - Stage / GC chips -

private struct ClassificationChips: View {
    let classifications: [HomeRaces.RaceResult.Classification]
    let selected: HomeRaces.RaceResult.Classification
    let select: (HomeRaces.RaceResult.Classification) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(classifications, id: \.self) { classification in
                let isSelected = classification == selected
                Button {
                    select(classification)
                } label: {
                    TribuneruText(
                        content: classification.title.uppercased(with: L10n.locale),
                        style: .vaporSpoilerChip,
                        color: isSelected ? .tribuneru(.vaporPageBackground) : .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        isSelected
                        ? Color.tribuneru(.vaporAccent)
                        : Color.tribuneru(.vaporCardSurface)
                    )
                    .clipShape(Capsule())
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    classification == .gc
                        ? L10n.tr("General classification")
                        : L10n.tr("Stage result")
                )
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Results -

private struct ResultTable: View {
    let table: HomeRaces.RaceResult.ViewState.Table

    var body: some View {
        switch table {
        case .loading:
            ResultRows(rows: HomeRaces.RaceResult.ViewState.Row.placeholders)
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.tr("Loading the results"))
        case .loaded(let rows):
            ResultRows(rows: rows)
        case .unavailable(let fallback, let message):
            VStack(alignment: .leading, spacing: 12) {
                TribuneruText(
                    content: message,
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextMuted),
                    lineLimit: 2
                )
                if !fallback.isEmpty {
                    ResultRows(rows: fallback)
                }
            }
        }
    }
}

private struct ResultRows: View {
    let rows: [HomeRaces.RaceResult.ViewState.Row]

    var body: some View {
        VaporCard(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    TribunerosDivider(
                        height: 1,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.08)
                    )
                }
                RaceResultRow(row: row)
            }
        }
    }
}

struct RaceResultRow: View {
    let row: HomeRaces.RaceResult.ViewState.Row

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            TribuneruText(
                content: row.position,
                style: .vaporPill,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            .frame(
                width: 28,
                alignment: .leading
            )

            if !row.countryCode.isEmpty {
                VaporFlagView(countryCode: row.countryCode)
            }

            VStack(alignment: .leading, spacing: 2) {
                TribuneruText(
                    content: row.name,
                    style: .vaporRaceNameNext,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                if !row.team.isEmpty {
                    TribuneruText(
                        content: row.team,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )

            if !row.time.isEmpty {
                TribuneruText(
                    content: row.time,
                    style: .vaporResultTime,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews -

#Preview("Stage") {
    NavigationStack {
        RaceFinishedDetailView(
            raceFinished: .previewStage,
            router: Router(),
            loadPage: { _ in .previewStage }
        )
    }
}

#Preview("Loading") {
    NavigationStack {
        RaceFinishedDetailView(
            raceFinished: .previewStage,
            router: Router(),
            loadPage: { _ in
                try? await Task.sleep(for: .seconds(3600))
                return nil
            }
        )
    }
}

#Preview("Failed") {
    NavigationStack {
        RaceFinishedDetailView(
            raceFinished: .previewStage,
            router: Router(),
            loadPage: { _ in nil }
        )
    }
}

private extension HomeRaces.Representable.RaceFinished {
    static let previewStage = HomeRaces.Representable.RaceFinished(
        race: "Skoda Tour de Luxembourg (2.Pro)",
        raceDetails: "Stage 5 | Mersch - Luxembourg-Limpertsberg (177km)",
        winnerImgURL: nil,
        podium: [
            .init(
                position: "1",
                flag: nil,
                countryCode: "nl",
                name: "VAN DER POEL Mathieu",
                team: "Alpecin - Premier Tech",
                time: "4:12:05"
            ),
            .init(
                position: "2",
                flag: nil,
                countryCode: "fr",
                name: "GACHIGNARD Thomas",
                team: "TotalEnergies",
                time: "0:00"
            ),
            .init(
                position: "3",
                flag: nil,
                countryCode: "it",
                name: "PIGANZOLI Davide",
                team: "Visma | Lease a Bike",
                time: "0:04"
            )
        ],
        isCancel: false,
        raceURL: URL(string: "https://www.procyclingstats.com/race/tour-de-luxembourg/2026/stage-5")
    )
}

private extension DTO.RaceResultPage {
    static let previewStage = DTO.RaceResultPage(
        stage: "Stage 5",
        from: "Mersch",
        to: "Luxembourg-Limpertsberg",
        distance: "177km",
        rows: (1...10).map {
            Row(
                position: "\($0)",
                name: "RIDER \($0)",
                team: "Team \($0)",
                time: $0 == 1 ? "4:12:05" : ($0 < 4 ? ",," : "0:\(10 + $0)"),
                countryCode: ["be", "nl", "fr", "it"][$0 % 4]
            )
        }
    )
}
