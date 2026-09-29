//
//  CXRiderDetailView.swift
//  Tribuneros
//
//  Created by albert vila on 29/9/26.
//

import SwiftUI

/// Native rider screen opened from a standings row or a latest-results podium row. The context
/// panel (the standing, or the podium result) comes from the Firestore documents; the photo,
/// profile facts and recent results from the rider's cyclocross24 page, parsed best-effort on the
/// device — each section hides when it comes back empty.
struct CXRiderDetailView: View {
    let context: CXRaces.RiderContext
    let openURL: (URL) -> Void
    /// Opens the podium's race results (`RaceDetailView`).
    private let openRace: (DTO.CX24Homepage.Race) -> Void
    /// Opens a past win's edition (`CXEventDetailView`).
    private let openEvent: (DTO.CXCalendarEvent) -> Void
    /// Opens a "Recent results" row as a native race detail.
    private let openRaceResult: (DTO.CXRiderPage.Result, CXRaces.RiderRef) -> Void
    /// Fetches the rider page; injectable so previews never hit the network.
    private let loadRiderPage: (URL?) async -> DTO.CXRiderPage?

    @State private var page: DTO.CXRiderPage?
    @State private var isLoading: Bool

    init(
        context: CXRaces.RiderContext,
        page: DTO.CXRiderPage? = nil,
        loadRiderPage: @escaping (URL?) async -> DTO.CXRiderPage? = {
            await Service.getCxRiderPage($0)
        },
        openRace: @escaping (DTO.CX24Homepage.Race) -> Void = { _ in },
        openEvent: @escaping (DTO.CXCalendarEvent) -> Void = { _ in },
        openRaceResult: @escaping (DTO.CXRiderPage.Result, CXRaces.RiderRef) -> Void = { _, _ in },
        openURL: @escaping (URL) -> Void
    ) {
        self.context = context
        self.openURL = openURL
        self.openRace = openRace
        self.openEvent = openEvent
        self.openRaceResult = openRaceResult
        self.loadRiderPage = loadRiderPage
        _page = State(initialValue: page)
        _isLoading = State(initialValue: page == nil && context.riderURL != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profilePanel
                switch context {
                case .standing(let standing):
                    standingPanel(standing)
                case .podium(let podium):
                    podiumPanel(podium)
                case .result(let result):
                    resultPanel(result)
                case .win(let winner):
                    winPanel(winner)
                }

                if isLoading {
                    LoaderView(title: "Loading rider...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let page {
                    if !page.facts.isEmpty {
                        CXRiderFactsPanel(facts: page.facts)
                    }
                    if !page.results.isEmpty {
                        CXRiderRecentResultsPanel(
                            results: page.results,
                            openResult: { openRaceResult($0, riderRef) }
                        )
                    }
                }

                if let riderURL = context.riderURL {
                    Button {
                        openURL(riderURL)
                    } label: {
                        VaporCard {
                            VaporMoreInfoLink(title: "rider page on cyclocross24")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle("Rider")
        .task {
            guard isLoading else { return }
            page = await loadRiderPage(context.riderURL)
            isLoading = false
        }
    }

    // MARK: - Profile -

    private var profilePanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            HStack(spacing: 6) {
                CXDetailTag(
                    title: "#\(context.position)",
                    color: context.position == "1" ? .tribuneru(.vaporAccent) : .tribuneru(.vaporTextSecondary)
                )
                CXDetailTag(title: context.category)
            }
        } content: {
            HStack(alignment: .center, spacing: 16) {
                CXRiderAvatar(url: page?.avatarURL)

                VStack(alignment: .leading, spacing: 6) {
                    TribuneruText(
                        content: riderName,
                        style: .vaporSectionTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )
                    HStack(spacing: 8) {
                        VaporFlagView(url: context.flagURL)
                        TribuneruText(
                            content: page?.nationality ?? context.country ?? "-",
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                    if let team = page?.team ?? context.team {
                        TribuneruText(
                            content: team,
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 2
                        )
                    }
                }
            }
        }
    }

    // MARK: - Standing -

    private func standingPanel(_ standing: CXRaces.RiderStanding) -> some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Standing")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    if let standingsURL = standing.standingsURL {
                        openURL(standingsURL)
                    }
                } label: {
                    VaporCard {
                        HStack(spacing: 10) {
                            rankingLogo(standing.rankingLogoURL)
                            VStack(alignment: .leading, spacing: 2) {
                                TribuneruText(
                                    content: standing.rankingTitle,
                                    style: .vaporRaceNameNext,
                                    color: .tribuneru(.vaporTextPrimary),
                                    lineLimit: 2
                                )
                                TribuneruText(
                                    content: standing.category,
                                    style: .vaporMeta,
                                    color: .tribuneru(.vaporTextSecondary),
                                    lineLimit: 1
                                )
                            }
                            Spacer(minLength: 0)
                            if standing.standingsURL != nil {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(standing.standingsURL == nil)

                HStack(spacing: 10) {
                    CXStatTile(
                        label: "Position",
                        value: "#\(standing.position)"
                    )
                    CXStatTile(
                        label: "Points",
                        value: standing.points.isEmpty ? "-" : standing.points
                    )
                }
            }
        }
    }

    private func rankingLogo(_ logoURL: URL?) -> some View {
        Group {
            if let logoURL {
                CachedImageView(
                    imageUrl: logoURL,
                    cornerRadius: 1
                )
            } else {
                Image(systemName: "trophy")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                    .padding(4)
            }
        }
        .frame(width: 28, height: 28)
        .background(Color.tribuneru(.vaporPageBackground).opacity(0.6))
        .cornerRadius(6)
    }

    // MARK: - Podium -

    private func podiumPanel(_ podium: CXRaces.RiderPodium) -> some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Result")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    openRace(podium.race)
                } label: {
                    VaporCard {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                TribuneruText(
                                    content: podium.race.title,
                                    style: .vaporRaceNameNext,
                                    color: .tribuneru(.vaporTextPrimary),
                                    lineLimit: 2
                                )
                                HStack(spacing: 6) {
                                    VaporFlagView(url: podium.race.countryFlagURL)
                                    TribuneruText(
                                        content: [podium.race.date, podium.race.location]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " · "),
                                        style: .vaporMeta,
                                        color: .tribuneru(.vaporTextSecondary),
                                        lineLimit: 1
                                    )
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.tribuneru(.vaporTextSecondary))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    CXStatTile(
                        label: "Position",
                        value: "#\(podium.position)"
                    )
                    CXStatTile(
                        label: "Time",
                        value: podium.time.isEmpty ? "-" : podium.time
                    )
                }
            }
        }
    }

