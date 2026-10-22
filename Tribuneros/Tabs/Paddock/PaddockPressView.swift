//
//  PaddockPressView.swift
//  Tribuneros
//
//  A press site's native headlines screen (route `paddockPress`). See `Paddock.PressPage`.
//

import SwiftUI

extension Paddock {

    struct PressView: View {
        @StateObject private var viewModel: PressPage.ViewModel<PressPage.InteractorImpl>

        init(
            item: PressItem,
            router: Router
        ) {
            _viewModel = StateObject(
                wrappedValue: PressPage.ViewModel(
                    router: router,
                    interactor: PressPage.InteractorImpl(item: item)
                )
            )
        }

        var body: some View {
            let state = viewModel.stateView
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PressHeader(state: state)
                    switch state.body {
                    case .loading:
                        headlines(PressPage.ViewState.placeholders)
                            .redacted(reason: .placeholder)
                            .shimmering()
                            .disabled(true)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(L10n.tr("Loading the headlines"))
                    case .loaded(let rows):
                        headlines(rows)
                    case .unavailable(let message):
                        unavailable(message)
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Color.tribuneru(.kitPageBackground))
            .preferredColorScheme(.dark)
            .navigationTitle(state.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.action(.onAppear)
            }
        }

        private func headlines(_ rows: [PressPage.ViewState.Row]) -> some View {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    Button {
                        viewModel.action(.openArticle(row.url))
                    } label: {
                        HeadlineCard(row: row)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("paddock.press.article.\(index)")
                }
            }
        }

        private func unavailable(_ message: String) -> some View {
            VStack(alignment: .leading, spacing: 14) {
                TribuneruText(
                    content: message,
                    style: .vaporMeta,
                    color: .tribuneru(.kitTextSecondary),
                    lineLimit: 3
                )
                .accessibilityIdentifier("paddock.press.unavailable")
                Button {
                    viewModel.action(.openSite)
                } label: {
                    TribuneruText(
                        content: L10n.tr("Open site"),
                        style: .vaporSeeAll,
                        color: .tribuneru(.kitAccent)
                    )
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        Capsule().fill(Color.tribuneru(.kitAccent).opacity(0.14))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("paddock.press.openSite")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kitCard()
        }
    }

    private struct PressHeader: View {
        let state: PressPage.ViewState

        var body: some View {
            HStack(spacing: 16) {
                Circle()
                    .fill(Color.tribuneru(.kitAvatar))
                    .overlay(
                        TribuneruText(
                            content: state.monogram,
                            style: .vaporHeading,
                            color: .tribuneru(.kitAvatarText),
                            lineLimit: 1
                        )
                    )
                    .padding(4)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.tribuneru(.kitAccent), lineWidth: 2.5)
                    )
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: state.name,
                        style: .vaporSectionTitle,
                        color: .tribuneru(.kitTextPrimary),
                        lineLimit: 2
                    )
                    TribuneruText(
                        content: state.domain,
                        style: .vaporMonoMeta,
                        color: .tribuneru(.kitTextSecondary),
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("paddock.press.header")
        }
    }

    private struct HeadlineCard: View {
        let row: PressPage.ViewState.Row

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                if row.imageURL != nil {
                    CachedImageView(
                        imageUrl: row.imageURL,
                        cornerRadius: 12,
                        presentation: .racePhoto
                    )
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                TribuneruText(
                    content: row.title,
                    style: .vaporRowTitle,
                    color: .tribuneru(.kitTextPrimary),
                    lineLimit: 3
                )
                if let summary = row.summary, !summary.isEmpty {
                    TribuneruText(
                        content: summary,
                        style: .vaporFeedDetail,
                        color: .tribuneru(.kitTextSecondary),
                        lineLimit: 3
                    )
                }
                if !row.date.isEmpty {
                    TribuneruText(
                        content: row.date,
                        style: .vaporMonoMeta,
                        color: .tribuneru(.kitAccent),
                        lineLimit: 1
                    )
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kitCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
    }
}
