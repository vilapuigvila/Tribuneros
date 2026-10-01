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
                header(state)
                content(state.body)
                if state.pcsURL != nil {
                    Button {
                        viewModel.action(.openOnPCS)
                    } label: {
                        VaporCard {
                            VaporMoreInfoLink(title: "Open on ProCyclingStats")
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
        .navigationTitle("Race Preview")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
    }

    private func header(_ state: RacePreview.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: state.title,
                style: .vaporHeading,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 3
            )
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("previewDetail.title")

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

    @ViewBuilder
    private func content(_ body: RacePreview.ViewState.Body) -> some View {
        switch body {
        case .loading:
            PreviewSections(content: .placeholders)
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading the race preview")
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
                        content: "Start",
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
                content: "Key points",
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

    var body: some View {
        VaporCard(spacing: 10) {
            TribuneruText(
                content: fact.text,
                style: .vaporRowTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 4
            )
            if !fact.header.isEmpty {
                tableRow(
                    fact.header,
                    color: .tribuneru(.vaporTextSecondary)
                )
            }
            ForEach(Array(fact.rows.enumerated()), id: \.offset) { _, row in
                tableRow(
                    row,
                    color: .tribuneru(.vaporTextPrimary)
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tableRow(
        _ cells: [String],
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                TribuneruText(
                    content: cell,
                    style: .vaporRowMeta,
                    color: color,
                    lineLimit: 1
                )
                .frame(
                    maxWidth: index == 1 ? .infinity : nil,
                    alignment: .leading
                )
            }
        }
    }
}
