//
//  HistoryResultsListView.swift
//  Tribuneros
//

import SwiftUI

struct HistoryResultsListView: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        HomeListScreen {
            VStack(alignment: .leading, spacing: 6) {
                TribuneruText(
                    content: "History",
                    style: .vaporSectionTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 2)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(races.enumerated()), id: \.element.id) { index, race in
                        HistoryResultCard(race: race) {
                            action(.openRaceResult(race))
                        }
                        .accessibilityIdentifier("historyResults.row.\(index)")
                    }
                }
            }
        }
    }
}

struct HistoryResultCard: View {
    let race: HomeRaces.Representable.RaceFinished
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                TribuneruText(
                    content: race.race,
                    style: .vaporRowTitle,
                    color: .tribuneru(.white(level: 1)),
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

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(race.podium, id: \.id) { winner in
                        HStack(spacing: 8) {
                            TribuneruText(
                                content: winner.position,
                                style: .vaporRowMeta,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 1
                            )
                            .frame(width: 20)

                            if let flagURL = winner.flag {
                                CachedImageView(
                                    imageUrl: flagURL,
                                    cornerRadius: 2
                                )
                                .frame(width: 16, height: 12)
                            }

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
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard()
        }
    }
}
