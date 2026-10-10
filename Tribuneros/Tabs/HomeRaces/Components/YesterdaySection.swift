//
//  YesterdaySection.swift
//  Tribuneros
//

import SwiftUI

struct YesterdaySection: View {
    static let previewLimit = 3

    let races: [HomeRaces.Representable.RaceFinished]
    var isHintAnchor = false
    let action: (HomeRaces.Action) -> Void

    private var seeAll: (() -> Void)? {
        guard races.count > Self.previewLimit else { return nil }
        return { action(.navigate(.yesterdayResults)) }
    }

    var body: some View {
        HomeSection(
            title: L10n.tr("Results yesterday"),
            seeAll: seeAll,
            seeAllIdentifier: "home.yesterday.seeAll"
        ) {
            if races.isEmpty {
                ResultsEmptyCard(
                    title: L10n.tr("No results yesterday"),
                    size: CGSize(width: 0, height: 108),
                    identifier: "home.yesterday.empty",
                    isFullWidth: true
                )
            } else {
                YesterdayResultsCard(
                    races: Array(races.prefix(Self.previewLimit)),
                    identifierPrefix: "home.yesterday",
                    artIdentifierPrefix: "home.yesterday.spoilerArt",
                    hintAnchorIndex: isHintAnchor ? 0 : nil,
                    open: { race in action(.openRaceResult(race)) },
                    toggle: { race in action(.toggleReveal(race)) }
                )
            }
        }
    }
}

struct YesterdayResultsCard: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let identifierPrefix: String
    var artIdentifierPrefix: String?
    var hintAnchorIndex: Int?
    let open: (HomeRaces.Representable.RaceFinished) -> Void
    let toggle: (HomeRaces.Representable.RaceFinished) -> Void

    var body: some View {
        // Not lazy: re-estimated row heights resize the page mid-scroll and make it jump at the top.
        VStack(spacing: 0) {
            ForEach(Array(races.enumerated()), id: \.offset) { index, race in
                if index > 0 {
                    TribunerosDivider(
                        height: 0.5,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.08)
                    )
                }
                YesterdayResultRow(
                    race: race,
                    visibility: race.visibility
                )
                    .accessibilityIdentifier("\(identifierPrefix)\(race.visibility == .placeholder ? ".placeholder" : "").row.\(index)")
                    .spoilerHintAnchor(hintAnchorIndex == index)
                    .spoilerArt(
                        race.visibility,
                        size: CGSize(width: 72, height: 72),
                        alignment: .leading,
                        identifier: artIdentifierPrefix.map { "\($0).\(index)" }
                    )
                    .resultGestures(
                        race.visibility,
                        open: { open(race) },
                        toggle: { toggle(race) }
                    )
                    .spoilerCrossfade(race.visibility)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .homeCard()
    }
}

struct YesterdayResultRow: View {
    let race: HomeRaces.Representable.RaceFinished
    var visibility: HomeRaces.ResultVisibility = .shown

    var body: some View {
        row
    }

    private var shownRace: HomeRaces.Representable.RaceFinished {
        race.shown(visibility)
    }

    private var row: some View {
        HStack(spacing: 14) {
            WinnerPhoto(
                url: shownRace.winnerImgURL,
                size: CGSize(width: 72, height: 72),
                isHiddenBySpoiler: visibility == .hidden
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                TribuneruText(
                    content: shownRace.race,
                    style: .vaporResultTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .unredacted(if: visibility == .hidden)
                if !shownRace.raceDetails.isEmpty {
                    TribuneruText(
                        content: shownRace.raceDetails,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
                if let winner = shownRace.winner {
                    winnerLine(winner)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if visibility == .shown, race.raceURL != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .redactedResult(
            visibility,
            title: race.race
        )
    }

    private func winnerLine(_ winner: HomeRaces.Representable.RaceFinished.Winner) -> some View {
        HStack(spacing: 6) {
            if !winner.time.isEmpty {
                TribuneruText(
                    content: winner.time,
                    style: .vaporResultTime,
                    color: .tribuneru(.vaporTextPrimary)
                )
                TribuneruText(
                    content: "·",
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextMuted)
                )
            }
            VaporFlagView(countryCode: winner.countryCode)
            TribuneruText(
                content: winner.name,
                style: .vaporRowMeta,
                color: .tribuneru(.vaporTextMuted),
                lineLimit: 1
            )
        }
    }
}
