//
//  LatestAllResultsView.swift
//  Tribuneros
//
//  Created by albert vila on 7/1/26.
//

import SwiftUI

struct LatestAllResultsView: View {
    let races: DTO.CX24Homepage
    /// Races flipped from the default this launch (revealed while results are hidden, hidden otherwise), shared with the CX Zone card.
    @Binding var flippedRaces: Set<String>
    /// A category block opens the race on that category; the rest of a race card opens it via `action`.
    var openCategory: (DTO.CX24Homepage.Race, String) -> Void = { _, _ in }
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
                                    visibility: CXRaces.resultVisibility(
                                        of: race,
                                        flipped: flippedRaces
                                    ),
                                    openCategory: openCategory
                                )
                                .resultGestures(
                                    CXRaces.resultVisibility(
                                        of: race,
                                        flipped: flippedRaces
                                    ),
                                    open: { action(race) },
                                    toggle: { CXRaces.flip(race, in: &flippedRaces) }
                                )
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
    let visibility: HomeRaces.ResultVisibility
    let openCategory: (DTO.CX24Homepage.Race, String) -> Void

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

            let shownRace = visibility == .shown ? race : race.hiddenStandIn
            VStack(spacing: 12) {
                ForEach(CXRaces.cardCategories(of: shownRace).indices, id: \.self) { idx in
                    let category = shownRace.categories[idx]
                    // A button wins over the card's own tap gesture, so it only takes touches while shown.
                    Button {
                        openCategory(race, category.title)
                    } label: {
                        CategoryResultsView(
                            category: category,
                            isHidden: visibility != .shown,
                            reservesPhoto: race.categories[idx].winnerImageURL != nil
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(visibility == .shown)
                }
            }
            .spoilerCrossfade(visibility)
            .padding(.bottom, 6)
        }
    }
}

extension DTO.CX24Homepage.Race {
    /// Built from stand-in values, so no real podium or photo reaches the view tree.
    fileprivate var hiddenStandIn: Self {
        let podium = (1...3).map {
            DTO.CX24Homepage.Podium(
                position: $0,
                rider: "Rider name",
                riderURL: nil,
                country: "",
                countryFlagURL: nil,
                time: "0:00:00"
            )
        }
        return Self(
            title: title,
            country: country,
            countryFlagURL: countryFlagURL,
            date: date,
            location: location,
            raceURL: nil,
            categories: categories.map {
                .init(
                    title: $0.title,
                    categoryURL: nil,
                    winnerImageURL: nil,
                    podium: podium
                )
            }
        )
    }
}

private struct CategoryResultsView: View {
    let category: DTO.CX24Homepage.Category
    let isHidden: Bool
    var reservesPhoto = false

    var body: some View {
        let podiums = Array(category.podium.prefix(3))
        VStack(alignment: .leading, spacing: 4) {
            TribuneruText(
                content: category.title.uppercased(with: L10n.locale),
                style: .vaporGroupLabel,
                color: .tribuneru(.mudTextSecondary)
            )

            HStack(alignment: .center, spacing: 12) {
                if category.winnerImageURL != nil || reservesPhoto {
                    WinnerAvatar(
                        imageURL: category.winnerImageURL,
                        name: isHidden ? nil : category.podium.first?.rider,
                        isHidden: isHidden
                    )
                }

                VStack(spacing: 0) {
                    ForEach(podiums.indices, id: \.self) { idx in
                        let podium = podiums[idx]
                        PodiumRow(podium: podium)

                        if idx < podiums.count - 1 {
                            MudDivider()
                        }
                    }
                }
                .redacted(reason: isHidden ? .placeholder : [])
                .accessibilityHidden(isHidden)
            }
        }
    }
}

/// 56pt winner photo; the Leaders-style initials disc shows while loading and when the photo fails.
private struct WinnerAvatar: View {
    let imageURL: URL?
    let name: String?
    let isHidden: Bool

    var body: some View {
        ZStack {
            initialsDisc
            if !isHidden {
                photo
            }
            RaceArtView(art: .spoiler)
                .opacity(isHidden ? 1 : 0)
                .animation(
                    isHidden ? nil : .easeInOut(duration: SpoilerHold.revealDuration),
                    value: isHidden
                )
                .accessibilityElement()
                .accessibilityLabel(L10n.tr("Result hidden"))
                .accessibilityHidden(!isHidden)
                .accessibilityIdentifier("cx.latestList.spoiler")
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.tribuneru(.mudAccent), lineWidth: 2))
    }

    private var photo: some View {
        ZStack {
            CachedImageView(
                imageUrl: imageURL,
                cornerRadius: 0,
                presentation: .racePhoto,
                fallback: AnyView(initialsDisc)
            )
        }
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
        LatestAllResultsView(
            races: CXRaces.Representable.mock.races,
            flippedRaces: .constant([])
        ) { _ in
        }
        .navigationTitle("Latest results")
    }
}

#endif
