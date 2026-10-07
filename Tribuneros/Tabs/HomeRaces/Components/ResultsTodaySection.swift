//
//  ResultsTodaySection.swift
//  Tribuneros
//

import SwiftUI

struct ResultsTodaySection: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let isSpoilerModeOn: Bool
    var isHintAnchor = false
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        HomeSection(title: "Results today") {
            cards
        }
    }

    private var visibility: HomeRaces.ResultVisibility {
        if races.isEmpty { return .placeholder }
        return isSpoilerModeOn ? .shown : .hidden
    }

    private var shownRaces: [HomeRaces.Representable.RaceFinished] {
        races.isEmpty ? Array(HomeRaces.Representable.placeholderResults.prefix(2)) : races
    }

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(shownRaces.enumerated()), id: \.offset) { index, race in
                    ResultHighlightCard(
                        race: race,
                        visibility: visibility
                    )
                    .accessibilityIdentifier("home.results.\(races.isEmpty ? "placeholder" : "card").\(index)")
                    .spoilerHintAnchor(isHintAnchor && index == 0)
                    .spoilerArt(
                        visibility,
                        size: CGSize(width: 180, height: 112),
                        alignment: .top,
                        identifier: "home.results.spoilerArt.\(index)"
                    )
                    .resultGestures(
                        visibility,
                        open: { action(.openRaceResult(race)) },
                        toggle: { action(.spoilerModeResultToday) }
                    )
                    .spoilerCrossfade(isSpoilerModeOn)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.horizontal, -16)
    }
}

struct ResultHighlightCard: View {
    private enum Sizes {
        static let width: CGFloat = 180
        static let photoHeight: CGFloat = 112
        static let cornerRadius: CGFloat = 16
    }

    let race: HomeRaces.Representable.RaceFinished
    var visibility: HomeRaces.ResultVisibility = .shown

    var body: some View {
        card
    }

    private var shownRace: HomeRaces.Representable.RaceFinished {
        race.shown(visibility)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            WinnerPhoto(
                url: shownRace.winnerImgURL,
                size: CGSize(width: Sizes.width, height: Sizes.photoHeight),
                isHiddenBySpoiler: visibility == .hidden
            )
            details
        }
        .frame(width: Sizes.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.tribuneru(.vaporCardSurface))
        .clipShape(RoundedRectangle(cornerRadius: Sizes.cornerRadius))
        .accessibilityElement(children: .combine)
        .redactedResult(
            visibility,
            title: race.race
        )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: shownRace.race,
                style: .vaporRaceNameResult,
                color: Color.tribuneru(.vaporTextPrimary).opacity(0.72),
                lineLimit: 2
            )
            .unredacted(if: visibility == .hidden)
            if !shownRace.raceDetails.isEmpty {
                TribuneruText(
                    content: shownRace.raceDetails,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }
            if let winner = shownRace.winner {
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
