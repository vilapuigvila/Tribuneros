//
//  YesterdaySection.swift
//  Tribuneros
//
//  "Yesterday": the title with "See all", the spoiler chip under it, then one card holding a
//  row per finished race. The card previews a few; "See all" opens the whole list.
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

    var body: some View {
        if races.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HomeSectionHeader(title: "Yesterday")
                HomeEmptyNote(text: "No results")
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    HomeSectionHeader(
                        title: "Yesterday",
                        seeAll: seeAll,
                        reservesTapHeight: false,
                        seeAllIdentifier: "home.yesterday.seeAll"
                    )
                    HomeSpoilerChip(
                        isSpoilerModeOn: isSpoilerModeOn,
                        action: { action(.spoilerModeResultYesterday) },
                        identifier: "home.yesterday.spoiler"
                    )
                }
                YesterdayResultsCard(
                    races: Array(races.prefix(Self.previewLimit)),
                    identifierPrefix: "home.yesterday"
                ) { url in
                    action(.openLink(url))
                }
                .foldsAway(unless: isSpoilerModeOn)
            }
        }
    }
}

struct YesterdayResultsCard: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let identifierPrefix: String
    let open: (URL) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(races.enumerated()), id: \.element.id) { index, race in
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
    let open: (URL) -> Void

    @ViewBuilder
    var body: some View {
        if let url = race.raceURL {
            Button {
                open(url)
            } label: {
                row(showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            row(showsChevron: false)
        }
    }

    private func row(showsChevron: Bool) -> some View {
        HStack(spacing: 14) {
            CachedImageView(
                imageUrl: race.winnerImgURL,
                cornerRadius: 0,
                contentMode: .fill,
                fallback: .raceArt
            )
            .frame(width: 72, height: 72, alignment: .top)
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
            if showsChevron {
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

extension View {
    /// Collapses and fades a section body, the way spoiler mode hides results.
    func foldsAway(unless isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .frame(maxHeight: isShown ? nil : 0)
            .clipped()
            .animation(.interpolatingSpring(.smooth, initialVelocity: 0.5), value: isShown)
            .accessibilityHidden(!isShown)
    }
}
