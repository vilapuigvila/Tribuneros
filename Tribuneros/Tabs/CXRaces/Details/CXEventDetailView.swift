//
//  CXEventDetailView.swift
//  Tribuneros
//
//  Created by albert vila on 29/9/26.
//

import SwiftUI

/// Detail of one "All races" calendar row. The header and race facts come straight from the
/// Firestore calendar event; the Men Elite results, video and the race's history of winners
/// (from its cyclocross24 `/race/<slug>/` page) are fetched on the device when the screen opens.
struct CXEventDetailView: View {
    private enum UI {
        static let resultsLimit = 10
        static let pastWinnersLimit = 12
    }

    let event: DTO.CXCalendarEvent
    let openURL: (URL) -> Void
    /// Opens the native winner screen, for this season's winner or a past edition's.
    private let openWinner: (CXRaces.Winner) -> Void
    /// Fetches the on-demand part of the screen; injectable so previews never hit the network.
    private let loadDetail: (DTO.CXCalendarEvent, Bool) async -> DTO.CXEventDetail

    @State private var detail: DTO.CXEventDetail
    @State private var isLoading: Bool
    @State private var videoSheet: VideoSheet?

    init(
        event: DTO.CXCalendarEvent,
        detail: DTO.CXEventDetail? = nil,
        loadDetail: @escaping (DTO.CXCalendarEvent, Bool) async -> DTO.CXEventDetail = {
            await Service.getCxEventDetail(
                $0,
                hasStarted: $1
            )
        },
        openWinner: @escaping (CXRaces.Winner) -> Void = { _ in },
        openURL: @escaping (URL) -> Void
    ) {
        self.event = event
        self.openURL = openURL
        self.openWinner = openWinner
        self.loadDetail = loadDetail
        _detail = State(initialValue: detail ?? .empty)
        _isLoading = State(initialValue: detail == nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryPanel

                if !winnerName.isEmpty {
                    winnerPanel
                }

                if isLoading {
                    LoaderView(title: "Loading race info...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    if !detail.results.isEmpty {
                        resultsPanel
                    }
                    if let page = detail.page, !page.pastWinners.isEmpty {
                        pastWinnersPanel(page.pastWinners)
                    }
                    if let summary = detail.page?.summary, !summary.isEmpty {
                        aboutPanel(summary)
                    }
                }

                linksPanel
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle(event.series.title)
        .fullScreenCover(item: $videoSheet) { sheet in
            YoutubeVideoView(url: sheet.url)
        }
        .task {
            guard isLoading else { return }
            detail = await loadDetail(
                event,
                status.hasStarted
            )
            isLoading = false
        }
    }

    // MARK: - Summary -

    private var summaryPanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: event.race)
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    CXDetailTag(title: event.series.title)
                    if !event.raceClass.isEmpty {
                        CXDetailTag(title: event.raceClass)
                    }
                    CXDetailTag(
                        title: status.title,
                        color: status.color
                    )
                }

                VaporCard(spacing: 0) {
                    InfoRow(
                        systemImage: "calendar",
                        title: "Date",
                        value: formattedDate
                    )
                    divider
                    InfoRow(
                        systemImage: "mappin.and.ellipse",
                        title: "Country",
                        value: event.raceCountry ?? "-",
                        flagURL: event.flagURL
                    )
                    if let classDescription = CXRaces.raceClassDescription(event.raceClass) {
                        divider
                        InfoRow(
                            systemImage: "flag.checkered",
                            title: "Class",
                            value: "\(event.raceClass) · \(classDescription)"
                        )
                    }
                    if let countdown {
                        divider
                        InfoRow(
                            systemImage: "timer",
                            title: "Starts",
                            value: countdown
                        )
                    }
                }
            }
        }
    }

    // MARK: - Winner -

    private var winnerPanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            VaporSectionHeader(title: "Winner")
        } content: {
            Button {
                openWinner(
                    CXRaces.Winner(
                        event: event,
                        result: winningResult
                    )
                )
            } label: {
                VaporCard {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.tribuneru(.vaporAccent))
                        VaporFlagView(url: event.winnerFlagURL ?? winningResult?.countryFlagURL)
                        VStack(alignment: .leading, spacing: 2) {
                            TribuneruText(
                                content: winnerName,
                                style: .vaporWinnerName,
                                color: .tribuneru(.vaporTextPrimary),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: ["Men Elite", event.winnerCountry, winningResult?.time]
                                    .compactMap { $0 }
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · "),
                                style: .vaporMeta,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 1
                            )
                        }
                        Spacer(minLength: 0)
                        chevron
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// The calendar's winner, or the results' when the calendar has none (a race opened from a
    /// rider's recent results, outside this season's calendar).
    private var winnerName: String {
        event.winnerName.isEmpty ? (winningResult?.rider ?? "") : event.winnerName
    }

    /// The results row of the winner, which carries their team, age and winning time.
    private var winningResult: DTO.CX24Homepage.CategoryResult? {
        detail.results.first { $0.position == "1" }
    }

    // MARK: - Results -

    private var resultsPanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelYesterday)) {
            VaporSectionHeader(title: "Results")
        } content: {
            VaporCard(spacing: 0) {
                TribuneruText(
                    content: "MEN ELITE · TOP \(min(UI.resultsLimit, detail.results.count))",
                    style: .vaporGroupLabel,
                    color: .tribuneru(.vaporTextSecondary)
                )
                .padding(.bottom, 8)

                let results = Array(detail.results.prefix(UI.resultsLimit))
                ForEach(results.indices, id: \.self) { index in
                    ResultRow(result: results[index])
                    if index < results.count - 1 {
                        divider
                    }
                }

                if let resultsURL = event.resultsURL {
                    Button {
                        openURL(resultsURL)
                    } label: {
                        VaporMoreInfoLink(title: "full results")
                            .padding(.top, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Past winners -

    private func pastWinnersPanel(_ winners: [DTO.CXRacePage.PastWinner]) -> some View {
        let winners = Array(winners.prefix(UI.pastWinnersLimit))
        return VaporPanel(panelColor: .tribuneru(.vaporPanelTomorrow)) {
            VaporSectionHeader(title: "Past winners")
        } content: {
            VaporCard(spacing: 0) {
                ForEach(winners.indices, id: \.self) { index in
                    let winner = winners[index]
                    Button {
                        openWinner(
                            CXRaces.Winner(
                                event: event,
                                pastWinner: winner
                            )
                        )
                    } label: {
                        HStack(spacing: 10) {
                            TribuneruText(
                                content: winner.year,
                                style: .vaporETALine,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 1
                            )
                            .frame(width: 44, alignment: .leading)
                            VaporFlagView(url: winner.countryFlagURL)
                            TribuneruText(
                                content: winner.rider,
                                style: .vaporRaceNameResult,
                                color: .tribuneru(.vaporTextPrimary),
                                lineLimit: 1
                            )
                            Spacer(minLength: 0)
                            chevron
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < winners.count - 1 {
                        divider
                    }
                }
            }
        }
    }

    // MARK: - About -

    private func aboutPanel(_ summary: String) -> some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "About")
        } content: {
            VaporCard {
                TribuneruText(
                    content: summary,
                    style: .vaporFeedDetail,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 8
                )
            }
        }
    }

    // MARK: - Links -

    private var linksPanel: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            VaporSectionHeader(title: "Links")
        } content: {
            VaporCard(spacing: 0) {
                let items = links
                ForEach(items.indices, id: \.self) { index in
                    let link = items[index]
                    Button {
                        link.handler()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: link.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.tribuneru(.vaporAccent))
                                .frame(width: 20)
                            TribuneruText(
                                content: link.title,
                                style: .vaporRaceNameNext,
                                color: .tribuneru(.vaporTextPrimary),
                                lineLimit: 1
                            )
                            Spacer(minLength: 0)
                            chevron
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        divider
                    }
                }
            }
        }
    }

    private var links: [DetailLink] {
        var links: [DetailLink] = []
        if let videoURL = detail.videoURL {
            links.append(
                .init(
                    title: "Race video",
                    systemImage: "play.rectangle.fill"
                ) {
                    videoSheet = VideoSheet(url: videoURL)
                }
            )
        }
        if let websiteURL = event.websiteURL {
            links.append(
                .init(
                    title: "Official website",
                    systemImage: "globe"
                ) {
                    openURL(websiteURL)
                }
            )
        }
        if let raceURL = event.raceURL {
            links.append(
                .init(
                    title: "Race page on cyclocross24",
                    systemImage: "safari"
                ) {
                    openURL(raceURL)
                }
            )
        }
        return links
    }

    // MARK: - Helpers -

    private var divider: some View {
        TribunerosDivider(
            height: 0.5,
            color: .tribuneru(.vaporTextSecondary).opacity(0.2)
        )
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.tribuneru(.vaporTextSecondary))
    }

    private var formattedDate: String {
        guard let date = event.eventDate else { return event.date }
        return CXEventDetailDate.formatter.string(from: date)
    }

    private var daysUntilStart: Int? {
        guard let date = event.eventDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day
    }

    private var countdown: String? {
        guard !event.isCancelled, let days = daysUntilStart, days >= 0 else { return nil }
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    private var status: Status {
        if event.isCancelled {
            return .cancelled
        }
        if !event.winnerName.isEmpty || (daysUntilStart ?? 0) < 0 {
            return .finished
        }
        return daysUntilStart == 0 ? .today : .upcoming
    }
}

