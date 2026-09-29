//
//  LatestResultsView.swift
//  Tribuneros
//
//  Created by albert vila on 9/1/26.
//

import SwiftUI

struct LatestResultsView: View {
    let races: DTO.CX24Homepage
    /// A podium row opens the rider screen; the rest of the card opens the full list (`action`).
    var openRider: (CXRaces.RiderPodium) -> Void = { _ in }
    let action: () -> Void

    var body: some View {
        if let firstRace = firstRaceFromFirstSection {
            VaporCard {
                HStack(spacing: 10) {
                    VaporFlagView(url: firstRace.countryFlagURL)

                    TribuneruText(
                        content: firstRace.title,
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )

                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.tribuneru(.vaporTextSecondary))
                        TribuneruText(
                            content: firstRace.date,
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.tribuneru(.vaporTextSecondary))
                        TribuneruText(
                            content: firstRace.location,
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 12) {
                    ForEach(firstRace.categories.prefix(2).indices, id: \.self) { idx in
                        let category = firstRace.categories[idx]
                        CategoryResultsView(category: category) { podium in
                            openRider(
                                CXRaces.RiderPodium(
                                    podium: podium,
                                    category: category,
                                    race: firstRace.race
                                )
                            )
                        }
                    }
                }

                VaporMoreInfoLink()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                action()
            }
        } else {
            TribuneruText(
                content: "No results found.",
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 2
            )
            .padding(12)
            .background(Color.tribuneru(.vaporCardSurface))
            .cornerRadius(8)
        }
    }

    private struct FirstRaceInfo {
        let title: String
        let countryFlagURL: URL?
        let date: String
        let location: String
        let categories: [DTO.CX24Homepage.Category]
        let race: DTO.CX24Homepage.Race
    }

    private var firstRaceFromFirstSection: FirstRaceInfo? {
        guard
            let section = races.sections.first,
            let race = section.races.first
        else {
            return nil
        }
        return .init(
            title: race.title,
            countryFlagURL: race.countryFlagURL,
            date: race.date,
            location: race.location,
            categories: race.categories,
            race: race
        )
    }

    private struct CategoryResultsView: View {
        let category: DTO.CX24Homepage.Category
        let openPodium: (DTO.CX24Homepage.Podium) -> Void

        var body: some View {
            let podiums = Array(category.podium.prefix(3))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TribuneruText(
                        content: category.title.uppercased(),
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary)
                    )

                    Spacer(minLength: 0)
                }

                HStack(alignment: .top, spacing: 12) {
                    CachedImageView(
                        imageUrl: category.winnerImageURL,
                        cornerRadius: 0
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())

                    VStack(spacing: 0) {
                        ForEach(podiums.indices, id: \.self) { idx in
                            let podium = podiums[idx]
                            // A button wins over the card's own tap gesture, so only the row opens the rider.
                            Button {
                                openPodium(podium)
                            } label: {
                                PodiumRow(podium: podium)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if idx < podiums.count - 1 {
                                TribunerosDivider(height: 0.5, color: .tribuneru(.vaporTextSecondary).opacity(0.2))
                            }
                        }
                    }
                }
            }
        }
    }

    private struct PodiumRow: View {
        let podium: DTO.CX24Homepage.Podium

        var body: some View {
            HStack(spacing: 10) {
                TribuneruText(
                    content: "\(podium.position)",
                    style: .vaporFinishTime,
                    color: .tribuneru(.vaporTextSecondary)
                )
                .frame(width: 18, alignment: .leading)

                VaporFlagView(url: podium.countryFlagURL)

                TribuneruText(
                    content: podium.rider,
                    style: .vaporRaceNameResult,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )

                Spacer(minLength: 0)

                TribuneruText(
                    content: podium.time,
                    style: .vaporFinishTime,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
            }
            .padding(.vertical, 6)
        }
    }
}
