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
    /// Fetches the rider page and, for a past win, its winning results row; injectable so
    /// previews never hit the network.
    private let loadDetail: (CXRaces.RiderContext) async -> DTO.CXWinnerDetail

    @State private var page: DTO.CXRiderPage?
    /// The past win's results row (time, team, age); only used by the `.win` context.
    @State private var winResult: DTO.CX24Homepage.CategoryResult?
    @State private var isLoading: Bool

    init(
        context: CXRaces.RiderContext,
        page: DTO.CXRiderPage? = nil,
        loadDetail: @escaping (CXRaces.RiderContext) async -> DTO.CXWinnerDetail = {
            await Service.getCxWinnerDetail(
                riderURL: $0.riderURL,
                resultsURL: $0.winResultsURL
            )
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
        self.loadDetail = loadDetail
        _page = State(initialValue: page)
        let initialWinResult: DTO.CX24Homepage.CategoryResult?
        if case .win(let winner) = context {
            initialWinResult = winner.result
        } else {
            initialWinResult = nil
        }
        _winResult = State(initialValue: initialWinResult)
        let isLoading = page == nil && (context.riderURL != nil || context.winResultsURL != nil)
        _isLoading = State(initialValue: isLoading)
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
                    VStack(alignment: .leading, spacing: 20) {
                        CXRiderFactsPanel(facts: DTO.CXRiderPage.Fact.placeholders)
                        CXRiderRecentResultsPanel(
                            results: DTO.CXRiderPage.Result.placeholders,
                            openResult: { _ in }
                        )
                    }
                    .redacted(reason: .placeholder)
                    .disabled(true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.tr("Loading the rider"))
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
                            VaporMoreInfoLink(title: L10n.tr("rider page on cyclocross24"))
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
        .navigationTitle(L10n.tr("Rider"))
        .task {
            guard isLoading else { return }
            let detail = await loadDetail(context)
            page = detail.page
            winResult = winResult ?? detail.result
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
                    if let team = page?.team ?? context.team ?? winTeam {
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
            VaporSectionHeader(title: L10n.tr("Standing"))
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
                        label: L10n.tr("Position"),
                        value: "#\(standing.position)"
                    )
                    CXStatTile(
                        label: L10n.tr("Points"),
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
            VaporSectionHeader(title: L10n.tr("Result"))
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
                        label: L10n.tr("Position"),
                        value: "#\(podium.position)"
                    )
                    CXStatTile(
                        label: L10n.tr("Time"),
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
            VaporSectionHeader(title: L10n.tr("Result"))
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
                        label: L10n.tr("Position"),
                        value: "#\(result.result.position)"
                    )
                    CXStatTile(
                        label: L10n.tr("Time"),
                        value: result.result.time.isEmpty ? "-" : result.result.time
                    )
                    if !result.result.age.isEmpty {
                        CXStatTile(
                            label: L10n.tr("Age"),
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
            VaporSectionHeader(title: L10n.tr("Victory"))
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
                    if let time = winResult?.time, !time.isEmpty {
                        CXStatTile(
                            label: L10n.tr("Time"),
                            value: time
                        )
                    }
                    if let age = winResult?.age, !age.isEmpty {
                        CXStatTile(
                            label: L10n.tr("Age"),
                            value: age
                        )
                    }
                    CXStatTile(
                        label: L10n.tr("Series"),
                        value: winner.series.title
                    )
                }
            }
        }
    }

    // MARK: - Helpers -

    /// The past win's team, from its results row.
    private var winTeam: String? {
        guard let team = winResult?.team, !team.isEmpty else { return nil }
        return team
    }

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
                title: "Men Elite", // l10n:ignore
                url: URL(string: "https://cyclocross24.com/uciranking/2025-2026/ME/"),
                leaders: [],
                leaderImageURL: nil
            ),
            item: .init(
                title: "UCI Ranking Cyclocross", // l10n:ignore
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
                .init(label: "Date of birth", value: "10 December 1993"), // l10n:ignore
                .init(label: "Nationality", value: "Belgium"), // l10n:ignore
                .init(label: "Team", value: "Pauwels Sauzen - Cibel Clementines") // l10n:ignore
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
            loadDetail: { _ in
                .init(
                    page: nil,
                    result: nil
                )
            }
        ) { _ in }
    }
}

#Preview("CX Rider - standings data only") {
    NavigationStack {
        CXRiderDetailView(
            context: .standing(.mock),
            loadDetail: { _ in
                .init(
                    page: nil,
                    result: nil
                )
            }
        ) { _ in }
    }
}

#Preview("CX Rider - loading") {
    NavigationStack {
        CXRiderDetailView(
            context: .standing(.mock),
            loadDetail: { _ in
                // Never finishes, so the preview stays on the placeholders.
                try? await Task.sleep(for: .seconds(3600))
                return .init(
                    page: nil,
                    result: nil
                )
            }
        ) { _ in }
    }
}

#endif
