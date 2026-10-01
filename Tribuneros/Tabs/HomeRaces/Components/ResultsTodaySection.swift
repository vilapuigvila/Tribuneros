//
//  ResultsTodaySection.swift
//  Tribuneros
//

import SwiftUI

struct ResultsTodaySection: View {
    let races: [HomeRaces.Representable.RaceFinished]
    var previews: [HomeRaces.Representable.RacePreview] = []
    let isSpoilerModeOn: Bool
    let action: (HomeRaces.Action) -> Void

    private var spoiler: HomeSpoiler? {
        guard !races.isEmpty else { return nil }
        return HomeSpoiler(
            isOn: isSpoilerModeOn,
            identifier: "home.results.spoiler"
        ) {
            action(.spoilerModeResultToday)
        }
    }

    var body: some View {
        HomeSection(title: "Results today", spoiler: spoiler) {
            if !races.isEmpty {
                cards
            } else if previews.isEmpty {
                HomeEmptyNote(text: "No results yet")
            } else {
                RacePreviewsCard(
                    previews: previews,
                    open: { action(.openRacePreview($0)) }
                )
            }
        }
    }

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(races.enumerated()), id: \.offset) { index, race in
                    ResultHighlightCard(race: race) {
                        action(.openRaceResult(race))
                    }
                    .accessibilityIdentifier("home.results.card.\(index)")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.horizontal, -16)
    }
}

struct RacePreviewsCard: View {
    let previews: [HomeRaces.Representable.RacePreview]
    let open: (HomeRaces.Representable.RacePreview) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(previews.enumerated()), id: \.offset) { index, preview in
                if index > 0 {
                    TribunerosDivider(
                        height: 0.5,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.08)
                    )
                }
                Button {
                    open(preview)
                } label: {
                    row(preview)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.previews.row.\(index)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .homeCard()
    }

    private func row(_ preview: HomeRaces.Representable.RacePreview) -> some View {
        HStack(spacing: 14) {
            TribuneruText(
                content: preview.countdown,
                style: .vaporRowCountdown,
                color: .tribuneru(.vaporAccent),
                lineLimit: 1
            )
            .frame(
                minWidth: 40,
                alignment: .leading
            )
            TribuneruText(
                content: preview.name,
                style: .vaporResultTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporTextSecondary))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ResultHighlightCard: View {
    private enum Sizes {
        static let width: CGFloat = 180
        static let photoHeight: CGFloat = 112
        static let cornerRadius: CGFloat = 16
    }

    let race: HomeRaces.Representable.RaceFinished
    let open: () -> Void

    var body: some View {
        Button {
            open()
        } label: {
            card
        }
        .buttonStyle(.plain)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            WinnerPhoto(
                url: race.winnerImgURL,
                size: CGSize(width: Sizes.width, height: Sizes.photoHeight)
            )
            details
        }
        .frame(width: Sizes.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.tribuneru(.vaporCardSurface))
        .clipShape(RoundedRectangle(cornerRadius: Sizes.cornerRadius))
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: race.race,
                style: .vaporRaceNameResult,
                color: Color.tribuneru(.vaporTextPrimary).opacity(0.72),
                lineLimit: 2
            )
            if !race.raceDetails.isEmpty {
                TribuneruText(
                    content: race.raceDetails,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }
            if let winner = race.winner {
                HStack(spacing: 6) {
                    VaporFlagView(countryCode: winner.countryCode)
                    TribuneruText(
                        content: winner.name,
                        style: .vaporWinnerName,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                }
                if !winner.time.isEmpty {
                    TribuneruText(
                        content: winner.time,
                        style: .vaporFinishTime,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.6)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}
