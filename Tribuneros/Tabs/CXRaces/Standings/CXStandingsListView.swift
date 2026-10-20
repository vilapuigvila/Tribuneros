//
//  CXStandingsListView.swift
//  Tribuneros
//
//  Created by albert vila on 9/1/26.
//

import SwiftUI

struct CXStandingsListView: View {
    let standings: DTO.CXStandings
    var openRider: (CXRaces.RiderStanding) -> Void = { _ in }
    @State private var searchText = ""

    var body: some View {
        let filtered = CXRaces.standings(
            standings,
            matching: searchText
        )
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if filtered.items.isEmpty {
                    TribuneruText(
                        content: standings.items.isEmpty
                            ? L10n.tr("No standings found.")
                            : L10n.tr("No riders or standings match “%@”.", searchText),
                        style: .vaporMeta,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 2
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .mudCard()
                } else {
                    // Keyed by title, so filtering doesn't reset a card's selected category tab.
                    ForEach(filtered.items, id: \.title) { item in
                        StandingsItemView(
                            item: item,
                            openRider: openRider
                        )
                    }
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.mudPageBackground))
        .preferredColorScheme(.dark)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.tr("Rider, ranking, category...")
        )
    }
}

// MARK: - UCI Ranking Cx ... -
private struct StandingsItemView: View {
    let item: DTO.CXStandings.Item
    let openRider: (CXRaces.RiderStanding) -> Void
    @State private var selectedCategoryIndex: Int = 0
    @State private var webPage: WebPage?

    var body: some View {
        MudCardBox(spacing: 10) {
            HStack(spacing: 10) {
                StandingsLogoView(logoURL: item.logoURL)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: item.title,
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.mudTextPrimary),
                        lineLimit: 1
                    )
                    .truncationMode(.tail)

                    TribuneruText(
                        content: item.categories.isEmpty ? L10n.tr("No categories") : L10n.tr("%lld categories", item.categories.count),
                        style: .vaporMeta,
                        color: .tribuneru(.mudTextSecondary)
                    )
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                if let url = item.url {
                    Button {
                        webPage = WebPage(url: url)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.tribuneru(.mudTextSecondary))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)

            if item.categories.isEmpty {
                TribuneruText(
                    content: L10n.tr("No categories found for this standings item."),
                    style: .vaporMeta,
                    color: .tribuneru(.mudTextSecondary),
                    lineLimit: 2
                )
                .padding(.bottom, 6)
            } else {
                StandingsTabbedLeadersView(
                    categories: item.categories,
                    selectedCategoryIndex: $selectedCategoryIndex
                ) { leader, category in
                    openRider(
                        CXRaces.RiderStanding(
                            leader: leader,
                            category: category,
                            item: item
                        )
                    )
                }
            }
        }
        .webPage($webPage)
    }
}

private struct StandingsLogoView: View {
    let logoURL: URL?

    var body: some View {
        ZStack {
            if logoURL != nil {
                CachedImageView(imageUrl: logoURL, cornerRadius: 1)
            } else {
                Image(systemName: "trophy")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.tribuneru(.mudTextSecondary))
                    .padding(4)
            }
        }
        .background(Color.tribuneru(.mudPageBackground).opacity(0.6))
        .cornerRadius(6)
    }
}

private struct StandingsTabbedLeadersView: View {
    let categories: [DTO.CXStandings.Category]
    @Binding var selectedCategoryIndex: Int
    let openLeader: (DTO.CXStandings.Leader, DTO.CXStandings.Category) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StandingsTabsView(
                categories: categories,
                selectedCategoryIndex: $selectedCategoryIndex
            )

            if let selectedCategory {
                StandingsLeadersTableView(category: selectedCategory) { leader in
                    openLeader(
                        leader,
                        selectedCategory
                    )
                }
            }
        }
        .onAppear {
            clampSelectedCategoryIndex()
        }
        .onChange(of: categories) {
            clampSelectedCategoryIndex()
        }
    }

    private var selectedCategory: DTO.CXStandings.Category? {
        guard !categories.isEmpty else { return nil }
        let idx = min(max(selectedCategoryIndex, 0), categories.count - 1)
        return categories[idx]
    }

    private func clampSelectedCategoryIndex() {
        guard !categories.isEmpty else {
            selectedCategoryIndex = 0
            return
        }
        selectedCategoryIndex = min(max(selectedCategoryIndex, 0), categories.count - 1)
    }
}

private struct StandingsTabsView: View {
    let categories: [DTO.CXStandings.Category]
    @Binding var selectedCategoryIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories.indices, id: \.self) { idx in
                    let selected = selectedCategoryIndex == idx
                    Button {
                        selectedCategoryIndex = idx
                    } label: {
                        TribuneruText(
                            content: categories[idx].title.uppercased(with: L10n.locale),
                            style: .vaporSpoilerChip,
                            color: selected ? .tribuneru(.mudAccent) : .tribuneru(.mudTextPrimary),
                            lineLimit: 1
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(
                                selected
                                    ? Color.tribuneru(.mudAccent).opacity(0.14)
                                    : Color.tribuneru(.mudPageBackground)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                selected
                                    ? Color.tribuneru(.mudAccent).opacity(0.4)
                                    : Color.tribuneru(.mudTextPrimary).opacity(0.08),
                                lineWidth: 1
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct StandingsLeadersTableView: View {
    let category: DTO.CXStandings.Category
    let openLeader: (DTO.CXStandings.Leader) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(category.leaders.indices, id: \.self) { idx in
                let leader = category.leaders[idx]
                Button {
                    openLeader(leader)
                } label: {
                    StandingsLeaderTableRowView(leader: leader)
                }
                .buttonStyle(.plain)

                if idx < category.leaders.count - 1 {
                    MudDivider()
                }
            }
        }
    }
}

private struct StandingsLeaderTableRowView: View {
    let leader: DTO.CXStandings.Leader

    var body: some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: "\(leader.position)",
                style: .vaporFinishTime,
                color: .tribuneru(.mudTextSecondary)
            )
            .frame(width: 18, alignment: .leading)

            VaporFlagView(url: leader.countryFlagURL)

            TribuneruText(
                content: leader.rider,
                style: .vaporRaceNameResult,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 1
            )

            Spacer(minLength: 0)

            TribuneruText(
                content: leader.points,
                style: .vaporFinishTime,
                color: .tribuneru(.mudTextSecondary),
                lineLimit: 1
            )

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.tribuneru(.mudTextSecondary))
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

#if DEBUG

#Preview("CX Standings list") {
    NavigationStack {
        CXStandingsListView(standings: CXRaces.Representable.mock.standings)
            .navigationTitle("Standings")
    }
}

#endif
