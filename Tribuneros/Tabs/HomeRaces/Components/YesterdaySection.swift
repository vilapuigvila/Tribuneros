//
//  YesterdaySection.swift
//  Tribuneros
//

import SwiftUI

struct YesterdaySection: View {
    static let previewLimit = 3

    let races: [HomeRaces.Representable.RaceFinished]
    let isSpoilerModeOn: Bool
    let action: (HomeRaces.Action) -> Void

    private var seeAll: (() -> Void)? {
        guard races.count > Self.previewLimit else { return nil }
        return { action(.navigate(.yesterdayResults)) }
    }

    private var spoiler: HomeSpoiler? {
        guard !races.isEmpty else { return nil }
        return HomeSpoiler(
            isOn: isSpoilerModeOn,
            identifier: "home.yesterday.spoiler"
        ) {
            action(.spoilerModeResultYesterday)
        }
    }

    var body: some View {
        HomeSection(
            title: "Yesterday",
            seeAll: seeAll,
            seeAllIdentifier: "home.yesterday.seeAll",
            spoiler: spoiler
        ) {
            if races.isEmpty {
                HomeEmptyNote(text: "No results")
            } else {
                YesterdayResultsCard(
                    races: Array(races.prefix(Self.previewLimit)),
                    identifierPrefix: "home.yesterday"
                ) { race in
                    action(.openRaceResult(race))
                }
            }
        }
    }
}

struct YesterdayResultsCard: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let identifierPrefix: String
    let open: (HomeRaces.Representable.RaceFinished) -> Void

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
                YesterdayResultRow(race: race, open: open)
                    .accessibilityIdentifier("\(identifierPrefix).row.\(index)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .homeCard()
    }
}

struct YesterdayResultRow: View {
    let race: HomeRaces.Representable.RaceFinished
    let open: (HomeRaces.Representable.RaceFinished) -> Void

    var body: some View {
        Button {
            open(race)
        } label: {
            row
        }
        .buttonStyle(.plain)
    }

    private var row: some View {
        HStack(spacing: 14) {
            WinnerPhoto(
                url: race.winnerImgURL,
                size: CGSize(width: 72, height: 72)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                TribuneruText(
                    content: race.race,
                    style: .vaporResultTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                if !race.raceDetails.isEmpty {
                    TribuneruText(
                        content: race.raceDetails,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
                if let winner = race.winner {
                    winnerLine(winner)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if race.raceURL != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
