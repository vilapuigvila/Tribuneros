//
//  HistorySection.swift
//  Tribuneros
//

import SwiftUI

struct HistorySection: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let action: (HomeRaces.Action) -> Void

    static let previewLimit = 3

    private var seeAll: (() -> Void)? {
        guard races.count > Self.previewLimit else { return nil }
        return { action(.navigate(.historyResults)) }
    }

    var body: some View {
        HomeSection(
            title: "History",
            seeAll: seeAll,
            seeAllIdentifier: "home.history.seeAll"
        ) {
            if races.isEmpty {
                HistoryBanner()
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(races.prefix(Self.previewLimit).enumerated()), id: \.element.id) { index, race in
                        HistoryRaceRow(race: race) {
                            action(.openRaceResult(race))
                        }
                        .accessibilityIdentifier("home.history.row.\(index)")
                    }
                }
            }
        }
    }
}

struct HistoryRaceRow: View {
    let race: HomeRaces.Representable.RaceFinished
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if !race.raceCountryCode.isEmpty {
                        VaporFlagView(countryCode: race.raceCountryCode)
                    }
                    TribuneruText(
                        content: race.race,
                        style: .vaporRowTitle,
                        color: .tribuneru(.white(level: 1)),
                        lineLimit: 1
                    )
                }

                if !race.raceDetails.isEmpty {
                    TribuneruText(
                        content: race.raceDetails,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }

                if let winner = race.podium.first, !winner.name.isEmpty {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            TribuneruText(
                                content: winner.name,
                                style: .vaporResultTitle,
                                color: .tribuneru(.white(level: 1)),
                                lineLimit: 1
                            )

                            if !winner.team.isEmpty && winner.team != "#" {
                                TribuneruText(
                                    content: winner.team,
                                    style: .vaporRowMeta,
                                    color: .tribuneru(.vaporTextSecondary),
                                    lineLimit: 1
                                )
                            }
                        }

                        Spacer()

                        if !winner.time.isEmpty && winner.time != "#" {
                            TribuneruText(
                                content: winner.time,
                                style: .vaporResultTime,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 1
                            )
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard()
        }
    }
}

struct HistoryBanner: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RaceArtView(art: .banner)
            LinearGradient(
                colors: [
                    Color.tribuneru(.vaporPageBackground).opacity(0.88),
                    Color.tribuneru(.vaporPageBackground).opacity(0.55),
                    Color.tribuneru(.vaporPageBackground).opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: "Browse past seasons",
                        style: .vaporBannerTitle,
                        color: .tribuneru(.white(level: 1)),
                        lineLimit: 1
                    )
                    .artTitleShadow()
                    TribuneruText(
                        content: "Results, standings and more",
                        style: .vaporBannerSubtitle,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.85),
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporTextPrimary))
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 124)
        .homeCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.history.banner")
    }
}
