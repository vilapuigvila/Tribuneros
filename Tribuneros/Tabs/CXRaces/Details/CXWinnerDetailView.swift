//
//  CXWinnerDetailView.swift
//  Tribuneros
//
//  Created by albert vila on 29/9/26.
//

import SwiftUI

/// Native screen for a CX race winner, opened from `CXEventDetailView`'s "Winner" row (this
/// season) or one of its "Past winners" rows. The race facts come from `CXRaces.Winner`; the
/// winning time, team and age from the winner's results row, loaded from the edition's results
/// page when the caller didn't have it. The rider's photo, profile facts and recent results come
/// from their cyclocross24 page, parsed best-effort — each section hides when it comes back empty.
struct CXWinnerDetailView: View {
    let winner: CXRaces.Winner
    let openURL: (URL) -> Void
    /// Opens the winning race (the "Victory" card) as a native race detail.
    private let openRace: (DTO.CXCalendarEvent) -> Void
    /// Opens a "Recent results" row as a native race detail.
    private let openRaceResult: (DTO.CXRiderPage.Result, CXRaces.RiderRef) -> Void
    /// Fetches the rider page and missing results row; injectable so previews never hit the network.
    private let loadDetail: (CXRaces.Winner) async -> DTO.CXWinnerDetail

    @State private var page: DTO.CXRiderPage?
    @State private var result: DTO.CX24Homepage.CategoryResult?
    @State private var isLoading: Bool
    @State private var loaderPhase: LoaderPhase