// MARK: - Shared components -

/// Outlined Space Mono tag used on the CX detail screens (series, class, status).
struct CXDetailTag: View {
    let title: String
    var color: Color = .tribuneru(.vaporTextSecondary)

    var body: some View {
        TribuneruText(
            content: title.uppercased(),
            style: .vaporFeedTag,
            color: color,
            lineLimit: 1
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(color, lineWidth: 0.5)
        )
    }
}

// MARK: - Private types -

private enum CXEventDetailDate {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

private extension CXEventDetailView {
    enum Status {
        case upcoming
        case today
        case finished
        case cancelled

        /// Results (and a video) can only exist from race day on.
        var hasStarted: Bool { self == .finished || self == .today }

        var title: String {
            switch self {
            case .upcoming: "Upcoming"
            case .today: "Today"
            case .finished: "Finished"
            case .cancelled: "Cancelled"
            }
        }

        var color: Color {
            switch self {
            case .upcoming: .tribuneru(.vaporTextSecondary)
            case .today: .tribuneru(.vaporLive)
            case .finished: .tribuneru(.vaporAccent)
            case .cancelled: .tribuneru(.vaporNegative)
            }
        }
    }

    struct DetailLink {
        let title: String
        let systemImage: String
        let handler: () -> Void
    }

    struct VideoSheet: Identifiable {
        let id = UUID()
        let url: URL
    }

