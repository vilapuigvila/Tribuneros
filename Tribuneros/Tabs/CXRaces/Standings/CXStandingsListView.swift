//
//  CXStandingsListView.swift
//  Tribuneros
//
//  Created by albert vila on 9/1/26.
//

import SwiftUI

struct CXStandingsListView: View {
    let standings: DTO.CXStandings

    var body: some View {
        List {
            if standings.items.isEmpty {
                TribuneruText(
                    content: "No standings found.",
                    style: .size14WeightRegular,
                    color: .gray,
                    lineLimit: 2
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.tribuneru(.greenCardBackground))
                .cornerRadius(8)
                .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            } else {
                ForEach(standings.items, id: \.self) { item in
                    StandingsItemView(item: item)
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.black)
        .preferredColorScheme(.dark)
    }
}

struct CyclocrossStandingsCardView: View {
    let item: DTO.CXStandings.Item
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StandingsLogoView(logoURL: item.logoURL)
                    .frame(width: 24, height: 24)

                TribuneruText(
                    content: item.title,
                    style: .size16WeightSemiBold,
                    lineLimit: 2
                )
                Spacer(minLength: 0)
            }

            if let firstCategory = item.categories.first {
                EmptyView()
                StandingsCategorySummaryView(category: firstCategory)
            } else {
                TribuneruText(
                    content: "No categories found.",
                    style: .size12WeightRegular,
                    color: .gray,
                    lineLimit: 2
                )
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                TribuneruText(
                    content: "more info..",
                    style: .size12WeightRegular,
                    color: .cyan,
                    lineLimit: 1
                )
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.cyan)
            }
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color.tribuneru(.greenCardBackground))
        .cornerRadius(8)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - UCI Ranking Cx ... -
private struct StandingsItemView: View {
    let item: DTO.CXStandings.Item
    @State private var selectedCategoryIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                StandingsLogoView(logoURL: item.logoURL)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: item.title,
                        style: .size16WeightSemiBold,
                        lineLimit: 1
                    )
                    .truncationMode(.tail)

                    TribuneruText(
                        content: item.categories.isEmpty ? "No categories" : "\(item.categories.count) categories",
                        style: .size12WeightRegular,
                        color: .gray
                    )
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                if let url = item.url {
                    NavigationLink(destination: SafariView(url: url)) {
                        EmptyView()
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                }
            }

            if item.categories.isEmpty {
                TribuneruText(
                    content: "No categories found for this standings item.",
                    style: .size14WeightRegular,
                    color: .gray,
                    lineLimit: 2
                )
            } else {
                StandingsTabbedLeadersView(
                    categories: item.categories,
                    selectedCategoryIndex: $selectedCategoryIndex
                )
            }
        }
        .padding(12)
        .background(Color.tribuneru(.greenCardBackground))
        .cornerRadius(8)
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
                    .foregroundColor(.gray)
                    .padding(4)
            }
        }
        .background(Color.black.opacity(0.25))
        .cornerRadius(6)
    }
}

private struct StandingsLeaderRowView: View {
    let leader: DTO.CXStandings.Leader

    var body: some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: "\(leader.position)",
                style: .size12WeightRegular,
                color: .gray
            )
            .frame(width: 18, alignment: .leading)

            CachedImageView(imageUrl: leader.countryFlagURL, cornerRadius: 1)
                .frame(width: 16, height: 16)

            TribuneruText(
                content: leader.rider,
                style: .size12WeightRegular,
                lineLimit: 1
            )

            Spacer(minLength: 0)

            TribuneruText(
                content: leader.points,
                style: .size12WeightRegular,
                color: .gray,
                lineLimit: 1
            )
        }
        .padding(.vertical, 6)
    }
}

private struct StandingsTabbedLeadersView: View {
    let categories: [DTO.CXStandings.Category]
    @Binding var selectedCategoryIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StandingsTabsView(
                categories: categories,
                selectedCategoryIndex: $selectedCategoryIndex
            )

            if let selectedCategory {
                StandingsLeadersTableView(category: selectedCategory)
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
        static let cornerRadius: CGFloat = 2
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
                            content: category.title.uppercased(),
                            style: .size14WeightSemiBold,
                            color: .white,
                            lineLimit: 1
                        )
                        .padding(.vertical, UI.paddingV)
                        .padding(.horizontal, UI.paddingH)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected(idx)
                            ?
                            Color.tribuneru(.greenSoft) : Color.tribuneru(.gray).opacity(0.15)
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

    var body: some View {
        VStack(spacing: 0) {
            ForEach(category.leaders.indices, id: \.self) { idx in
                let leader = category.leaders[idx]
                StandingsLeaderTableRowView(leader: leader)

                if idx < category.leaders.count - 1 {
                    TribunerosDivider()
                }
            }
        }
        .background(Color.tribuneru(.greenCardBackground))
        .cornerRadius(2)
    }
}

private struct StandingsLeaderTableRowView: View {
    let leader: DTO.CXStandings.Leader

    var body: some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: "\(leader.position)",
                style: .size12WeightRegular,
                color: .white.opacity(0.9)
            )
                .frame(width: 18, alignment: .leading)

            CachedImageView(
                imageUrl: leader.countryFlagURL,
                cornerRadius: 1
            )
            .frame(width: 18, height: 18)

            TribuneruText(
                content: leader.rider,
                style: .size12WeightRegular,
                color: .white,
                lineLimit: 1
            )

            Spacer(minLength: 0)

            TribuneruText(
                content: leader.points,
                style: .size12WeightRegular,
                color: .white.opacity(0.85),
                lineLimit: 1
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

private struct StandingsCategorySummaryView: View {
    let category: DTO.CXStandings.Category

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TribuneruText(
                content: category.title.uppercased(),
                style: .size12WeightRegular,
                color: .gray
            )

            let leaders = Array(category.leaders.prefix(3))
            ForEach(leaders, id: \.self) { leader in
                StandingsLeaderRowView(leader: leader)
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
        .background(.black)
        .preferredColorScheme(.dark)
}

#endif
