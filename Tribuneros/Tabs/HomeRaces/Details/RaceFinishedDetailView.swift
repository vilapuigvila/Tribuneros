//
//  RaceFinishedDetailView.swift
//  Tribuneros
//
//  A native SwiftUI view for displaying race result details using Vapor design tokens.
//  Displays race title, winner information with photo, and full podium results.
//

import SwiftUI

/// A detailed view for displaying race results with Vapor design system styling.
///
/// This view shows:
/// - Race title and additional details
/// - Winner image
/// - Complete podium with positions, rider names, times, and country flags
///
/// Styling uses Vapor design tokens throughout.
struct RaceFinishedDetailView: View {
    /// The race result data
    let raceFinished: HomeRaces.Representable.RaceFinished

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header section with title and details
                headerSection

                // Divider
                Divider()
                    .padding(.horizontal, 16)

                // Winner image and podium
                if !raceFinished.podium.isEmpty {
                    contentSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .navigationTitle("Race Result")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: raceFinished.race,
                style: .vaporHeading,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 3
            )

            if !raceFinished.raceDetails.isEmpty {
                TribuneruText(
                    content: raceFinished.raceDetails,
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Winner image
            if let imageURL = raceFinished.winnerImgURL {
                CachedImageView(
                    imageUrl: imageURL,
                    cornerRadius: 12
                )
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .padding(16)
            }

            // Podium rows
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(raceFinished.podium.enumerated()), id: \.element.id) { index, winner in
                    podiumRow(winner)
                    if index < raceFinished.podium.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Podium Row

    private func podiumRow(_ winner: HomeRaces.Representable.RaceFinished.Winner) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Position
            VStack(alignment: .center) {
                TribuneruText(
                    content: winner.position,
                    style: .vaporRowTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
            }
            .frame(width: 32)

            // Flag and name
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    TribuneruText(
                        content: winner.name,
                        style: .vaporRowTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )

                    if let flagURL = winner.flag {
                        CachedImageView(
                            imageUrl: flagURL,
                            cornerRadius: 2
                        )
                        .frame(width: 20, height: 14)
                    }
                }

                TribuneruText(
                    content: winner.team,
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Time
            if !winner.time.isEmpty {
                TribuneruText(
                    content: winner.time,
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextMuted),
                    lineLimit: 1
                )
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let mockPodium: [HomeRaces.Representable.RaceFinished.Winner] = [
        HomeRaces.Representable.RaceFinished.Winner(
            position: "1",
            flag: URL(string: "https://flagcdn.com/w40/be.png"),
            countryCode: "BE",
            name: "Remco Evenepoel",
            team: "Soudal QuickStep",
            time: "6:28:35"
        ),
        HomeRaces.Representable.RaceFinished.Winner(
            position: "2",
            flag: URL(string: "https://flagcdn.com/w40/nl.png"),
            countryCode: "NL",
            name: "Mathieu van der Poel",
            team: "Alpecin-Deceuninck",
            time: "+00:34"
        ),
        HomeRaces.Representable.RaceFinished.Winner(
            position: "3",
            flag: URL(string: "https://flagcdn.com/w40/it.png"),
            countryCode: "IT",
            name: "Filippo Ganna",
            team: "Ineos Grenadiers",
            time: "+00:45"
        )
    ]

    let mockRace = HomeRaces.Representable.RaceFinished(
        race: "Tour of Flanders",
        raceDetails: "Elite Men | Belgium | 265.8 km",
        winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/remco-evenepoel-2025.jpg"),
        podium: mockPodium,
        isCancel: false,
        raceURL: URL(string: "https://www.procyclingstats.com/race/tour-of-flanders")
    )

    NavigationStack {
        RaceFinishedDetailView(raceFinished: mockRace)
    }
}
