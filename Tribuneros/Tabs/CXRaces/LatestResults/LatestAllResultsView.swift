//
//  LatestAllResultsView.swift
//  Tribuneros
//
//  Created by albert vila on 7/1/26.
//

import SwiftUI

struct LatestAllResultsView: View {
    let races: DTO.CX24Homepage
    /// A podium row opens the rider screen; the rest of a race card opens the race (`action`).
    var openRider: (CXRaces.RiderPodium) -> Void = { _ in }
    let action: (DTO.CX24Homepage.Race) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                ForEach(races.sections.indices, id: \.self) { sectionIndex in
                    let section = races.sections[sectionIndex]
                    MudPanel(title: section.title) {
                        VStack(spacing: 12) {
                            ForEach(section.races.indices, id: \.self) { raceIndex in
                                let race = section.races[raceIndex]
                                RaceRowView(
                                    race: race,
                                    openRider: openRider
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    action(race)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.mudPageBackground))
        .preferredColorScheme(.dark)
    }
}

private struct RaceRowView: View {
    let race: DTO.CX24Homepage.Race
    let openRider: (CXRaces.RiderPodium) -> Void

    var body: some View {
        MudCardBox(spacing: 12) {
            HStack(spacing: 10) {
                VaporFlagView(url: race.countryFlagURL)

                TribuneruText(
                    content: race.title,
                    style: .vaporRaceNameNext,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 2
                )

                Spacer(minLength: 0)
            }
            .padding(.top, 6)

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.tribuneru(.mudTextSecondary))
                    TribuneruText(
                        content: race.date,
                        style: .vaporMeta,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.tribuneru(.mudTextSecondary))
                    TribuneruText(
                        content: race.location,
                        style: .vaporMeta,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 12) {
                ForEach(race.categories.prefix(2).indices, id: \.self) { idx in
                    let category = race.categories[idx]
                    CategoryResultsView(category: category) { podium in
                        openRider(
                            CXRaces.RiderPodium(
                                podium: podium,
                                category: category,
                                race: race
                            )
                        )
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }
}

private struct CategoryResultsView: View {
    let category: DTO.CX24Homepage.Category
    let openPodium: (DTO.CX24Homepage.Podium) -> Void

    var body: some View {
        let podiums = Array(category.podium.prefix(3))
        VStack(alignment: .leading, spacing: 4) {
            TribuneruText(
                content: category.title.uppercased(with: L10n.locale),
                style: .vaporGroupLabel,
                color: .tribuneru(.mudTextSecondary)
            )

            HStack(alignment: .center, spacing: 12) {
                if let imageURL = category.winnerImageURL {
                    WinnerAvatar(
                        imageURL: imageURL,
                        name: category.podium.first?.rider
                    )
                }

                VStack(spacing: 0) {
                    ForEach(podiums.indices, id: \.self) { idx in
                        let podium = podiums[idx]
                        // A button wins over the row's own tap gesture, so only the podium opens the rider.
                        Button {
                            openPodium(podium)
                        } label: {
                            PodiumRow(podium: podium)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if idx < podiums.count - 1 {
                            MudDivider()
                        }
                    }
                }
            }
        }
    }
}

/// 56pt winner photo; the Leaders-style initials disc shows while loading and when the photo fails.
private struct WinnerAvatar: View {
    let imageURL: URL
    let name: String?

    var body: some View {
        ZStack {
            initialsDisc
            CachedImageView(
                imageUrl: imageURL,
                cornerRadius: 0,
                presentation: .racePhoto,
                fallback: AnyView(initialsDisc)
            )
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.tribuneru(.mudAccent), lineWidth: 2))
    }

    private var initialsDisc: some View {
        ZStack {
            Color.tribuneru(.mudTagNeutral)
            if let name {
                TribuneruText(
                    content: CXRaces.riderInitials(name),
                    style: .vaporResultTitle,
                    color: .tribuneru(.mudTagNeutralText)
                )
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
                color: .tribuneru(.mudTextSecondary)
            )
            .frame(width: 18, alignment: .leading)

            VaporFlagView(url: podium.countryFlagURL)

            TribuneruText(
                content: podium.rider,
                style: .vaporRaceNameResult,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 1
            )

            Spacer(minLength: 0)

            TribuneruText(
                content: podium.time,
                style: .vaporFinishTime,
                color: .tribuneru(.mudTextSecondary),
                lineLimit: 1
            )

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.tribuneru(.mudTextSecondary))
        }
        .padding(.vertical, 8)
    }
}

#if DEBUG

#Preview("Latest all results") {
    NavigationStack {
        LatestAllResultsView(races: CXRaces.Representable.mock.races) { _ in
            
        }
        .navigationTitle("Latest results")
    }
}

#endif
