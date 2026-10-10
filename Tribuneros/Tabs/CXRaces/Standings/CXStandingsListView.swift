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
        List {
            if filtered.items.isEmpty {
                TribuneruText(
                    content: standings.items.isEmpty
                        ? L10n.tr("No standings found.")
                        : L10n.tr("No riders or standings match “%@”.", searchText),
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.tribuneru(.vaporCardSurface))
                .cornerRadius(8)
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } else {
                // Keyed by title, so filtering doesn't reset a card's selected category tab.
                ForEach(filtered.items, id: \.title) { item in
                    StandingsItemView(
                        item: item,
                        openRider: openRider
                    )
                    .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.tr("Rider, ranking, category...")
        )
    }
}

struct CyclocrossStandingsCardView: View {
    let item: DTO.CXStandings.Item
    var openRider: (CXRaces.RiderStanding) -> Void = { _ in }
    let onTap: () -> Void

    var body: some View {
        VaporCard {
            HStack(spacing: 10) {
                StandingsLogoView(logoURL: item.logoURL)
                    .frame(width: 24, height: 24)

                TribuneruText(
                    content: item.title,
                    style: .vaporRaceNameNext,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
                Spacer(minLength: 0)
            }

            if let firstCategory = item.categories.first {
                StandingsCategorySummaryView(category: firstCategory) { leader in
                    openRider(
                        CXRaces.RiderStanding(
                            leader: leader,
                            category: firstCategory,
                            item: item
                        )
                    )
                }
            } else {
                TribuneruText(
                    content: L10n.tr("No categories found."),
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }

            VaporMoreInfoLink()
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - UCI Ranking Cx ... -
private struct StandingsItemView: View {
    let item: DTO.CXStandings.Item
    let openRider: (CXRaces.RiderStanding) -> Void
    @State private var selectedCategoryIndex: Int = 0
    @State private var webPage: WebPage?

    var body: some View {
        VaporCard {
            HStack(spacing: 10) {
                StandingsLogoView(logoURL: item.logoURL)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: item.title,
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    .truncationMode(.tail)

                    TribuneruText(
                        content: item.categories.isEmpty ? L10n.tr("No categories") : L10n.tr("%lld categories", item.categories.count),
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary)
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
                            .foregroundColor(.tribuneru(.vaporTextSecondary))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if item.categories.isEmpty {
                TribuneruText(
                    content: L10n.tr("No categories found for this standings item."),
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
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
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                    .padding(4)
            }
        }
        .background(Color.tribuneru(.vaporPageBackground).opacity(0.6))
        .cornerRadius(6)
    }
}

private struct StandingsLeaderRowView: View {
    let leader: DTO.CXStandings.Leader

    var body: some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: "\(leader.position)",
                style: .vaporFinishTime,
                color: .tribuneru(.vaporTextSecondary)
            )
            .frame(width: 18, alignment: .leading)

            VaporFlagView(url: leader.countryFlagURL)

            TribuneruText(
                content: leader.rider,
                style: .vaporRaceNameResult,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )

            Spacer(minLength: 0)

            TribuneruText(
                content: leader.points,
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

private struct StandingsTabbedLeadersView: View {
    let categories: [DTO.CXStandings.Category]
    @Binding var selectedCategoryIndex: Int
    let openLeader: (DTO.CXStandings.Leader, DTO.CXStandings.Category) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
    private enum UI {
        static let paddingV: CGFloat = 10
        static let paddingH: CGFloat = 12
        static let spacing: CGFloat = 8
        static let cornerRadius: CGFloat = 6
    }

    let categories: [DTO.CXStandings.Category]
    @Binding var selectedCategoryIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: UI.spacing) {
                ForEach(categories.indices, id: \.self) { idx in
                    let category = categories[idx]
                    Button {
                        selectedCategoryIndex = idx
                    } label: {
                        TribuneruText(
                            content: category.title.uppercased(with: L10n.locale),
                            style: .vaporSpoilerChip,
                            color: isSelected(idx) ? .tribuneru(.vaporAccent) : .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                        .padding(.vertical, UI.paddingV)
                        .padding(.horizontal, UI.paddingH)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected(idx)
                            ? Color.tribuneru(.vaporAccent).opacity(0.16) : Color.tribuneru(.vaporTextSecondary).opacity(0.12)
                        )
                        .cornerRadius(UI.cornerRadius)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, UI.spacing)
        }
    }

    private func isSelected(_ idx: Int) -> Bool {
        selectedCategoryIndex == idx
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
                    TribunerosDivider(height: 0.5, color: .tribuneru(.vaporTextSecondary).opacity(0.2))
                }
            }
        }
        .padding(.horizontal, 4)
        .background(Color.tribuneru(.vaporCardSurface))
        .cornerRadius(6)
    }
}

private struct StandingsLeaderTableRowView: View {
    let leader: DTO.CXStandings.Leader

    var body: some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: "\(leader.position)",
                style: .vaporFinishTime,
                color: .tribuneru(.vaporTextSecondary)
            )
                .frame(width: 18, alignment: .leading)

            VaporFlagView(url: leader.countryFlagURL)

            TribuneruText(
                content: leader.rider,
                style: .vaporRaceNameResult,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )

            Spacer(minLength: 0)

            TribuneruText(
                content: leader.points,
                style: .vaporFinishTime,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporTextSecondary))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }
}

private struct StandingsCategorySummaryView: View {
    let category: DTO.CXStandings.Category
    let openLeader: (DTO.CXStandings.Leader) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TribuneruText(
                content: category.title.uppercased(with: L10n.locale),
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary)
            )

            let leaders = Array(category.leaders.prefix(3))
            ForEach(leaders, id: \.self) { leader in
                // A button wins over the card's own tap gesture, so only the row opens the rider.
                Button {
                    openLeader(leader)
                } label: {
                    StandingsLeaderRowView(leader: leader)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#if DEBUG

#Preview("CX Standings list") {
    NavigationStack {
        CXStandingsListView(standings: CXRaces.Representable.mock.standings)
            .navigationTitle("Standings")
    }
}

#Preview("CX Standings card") {
    CyclocrossStandingsCardView(item: CXRaces.Representable.mock.standings.items[0]) { }
        .padding()
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
}

#endif
