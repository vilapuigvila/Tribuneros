//
//  RaceFinishedDetailView.swift
//  Tribuneros
//
//  Created by Claude on 30/9/26.
//

import SwiftUI

struct RaceFinishedDetailView: View {
    let raceFinished: HomeRaces.Representable.RaceFinished
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var webPage: WebPage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Race Header
                    VStack(alignment: .leading, spacing: 8) {
                        TribuneruText(
                            content: raceFinished.race,
                            style: .vaporHeading,
                            color: .tribuneru(.vaporTextPrimary)
                        )

                        TribuneruText(
                            content: raceFinished.raceDetails,
                            style: .vaporBodySmall,
                            color: .tribuneru(.vaporTextSecondary)
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    Divider()
                        .padding(.horizontal, 16)

                    // Winner Image
                    if let imageURL = raceFinished.winnerImgURL {
                        CachedImageView(
                            imageUrl: imageURL,
                            cornerRadius: 12
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .padding(.horizontal, 16)
                    }

                    // Cancel Status
                    if raceFinished.isCancel {
                        VStack(alignment: .leading, spacing: 8) {
                            TribuneruText(
                                content: "Race Cancelled",
                                style: .vaporBodyBold,
                                color: .tribuneru(.vaporLiveRed)
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                    } else if !raceFinished.podium.isEmpty {
                        // Podium Section
                        VStack(alignment: .leading, spacing: 12) {
                            TribuneruText(
                                content: "Podium",
                                style: .vaporSubheading,
                                color: .tribuneru(.vaporTextPrimary)
                            )

                            VStack(spacing: 12) {
                                ForEach(raceFinished.podium, id: \.id) { winner in
                                    PodiumRowView(winner: winner)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)

                        // View Full Results Button
                        Button(action: openFullResults) {
                            HStack(spacing: 8) {
                                TribuneruText(
                                    content: "View Full Results",
                                    style: .vaporBodyBold,
                                    color: .tribuneru(.vaporTextOnAccent)
                                )
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.tribuneru(.vaporTextOnAccent))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.tribuneru(.vaporAccent))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                    }

                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Race Result")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.tribuneru(.vaporBackground))
            .overlay(alignment: .center) {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil), presenting: errorMessage) { _ in
                Button("OK") { errorMessage = nil }
            } message: { error in
                Text(error)
            }
            .webPage($webPage)
        }
    }

    private func openFullResults() {
        guard let url = raceFinished.raceURL else {
            errorMessage = "Race URL not available"
            return
        }
        webPage = WebPage(url: url)
    }
}

struct PodiumRowView: View {
    let winner: HomeRaces.Representable.RaceFinished.Winner

    var body: some View {
        HStack(spacing: 12) {
            // Position Badge
            VStack(alignment: .center) {
                TribuneruText(
                    content: winner.position,
                    style: .vaporBodyBold,
                    color: .tribuneru(.vaporTextPrimary)
                )
            }
            .frame(width: 40)
            .padding(.vertical, 8)
            .background(Color.tribuneru(.vaporCardBackground))
            .cornerRadius(8)

            // Flag
            if let flagURL = winner.flag {
                CachedImageView(
                    imageUrl: flagURL,
                    cornerRadius: 4
                )
                .frame(width: 24, height: 16)
            } else {
                VStack {
                    Text(winner.countryCode)
                        .font(.caption2)
                        .foregroundColor(.tribuneru(.vaporTextSecondary))
                }
                .frame(width: 24, height: 16)
            }

            // Rider Info
            VStack(alignment: .leading, spacing: 4) {
                TribuneruText(
                    content: winner.name,
                    style: .vaporBodyBold,
                    color: .tribuneru(.vaporTextPrimary)
                )

                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: winner.team,
                        style: .vaporBodySmall,
                        color: .tribuneru(.vaporTextSecondary)
                    )

                    if !winner.time.isEmpty {
                        TribuneruText(
                            content: winner.time,
                            style: .vaporBodySmall,
                            color: .tribuneru(.vaporTextTertiary)
                        )
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.tribuneru(.vaporCardBackground))
        .cornerRadius(8)
    }
}

#Preview {
    let mockWinner = HomeRaces.Representable.RaceFinished.Winner(
        id: UUID(),
        position: "1",
        flag: URL(string: "https://www.procyclingstats.com/img/flags/it.png"),
        countryCode: "ITA",
        name: "Juan Ayuso",
        team: "UAE Team Emirates",
        time: "3h 24' 12\""
    )

    let mockRace = HomeRaces.Representable.RaceFinished(
        id: UUID(),
        race: "Giro d'Italia",
        raceDetails: "Stage 5 - 156 km",
        winnerImgURL: URL(string: "https://www.procyclingstats.com/img/rider/default.jpg"),
        podium: [mockWinner],
        isCancel: false,
        raceURL: URL(string: "https://www.procyclingstats.com/race/giro-d-italia")
    )

    RaceFinishedDetailView(raceFinished: mockRace)
}