    struct InfoRow: View {
        let systemImage: String
        let title: String
        let value: String
        var flagURL: URL?

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                    .frame(width: 18)
                TribuneruText(
                    content: title,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
                .frame(width: 64, alignment: .leading)
                if let flagURL {
                    VaporFlagView(url: flagURL)
                }
                TribuneruText(
                    content: value,
                    style: .vaporRaceNameResult,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
        }
    }

    struct ResultRow: View {
        let result: DTO.CX24Homepage.CategoryResult

        var body: some View {
            HStack(spacing: 8) {
                TribuneruText(
                    content: result.position,
                    style: .vaporFinishTime,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .frame(width: 22, alignment: .leading)
                VaporFlagView(url: result.countryFlagURL)
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: result.rider,
                        style: .vaporRaceNameResult,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    if !result.team.isEmpty {
                        TribuneruText(
                            content: result.team,
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                }
                Spacer(minLength: 0)
                TribuneruText(
                    content: result.time,
                    style: .vaporFinishTime,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            .padding(.vertical, 8)
        }
    }
}

#if DEBUG

// MARK: - Mocks -

private extension DTO.CXCalendarEvent {
    /// Middelkerke, `daysFromToday` away from now so the status and countdown stay meaningful.
    static func mockMiddelkerke(
        daysFromToday: Int,
        winnerName: String = "",
        isCancelled: Bool = false
    ) -> Self {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = Calendar.current.date(byAdding: .day, value: daysFromToday, to: Date()) ?? Date()
        let hasWinner = !winnerName.isEmpty

        return .init(
            date: formatter.string(from: date),
            race: "X2O Badkamers Trofee - Middelkerke",
            raceClass: "C1",
            flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
            winnerName: winnerName,
            isCancelled: isCancelled,
            raceID: 18001,
            raceSlug: "middelkerke",
            raceURL: URL(string: "https://cyclocross24.com/race/middelkerke/"),
            resultsURL: URL(string: "https://cyclocross24.com/race/18001/"),
            videoURL: hasWinner ? URL(string: "https://cyclocross24.com/race/18001/#video") : nil,
            websiteURL: URL(string: "https://www.trofee-veldrijden.be"),
            raceCountry: "Belgium",
            winnerURL: hasWinner ? URL(string: "https://cyclocross24.com/rider/mathieu-van-der-poel/") : nil,
            winnerCountry: hasWinner ? "Netherlands" : nil,
            winnerFlagURL: hasWinner ? URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png") : nil
        )
    }
}

private extension DTO.CXRacePage {
    static var mockMiddelkerke: Self {
        .init(
            title: "Middelkerke",
            summary: "Cyclocross race on the beach and dunes of Middelkerke, Belgium.",
            pastWinners: [
                .init(
                    year: "2025",
                    rider: "VAN DER POEL Mathieu",
                    riderURL: nil,
                    countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                    resultsURL: nil
                ),
                .init(
                    year: "2024",
                    rider: "ISERBYT Eli",
                    riderURL: nil,
                    countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                    resultsURL: nil
                )
            ]
        )
    }
}

// MARK: - Previews -

#Preview("CX Event Detail - finished") {
    NavigationStack {
        CXEventDetailView(
            event: .mockMiddelkerke(
                daysFromToday: -3,
                winnerName: "VAN DER POEL Mathieu"
            ),
            detail: .init(
                page: .mockMiddelkerke,
                results: [
                    .init(
                        position: "1",
                        rider: "VAN DER POEL Mathieu",
                        age: "31",
                        team: "Alpecin - Deceuninck",
                        time: "59:36",
                        countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Netherlands.png"),
                        raceVideosURL: nil
                    ),
                    .init(
                        position: "2",
                        rider: "NYS Thibau",
                        age: "23",
                        team: "Baloise Glowi Lions",
                        time: "0:45",
                        countryFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                        raceVideosURL: nil
                    )
                ],
                videoURL: URL(string: "https://www.youtube.com/watch?v=EShExWlESGs")
            )
        ) { _ in }
    }
}

#Preview("CX Event Detail - upcoming") {
    NavigationStack {
        CXEventDetailView(
            event: .mockMiddelkerke(daysFromToday: 5),
            detail: .init(
                page: .mockMiddelkerke,
                results: [],
                videoURL: nil
            )
        ) { _ in }
    }
}

#Preview("CX Event Detail - cancelled") {
    NavigationStack {
        CXEventDetailView(
            event: .mockMiddelkerke(
                daysFromToday: 5,
                isCancelled: true
            ),
            detail: .init(
                page: .mockMiddelkerke,
                results: [],
                videoURL: nil
            )
        ) { _ in }
    }
}

#Preview("CX Event Detail - loading") {
    NavigationStack {
        CXEventDetailView(
            event: .mockMiddelkerke(daysFromToday: 5),
            loadDetail: { _, _ in
                // Never finishes, so the preview stays on the loader.
                try? await Task.sleep(for: .seconds(3600))
                return .empty
            }
        ) { _ in }
    }
}

#endif
