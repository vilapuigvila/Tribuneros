//
//  RacePreviewDetailView.swift
//  Tribuneros
//
//  The race preview screen opened from a Results today preview (route `racePreview`). See
//  `HomeRaces.RacePreview` for what it shows and where it comes from.
//

import SwiftUI

struct RacePreviewDetailView: View {
    private typealias RacePreview = HomeRaces.RacePreview

    @StateObject private var viewModel: RacePreview.ViewModel<RacePreview.InteractorImpl>

    init(
        preview: HomeRaces.Representable.RacePreview,
        router: Router,
        loadPage: @escaping (URL) async -> DTO.PreviewPage? = {
            await Service.getPreviewPage(url: $0)
        }
    ) {
        _viewModel = StateObject(
            wrappedValue: RacePreview.ViewModel(
                preview: preview,
                router: router,
                interactor: RacePreview.InteractorImpl(
                    url: preview.url,
                    loadPage: loadPage
                )
            )
        )
    }

    var body: some View {
        let state = viewModel.stateView
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RaceDetailHero(
                    title: state.title,
                    subtitle: state.subtitle,
                    titleIdentifier: "previewDetail.title"
                )
                content(state.body)
                if state.pcsURL != nil {
                    Button {
                        viewModel.action(.openOnPCS)
                    } label: {
                        VaporCard {
                            VaporMoreInfoLink(title: L10n.tr("Open on ProCyclingStats"))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .padding(.bottom, 48)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle(L10n.tr("Race Preview"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
    }

    @ViewBuilder
    private func content(_ body: RacePreview.ViewState.Body) -> some View {
        switch body {
        case .loading:
            PreviewSections(content: .placeholders)
                .redacted(reason: .placeholder)
                .shimmering()
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.tr("Loading the race preview"))
        case .loaded(let content):
            PreviewSections(content: content)
        case .unavailable(let message):
            TribuneruText(
                content: message,
                style: .vaporRowMeta,
                color: .tribuneru(.vaporTextMuted),
                lineLimit: 2
            )
        }
    }
}

private struct PreviewSections: View {
    let content: HomeRaces.RacePreview.ViewState.Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let start = content.start {
                VaporCard(spacing: 4) {
                    TribuneruText(
                        content: L10n.tr("Start"),
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                    TribuneruText(
                        content: start,
                        style: .vaporResultTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("previewDetail.start")
            }

            if !content.keypoints.isEmpty {
                keypoints
            }

            ForEach(content.facts) { fact in
                FactCard(fact: fact)
                    .accessibilityIdentifier("previewDetail.fact.\(fact.id)")
            }
        }
    }

    private var keypoints: some View {
        VStack(alignment: .leading, spacing: 10) {
            TribuneruText(
                content: L10n.tr("Key points"),
                style: .vaporRowTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            VaporCard(spacing: 0) {
                ForEach(Array(content.keypoints.enumerated()), id: \.offset) { index, keypoint in
                    if index > 0 {
                        TribunerosDivider(
                            height: 1,
                            color: Color.tribuneru(.vaporTextPrimary).opacity(0.08)
                        )
                    }
                    HStack(spacing: 12) {
                        TribuneruText(
                            content: keypoint.km,
                            style: .vaporPill,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                        .frame(
                            width: 48,
                            alignment: .leading
                        )
                        TribuneruText(
                            content: keypoint.name,
                            style: .vaporRaceNameNext,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 2
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        TribuneruText(
                            content: keypoint.type,
                            style: .vaporRowMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("previewDetail.keypoint.\(index)")
                }
            }
        }
    }
}

private struct FactCard: View {
    let fact: HomeRaces.RacePreview.ViewState.Fact

    private var hasTable: Bool {
        !fact.header.isEmpty || !fact.rows.isEmpty
    }

    var body: some View {
        VaporCard(spacing: 0) {
            TribuneruText(
                content: fact.text,
                style: .vaporRowTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 4
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            if hasTable {
                if !fact.header.isEmpty {
                    tableRow(
                        fact.header,
                        isHeader: true
                    )
                    .padding(.top, 12)
                }
                ForEach(Array(fact.rows.enumerated()), id: \.offset) { _, row in
                    TribunerosDivider(
                        height: 1,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.08)
                    )
                    tableRow(
                        row,
                        isHeader: false
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tableRow(
        _ cells: [String],
        isHeader: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                TribuneruText(
                    content: isHeader ? cell.uppercased(with: L10n.locale) : cell,
                    style: isHeader ? .vaporGroupLabel : (index == 0 ? .vaporRaceNameNext : .vaporResultTime),
                    color: isHeader ? .tribuneru(.vaporTextSecondary) : .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .frame(
                    maxWidth: index == 0 ? .infinity : nil,
                    alignment: index == 0 ? .leading : .trailing
                )
            }
        }
        .padding(.vertical, isHeader ? 6 : 10)
    }
}
