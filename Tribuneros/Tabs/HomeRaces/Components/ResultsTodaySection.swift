//
//  ResultsTodaySection.swift
//  Tribuneros
//
//  "Results today": the title on one line, the spoiler chip under it, then a card per
//  finished race. With spoilers off the cards fold away and only the header stays.
//

import SwiftUI

extension HomeRaces.Representable.RaceFinished {
    /// The first podium entry that actually has a rider; yesterday's podiums are padded with blanks.
    var winner: Winner? {
        podium.first { !$0.name.isEmpty }
    }
}

struct ResultsTodaySection: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let isSpoilerModeOn: Bool
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        if races.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HomeSectionHeader(title: "Results today")
                HomeEmptyNote(text: "No results yet")
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    HomeSectionHeader(
                        title: "Results today",
                        reservesTapHeight: false
                    )
                    HomeSpoilerChip(
                        isSpoilerModeOn: isSpoilerModeOn,
                        action: { action(.spoilerModeResultToday) },
                        identifier: "home.results.spoiler"
                    )
                }
                cards
            }
        }
    }

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(races.enumerated()), id: \.element.id) { index, race in
                    ResultHighlightCard(race: race) { url in
                        action(.openLink(url))
                    }
                    .accessibilityIdentifier("home.results.card.\(index)")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.horizontal, -16)
        .foldsAway(unless: isSpoilerModeOn)
    }
}

struct ResultHighlightCard: View {
    private enum Sizes {
        static let width: CGFloat = 180
        static let photoHeight: CGFloat = 112
        static let cornerRadius: CGFloat = 16
    }

    let race: HomeRaces.Representable.RaceFinished
    let open: (URL) -> Void

    @ViewBuilder
    var body: some View {
        if let url = race.raceURL {
            Button {
                open(url)
            } label: {
                card
            }
            .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            CachedImageView(
                imageUrl: race.winnerImgURL,
                cornerRadius: 0,
                contentMode: .fill,
                fallback: .raceArt
            )
            .frame(width: Sizes.width, height: Sizes.photoHeight, alignment: .top)
            .clipped()
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
