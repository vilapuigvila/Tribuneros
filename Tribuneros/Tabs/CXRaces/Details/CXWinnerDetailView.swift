//
//  CXWinnerDetailView.swift
//  Tribuneros
//
//  Created by albert vila on 29/9/26.
//

import SwiftUI

/// Native screen for the winner of a CX calendar race, opened from the "Winner" row of
/// `CXEventDetailView`. The race facts (who, where, winning time, team, age) come from data the
/// app already holds: the calendar event and, when it was loaded, the winner's results row. The
/// rider's photo, profile facts and recent results come from their cyclocross24 page, fetched on
/// the device and parsed best-effort — each section hides when it comes back empty.
struct CXWinnerDetailView: View {
    let event: DTO.CXCalendarEvent
    let result: DTO.CX24Homepage.CategoryResult?
    let openURL: (URL) -> Void
    /// Fetches the rider page; injectable so previews never hit the network.
    private let loadRiderPage: (URL?) async -> DTO.CXRiderPage?

    @State private var page: DTO.CXRiderPage?
    @State private var isLoading: Bool

    init(
        event: DTO.CXCalendarEvent,
        result: DTO.CX24Homepage.CategoryResult?,
        page: DTO.CXRiderPage? = nil,
        loadRiderPage: @escaping (URL?) async -> DTO.CXRiderPage? = {
            await Service.getCxRiderPage($0)
        },
        openURL: @escaping (URL) -> Void
    ) {
        self.event = event
        self.result = result
        self.openURL = openURL
        self.loadRiderPage = loadRiderPage
        _page = State(initialValue: page)
        _isLoading = State(initialValue: page == nil && event.winnerURL != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profilePanel
                victoryPanel

                if isLoading {
                    LoaderView(title: "Loading rider...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let page {
                    if !page.facts.isEmpty {
                        factsPanel(page.facts)
                    }
                    if !page.results.isEmpty {
                        recentResultsPanel(page.results)
                    }
                }

                if let winnerURL = event.winnerURL {
                    Button {
                        openURL(winnerURL)
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
        .navigationTitle("Winner")
        .task {
            guard isLoading else { return }
            page = await loadRiderPage(event.winnerURL)
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
                avatar

                VStack(alignment: .leading, spacing: 6) {
                    TribuneruText(
                        content: riderName,
                        style: .vaporSectionTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )
                    HStack(spacing: 8) {
                        VaporFlagView(url: event.winnerFlagURL ?? result?.countryFlagURL)
                        TribuneruText(
                            content: event.winnerCountry ?? "-",
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

    private var avatar: some View {
        Group {
            if let avatarURL = page?.avatarURL {
                CachedImageView(
                    imageUrl: avatarURL,
                    cornerRadius: 40
                )
                .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
            }
        }
        .frame(width: 80, height: 80)
        .background(Color.tribuneru(.vaporCardSurface))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.tribuneru(.vaporAccent), lineWidth: 1.5)
        )
    }

    // MARK: - Victory -

    private var victoryPanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Victory")
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                VaporCard(spacing: 4) {
                    TribuneruText(
                        content: event.race,
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )
                    HStack(spacing: 6) {
                        VaporFlagView(url: event.flagURL)
                        TribuneruText(
                            content: [victoryDate, event.raceClass]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · "),
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                }

                if !stats.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(stats) { stat in
                            StatTile(
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
        stats.append(.init(label: "Series", value: event.series.title))
        return stats
    }

    // MARK: - Facts -

    private func factsPanel(_ facts: [DTO.CXRiderPage.Fact]) -> some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelYesterday)) {
            VaporSectionHeader(title: "Profile")
        } content: {
            VaporCard(spacing: 0) {
                ForEach(facts.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        TribuneruText(
                            content: facts[index].label,
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                        .frame(width: 110, alignment: .leading)
                        TribuneruText(
                            content: facts[index].value,
                            style: .vaporRaceNameResult,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 2
                        )
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)

                    if index < facts.count - 1 {
                        divider
                    }
                }
            }
        }
    }

    // MARK: - Recent results -

    private func recentResultsPanel(_ results: [DTO.CXRiderPage.Result]) -> some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelTomorrow)) {
            VaporSectionHeader(title: "Recent results")
        } content: {
            VaporCard(spacing: 0) {
                ForEach(results.indices, id: \.self) { index in
                    let item = results[index]
                    Button {
                        if let raceURL = item.raceURL {
                            openURL(raceURL)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            PositionBadge(position: item.position)
                            VStack(alignment: .leading, spacing: 2) {
                                TribuneruText(
                                    content: item.race,
                                    style: .vaporRaceNameResult,
                                    color: .tribuneru(.vaporTextPrimary),
                                    lineLimit: 1
                                )
                                TribuneruText(
                                    content: item.date,
                                    style: .vaporMonoMeta,
                                    color: .tribuneru(.vaporTextSecondary),
                                    lineLimit: 1
                                )
                            }
                            Spacer(minLength: 0)
                            if item.raceURL != nil {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(item.raceURL == nil)

                    if index < results.count - 1 {
                        divider
                    }
                }
            }
        }
    }

    // MARK: - Helpers -

    private var riderName: String {
        if let name = page?.name, !name.isEmpty {
            return name
        }
        return event.winnerName
    }

    private var victoryDate: String {
        guard let date = event.eventDate else { return event.date }
        return CXWinnerDetailDate.formatter.string(from: date)
    }

    private var divider: some View {
        TribunerosDivider(
            height: 0.5,
            color: .tribuneru(.vaporTextSecondary).opacity(0.2)
        )
    }
}

// MARK: - Private types -

private enum CXWinnerDetailDate {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

private struct Stat: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TribuneruText(
                content: label.uppercased(),
                style: .vaporGroupLabel,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            TribuneruText(
                content: value,
                style: .vaporFinishTime,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tribuneru(.vaporCardSurface))
        .cornerRadius(8)
    }
}

/// Finishing position; wins are highlighted in the accent colour.
private struct PositionBadge: View {
    let position: String

    var body: some View {
        let isWin = position == "1"
        TribuneruText(
            content: position,
            style: .vaporFinishTime,
            color: isWin ? .tribuneru(.vaporPageBackground) : .tribuneru(.vaporTextPrimary),
            lineLimit: 1
        )
        .frame(width: 30, height: 30)
        .background(
            isWin
            ? Color.tribuneru(.vaporAccent)
            : Color.tribuneru(.vaporPageBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
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
            event: .mockWinner,
            result: .mockWinner,
            page: .mock
        ) { _ in }
    }
}

#Preview("CX Winner - calendar data only") {
    NavigationStack {
        CXWinnerDetailView(
            event: .mockWinner,
            result: nil,
            loadRiderPage: { _ in nil }
        ) { _ in }
    }
}

#Preview("CX Winner - loading") {
    NavigationStack {
        CXWinnerDetailView(
            event: .mockWinner,
            result: .mockWinner,
            loadRiderPage: { _ in
                // Never finishes, so the preview stays on the loader.
                try? await Task.sleep(for: .seconds(3600))
                return nil
            }
        ) { _ in }
    }
}

#endif
