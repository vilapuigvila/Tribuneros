//
//  RaceDetailView.swift
//  Tribuneros
//
//  Created by albert vila on 13/1/26.
//

import SwiftUI
import SwiftSoup

struct RaceDetailView: View {
    let race: DTO.CX24Homepage.Race
    @State private var categoryResults: [String: [DTO.CX24Homepage.CategoryResult]] = [:]
    @State private var selectedCategory: Int = 0
    @State private var expandedCategories: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    /// A results row opens the rider screen.
    private let openRider: (CXRaces.RiderResult) -> Void
    /// Hands the race video to the system (the YouTube app when installed).
    private let openVideo: (URL) -> Void
    
    init(
        race: DTO.CX24Homepage.Race,
        category: String? = nil,
        categoryResults: [String: [DTO.CX24Homepage.CategoryResult]] = [:],
        openVideo: @escaping (URL) -> Void = { _ in },
        openRider: @escaping (CXRaces.RiderResult) -> Void = { _ in }
    ) {
        self.race = race
        self.openRider = openRider
        self.openVideo = openVideo
        _categoryResults = State(initialValue: categoryResults)
        _selectedCategory = State(initialValue: CXRaces.categoryIndex(category, in: race))
        _isLoading = State(initialValue: categoryResults.isEmpty)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerView

                if isLoading {
                    VStack(alignment: .leading, spacing: 16) {
                        categoryTabsView
                        resultsList(DTO.CX24Homepage.CategoryResult.placeholders)
                    }
                    .redacted(reason: .placeholder)
                    .shimmering()
                    .disabled(true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.tr("Loading the results"))
                } else if let error = errorMessage {
                    TribuneruText(
                        content: error,
                        style: .vaporMeta,
                        color: .tribuneru(.mudNegative)
                    )
                    .padding()
                } else {
                    categoryTabsView
                    resultsList()
                }

                if !isLoading, let videoID = inlineVideoID {
                    CXInlineVideoPanel(
                        videoID: videoID,
                        openURL: openVideo
                    )
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.mudPageBackground))
        .preferredColorScheme(.dark)
        .task {
            if !categoryResults.isEmpty {
                return
            }
            isLoading = true
            errorMessage = nil
            do {
                categoryResults = try await Service.getCxRaceCategoryResults(race)
            } catch {
                errorMessage = L10n.tr("Couldn’t load the results. Check your connection and try again.")
            }
            isLoading = false
        }
    }

    private var headerView: some View {
        ZStack {
            CXMudArt()
            ImageScrim(
                top: 0.5,
                topEnd: 0.34,
                bottom: 0.8,
                bottomEnd: 0.46,
                tint: .tribuneru(.mudPageBackground)
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    VaporFlagView(url: race.countryFlagURL)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: race.title,
                        style: .vaporHeroTitle,
                        color: .tribuneru(.white(level: 1)),
                        lineLimit: 2
                    )
                    .artTitleShadow()
                    TribuneruText(
                        content: [race.date, race.location]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "),
                        style: .vaporHeroSubtitle,
                        color: Color.tribuneru(.mudTextPrimary).opacity(0.88),
                        lineLimit: 1
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            .padding(14)
        }
        .frame(height: 196)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    Color.tribuneru(.mudTextPrimary).opacity(0.08),
                    lineWidth: 1
                )
        )
    }

    private var categoryTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(race.categories.indices, id: \.self) { index in
                    let category = race.categories[index]
                    CategoryTabButton(
                        title: category.title.uppercased(with: L10n.locale),
                        isSelected: selectedCategory == index
                    ) {
                        selectedCategory = index
                    }
                }
            }
        }
    }

    private static let collapsedRowCount = 10

    /// The selected category's loaded results, or `placeholders` drawn in their place.
    private func resultsList(_ placeholders: [DTO.CX24Homepage.CategoryResult]? = nil) -> some View {
        MudCardBox {
            if selectedCategory < race.categories.count {
                let category = race.categories[selectedCategory]
                let allResults = placeholders ?? categoryResults[category.title] ?? []
                let canExpand = placeholders == nil
                    && allResults.count > Self.collapsedRowCount
                    && !expandedCategories.contains(category.title)
                let results = canExpand ? Array(allResults.prefix(Self.collapsedRowCount)) : allResults

                if results.isEmpty {
                    TribuneruText(
                        content: L10n.tr("No results available"),
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary)
                    )
                    .padding(.vertical, 12)
                } else {
                    resultsHeaderRow

                    ForEach(results.indices, id: \.self) { index in
                        Button {
                            openRider(
                                CXRaces.RiderResult(
                                    result: results[index],
                                    category: category.title,
                                    race: race
                                )
                            )
                        } label: {
                            ResultRow(result: results[index])
                                .frame(minHeight: 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < results.count - 1 {
                            MudDivider()
                        }
                    }

                    if canExpand {
                        Button {
                            expandedCategories.insert(category.title)
                        } label: {
                            MudMoreLink(title: L10n.tr("View all"))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("race-detail-view-all")
                    }
                }
            }
        }
    }

    private var resultsHeaderRow: some View {
        HStack(spacing: 0) {
            TribuneruText(
                content: "#",
                style: .vaporMeta,
                color: .tribuneru(.mudTextSecondary)
            )
            .frame(width: 24, alignment: .leading)

            TribuneruText(
                content: L10n.tr("Rider"),
                style: .vaporMeta,
                color: .tribuneru(.mudTextSecondary)
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            TribuneruText(
                content: L10n.tr("Team"),
                style: .vaporMeta,
                color: .tribuneru(.mudTextSecondary)
            )
            .frame(width: 96, alignment: .leading)

            TribuneruText(
                content: L10n.tr("Time"),
                style: .vaporMeta,
                color: .tribuneru(.mudTextSecondary)
            )
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.bottom, 4)
    }

    private var inlineVideoID: String? {
        categoryResults.values
            .lazy
            .compactMap { $0.first?.raceVideosURL }
            .compactMap(CXInlineVideoPanel.youTubeID(from:))
            .first
    }
}

private struct CategoryTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            TribuneruText(
                content: title,
                style: .vaporSpoilerChip,
                color: isSelected ? .tribuneru(.mudPageBackground) : .tribuneru(.mudTextSecondary)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Color.tribuneru(isSelected ? .mudAccent : .mudCardSurface),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(
                    Color.tribuneru(.mudTextPrimary).opacity(isSelected ? 0 : 0.08),
                    lineWidth: 1
                )
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ResultRow: View {
    let result: DTO.CX24Homepage.CategoryResult
    
    var body: some View {
        HStack(spacing: 0) {
            TribuneruText(
                content: result.position,
                style: .vaporFinishTime,
                color: .tribuneru(.mudTextPrimary)
            )
            .frame(width: 24, alignment: .leading)

            HStack(spacing: 6) {
                if let flagURL = result.countryFlagURL {
                    VaporFlagView(url: flagURL)
                }

                TribuneruText(
                    content: result.rider,
                    style: .vaporRaceNameResult,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 1
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TribuneruText(
                content: result.team,
                style: .vaporMeta,
                color: .tribuneru(.mudTextSecondary),
                lineLimit: 1
            )
            .frame(width: 96, alignment: .leading)

            TribuneruText(
                content: result.time,
                style: .vaporFinishTime,
                color: .tribuneru(.mudTextSecondary)
            )
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

#if DEBUG

#Preview("Race Detail") {
    let mockResults: [String: [DTO.CX24Homepage.CategoryResult]] = [
        "Men Elite": [
            .init(
                position: "1",
                rider: "Eli Iserbyt",
                age: "27",
                team: "Pauwels Sauzen",
                time: "1:00:12",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                raceVideosURL: URL(string: "https://www.youtube.com/watch?v=EShExWlESGs")
            ),
            .init(
                position: "2",
                rider: "Laurens Sweeck",
                age: "31",
                team: "Crelan-Corendon",
                time: "+0:15",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                raceVideosURL: URL(string: "https://www.youtube.com/watch?v=EShExWlESGs")
            ),
            .init(
                position: "3",
                rider: "Michael Vanthourenhout",
                age: "30",
                team: "Pauwels Sauzen",
                time: "+0:32",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                raceVideosURL: URL(string: "https://www.youtube.com/watch?v=EShExWlESGs")
            )
        ],
        "Women Elite": [
            .init(
                position: "1",
                rider: "Fem van Empel",
                age: "23",
                team: "Visma | Lease a Bike",
                time: "49:22",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                raceVideosURL: URL(string: "https://www.youtube.com/watch?v=EShExWlESGs")
            ),
            .init(
                position: "2",
                rider: "Lucinda Brand",
                age: "34",
                team: "Baloise Trek",
                time: "+0:12",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                raceVideosURL: URL(string: "https://www.youtube.com/watch?v=EShExWlESGs")
            ),
            .init(
                position: "3",
                rider: "Puck Pieterse",
                age: "22",
                team: "Fenix-Deceuninck",
                time: "+0:20",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                raceVideosURL: URL(string: "https://www.youtube.com/watch?v=EShExWlESGs")
            )
        ]
    ]

    NavigationStack {
        RaceDetailView(
            race: .init(
                title: "UCI World Cup Zonhoven (CDM)",
                country: "Belgium",
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")!,
                date: "4 January 2026",
                location: "Zonhoven, Belgium",
                raceURL: URL(string: "https://cyclocross24.com/race/otegem/"),
                categories: [
                    .init(
                        title: "Men Elite",
                        categoryURL: URL(string: "https://cyclocross24.com/race/18062/"),
                        winnerImageURL: nil,
                        podium: []
                    ),
                    .init(
                        title: "Women Elite",
                        categoryURL: URL(string: "https://cyclocross24.com/race/18063/"),
                        winnerImageURL: nil,
                        podium: []
                    )
                ]
            ),
            categoryResults: mockResults
        )
    }
}

#endif