    // MARK: - Result -

    /// Opened from the race screen it describes, so the race card isn't a link back.
    private func resultPanel(_ result: CXRaces.RiderResult) -> some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Result")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                VaporCard(spacing: 4) {
                    TribuneruText(
                        content: result.raceTitle,
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )
                    HStack(spacing: 6) {
                        VaporFlagView(url: result.raceFlagURL)
                        TribuneruText(
                            content: [result.category, result.raceMeta]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · "),
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                }

                HStack(spacing: 10) {
                    CXStatTile(
                        label: "Position",
                        value: "#\(result.result.position)"
                    )
                    CXStatTile(
                        label: "Time",
                        value: result.result.time.isEmpty ? "-" : result.result.time
                    )
                    if !result.result.age.isEmpty {
                        CXStatTile(
                            label: "Age",
                            value: result.result.age
                        )
                    }
                }
            }
        }
    }

    // MARK: - Win -

    /// A past edition won by this rider; the race card opens that edition.
    private func winPanel(_ winner: CXRaces.Winner) -> some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Victory")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    openEvent(winner.raceEvent)
                } label: {
                    VaporCard {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                TribuneruText(
                                    content: winner.race,
                                    style: .vaporRaceNameNext,
                                    color: .tribuneru(.vaporTextPrimary),
                                    lineLimit: 2
                                )
                                HStack(spacing: 6) {
                                    VaporFlagView(url: winner.raceFlagURL)
                                    TribuneruText(
                                        content: [winner.dateText, winner.raceClass]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " · "),
                                        style: .vaporMeta,
                                        color: .tribuneru(.vaporTextSecondary),
                                        lineLimit: 1
                                    )
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.tribuneru(.vaporTextSecondary))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    CXStatTile(
                        label: "Edition",
                        value: winner.dateText
                    )
                    CXStatTile(
                        label: "Series",
                        value: winner.series.title
                    )
                }
            }
        }
    }

    // MARK: - Helpers -

    /// This screen's rider, for opening the winner screen from one of their wins.
    private var riderRef: CXRaces.RiderRef {
        CXRaces.RiderRef(
            name: riderName,
            riderURL: context.riderURL,
            flagURL: context.flagURL,
            country: page?.nationality ?? context.country
        )
    }

    private var riderName: String {
        if let name = page?.name, !name.isEmpty {
            return name
        }
        return context.rider
    }
}