    init(
        winner: CXRaces.Winner,
        page: DTO.CXRiderPage? = nil,
        loadDetail: @escaping (CXRaces.Winner) async -> DTO.CXWinnerDetail = {
            await Service.getCxWinnerDetail(
                riderURL: $0.riderURL,
                resultsURL: $0.result == nil ? $0.resultsURL : nil
            )
        },
        openRace: @escaping (DTO.CXCalendarEvent) -> Void = { _ in },
        openRaceResult: @escaping (DTO.CXRiderPage.Result, CXRaces.RiderRef) -> Void = { _, _ in },
        openURL: @escaping (URL) -> Void
    ) {
        self.winner = winner
        self.openURL = openURL
        self.openRace = openRace
        self.openRaceResult = openRaceResult
        self.loadDetail = loadDetail
        _page = State(initialValue: page)
        _result = State(initialValue: winner.result)
        let needsResult = winner.result == nil && winner.resultsURL != nil
        let isLoading = page == nil && (winner.riderURL != nil || needsResult)
        _isLoading = State(initialValue: isLoading)
        _loaderPhase = State(initialValue: LoaderPhase(isLoading: isLoading))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profilePanel
                victoryPanel

                if loaderPhase == .loader {
                    LoaderView(title: "Loading rider...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if loaderPhase == .content, let page {
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

                if let riderURL = winner.riderURL {
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
        .loaderPhase(
            $loaderPhase,
            isLoading: isLoading
        )
        .preferredColorScheme(.dark)
        .navigationTitle("Winner")
        .task {
            guard isLoading else { return }
            let detail = await loadDetail(winner)
            page = detail.page
            result = result ?? detail.result
            isLoading = false
        }
    }

    // MARK: - Profile -

    private var profilePanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            HStack(spacing: 6) {
                CXDetailTag(
                    title: "Winner",
                    color: .tribuneru(.vaporAccent)
                )
                CXDetailTag(title: "Men Elite")
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
                        VaporFlagView(url: winner.flagURL ?? result?.countryFlagURL)
                        TribuneruText(
                            content: winner.country ?? countryFact ?? "-",
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                    if let team = result?.team, !team.isEmpty {
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

    // MARK: - Victory -

    private var victoryPanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Victory")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    openRace(winner.raceEvent)
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

                if !stats.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(stats) { stat in
                            CXStatTile(
                                label: stat.label,
                                value: stat.value
                            )
                        }
                    }
                }
            }
        }
    }

    private var stats: [Stat] {
        var stats: [Stat] = []
        if let time = result?.time, !time.isEmpty {
            stats.append(.init(label: "Time", value: time))
        }
        if let age = result?.age, !age.isEmpty {
            stats.append(.init(label: "Age", value: age))
        }
        stats.append(.init(label: "Series", value: winner.series.title))
        return stats
    }

    // MARK: - Helpers -

    /// This screen's rider, for opening the winner screen from one of their wins.
    private var riderRef: CXRaces.RiderRef {
        CXRaces.RiderRef(
            name: riderName,
            riderURL: winner.riderURL,
            flagURL: winner.flagURL ?? result?.countryFlagURL,
            country: winner.country ?? countryFact
        )
    }

    private var riderName: String {
        if let name = page?.name, !name.isEmpty {
            return name
        }
        return winner.name
    }

    /// Past winners carry no country, so fall back to a "Nationality" fact from the rider page.
    private var countryFact: String? {
        page?.nationality
    }
}

// MARK: - Private types -

private struct Stat: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

#if DEBUG

// MARK: - Mocks -

private extension DTO.CXCalendarEvent {
    static var mockWinner: Self {
        .init(
            date: "04-01-2026",
            race: "X2O Badkamers Trofee - Middelkerke",
            raceClass: "C1",
            flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
            winnerName: "VAN DER POEL Mathieu",
            isCancelled: false,
            raceID: 18001,
            raceSlug: "middelkerke",
            raceURL: URL(string: "https://cyclocross24.com/race/middelkerke/"),
            resultsURL: URL(string: "https://cyclocross24.com/race/18001/"),
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "Belgium",
            winnerURL: URL(string: "https://cyclocross24.com/rider/mathieu-van-der-poel/"),
            winnerCountry: "Netherlands",
            winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png")
        )
    }
}

private extension DTO.CX24Homepage.CategoryResult {
    static var mockWinner: Self {
        .init(
            position: "1",
            rider: "VAN DER POEL Mathieu",
            age: "31",
            team: "Alpecin - Deceuninck",
            time: "59:36",
            countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
            raceVideosURL: nil
        )
    }
}

private extension DTO.CXRiderPage {
    static var mock: Self {
        .init(
            name: "Mathieu van der Poel",
            avatarURL: URL(string: "https://cyclocross24.com/images/rider/mathieu-van-der-poel-kL0.png"),
            facts: [
                .init(label: "Date of birth", value: "19 January 1995"),
                .init(label: "Nationality", value: "Netherlands"),
                .init(label: "Team", value: "Alpecin - Deceuninck")
            ],
            results: [
                .init(
                    date: "04-01-2026",
                    race: "X2O Badkamers Trofee - Middelkerke",
                    position: "1",
                    raceURL: URL(string: "https://cyclocross24.com/race/18001/")
                ),
                .init(
                    date: "28-12-2025",
                    race: "UCI World Cup Dendermonde",
                    position: "2",
                    raceURL: URL(string: "https://cyclocross24.com/race/17990/")
                )
            ]
        )
    }
}

// MARK: - Previews -

#Preview("CX Winner - loaded") {
    NavigationStack {
        CXWinnerDetailView(
            winner: .init(
                event: .mockWinner,
                result: .mockWinner
            ),
            page: .mock
        ) { _ in }
    }
}

#Preview("CX Winner - past edition") {
    NavigationStack {
        CXWinnerDetailView(
            winner: .init(
                event: .mockWinner,
                pastWinner: .init(
                    year: "2024",
                    rider: "ISERBYT Eli",
                    riderURL: URL(string: "https://cyclocross24.com/rider/eli-iserbyt/"),
                    countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                    resultsURL: URL(string: "https://cyclocross24.com/race/17001/")
                )
            ),
            loadDetail: { _ in
                .init(
                    page: nil,
                    result: .init(
                        position: "1",
                        rider: "ISERBYT Eli",
                        age: "26",
                        team: "Pauwels Sauzen - Cibel Clementines",
                        time: "1:01:12",
                        countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                        raceVideosURL: nil
                    )
                )
            }
        ) { _ in }
    }
}

#Preview("CX Winner - calendar data only") {
    NavigationStack {
        CXWinnerDetailView(
            winner: .init(
                event: .mockWinner,
                result: nil
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

#Preview("CX Winner - loading") {
    NavigationStack {
        CXWinnerDetailView(
            winner: .init(
                event: .mockWinner,
                result: .mockWinner
            ),
            loadDetail: { _ in
                // Never finishes, so the preview stays on the loader.
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