#if DEBUG

// MARK: - Mocks -

private extension CXRaces.RiderStanding {
    static var mock: Self {
        .init(
            leader: .init(
                position: 1,
                rider: "VANTHOURENHOUT Michael",
                riderURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                points: "2058"
            ),
            category: .init(
                title: "Men Elite",
                url: URL(string: "https://cyclocross24.com/uciranking/2025-2026/ME/"),
                leaders: [],
                leaderImageURL: nil
            ),
            item: .init(
                title: "UCI Ranking Cyclocross",
                url: URL(string: "https://cyclocross24.com/uciranking/"),
                logoURL: URL(string: "https://cyclocross24.com/images/flag/32/UCI.png"),
                categories: []
            )
        )
    }
}

private extension DTO.CXRiderPage {
    static var mockVanthourenhout: Self {
        .init(
            name: "Michael Vanthourenhout",
            avatarURL: URL(string: "https://cyclocross24.com/images/rider/michael-vanthourenhout-sX4.png"),
            facts: [
                .init(label: "Date of birth", value: "10 December 1993"),
                .init(label: "Nationality", value: "Belgium"),
                .init(label: "Team", value: "Pauwels Sauzen - Cibel Clementines")
            ],
            results: [
                .init(
                    date: "04-01-2026",
                    race: "X2O Badkamers Trofee - Middelkerke",
                    position: "3",
                    raceURL: URL(string: "https://cyclocross24.com/race/18001/")
                ),
                .init(
                    date: "28-12-2025",
                    race: "UCI World Cup Dendermonde",
                    position: "1",
                    raceURL: URL(string: "https://cyclocross24.com/race/17990/")
                )
            ]
        )
    }
}

// MARK: - Previews -

#Preview("CX Rider - loaded") {
    NavigationStack {
        CXRiderDetailView(
            context: .standing(.mock),
            page: .mockVanthourenhout
        ) { _ in }
    }
}

#Preview("CX Rider - podium") {
    NavigationStack {
        CXRiderDetailView(
            context: .podium(
                .init(
                    podium: .init(
                        position: 2,
                        rider: "DEL GROSSO Tibor",
                        riderURL: URL(string: "https://cyclocross24.com/rider/tibor-del-grosso/"),
                        country: "Netherlands",
                        countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                        time: "0:45"
                    ),
                    category: .init(
                        title: "Men Elite",
                        categoryURL: nil,
                        winnerImageURL: nil,
                        podium: []
                    ),
                    race: .init(
                        title: "UCI World Cup Zonhoven (CDM)",
                        country: "Belgium",
                        countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                        date: "4 January 2026",
                        location: "Zonhoven, Belgium",
                        raceURL: nil,
                        categories: []
                    )
                )
            ),
            loadRiderPage: { _ in nil }
        ) { _ in }
    }
}

#Preview("CX Rider - standings data only") {
    NavigationStack {
        CXRiderDetailView(
            context: .standing(.mock),
            loadRiderPage: { _ in nil }
        ) { _ in }
    }
}

#Preview("CX Rider - loading") {
    NavigationStack {
        CXRiderDetailView(
            context: .standing(.mock),
            loadRiderPage: { _ in
                // Never finishes, so the preview stays on the loader.
                try? await Task.sleep(for: .seconds(3600))
                return nil
            }
        ) { _ in }
    }
}

#endif
