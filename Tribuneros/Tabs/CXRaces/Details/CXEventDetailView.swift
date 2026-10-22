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
        static let tvPlaceholders: [DTO.CXRacePage.TVChannel] = (0..<3).map { _ in
            .init(name: "Channel", logoURL: nil, url: nil) // l10n:ignore
        }
    }

    let event: DTO.CXCalendarEvent
    /// Hands a third-party link (broadcaster, organiser, video) to the system.
    let openURL: (URL) -> Void
    /// Opens every Men Elite row (`CXFullResultsView`).
    private let openFullResults: ([DTO.CX24Homepage.CategoryResult]) -> Void
    /// Opens the native winner screen for this season's winner.
    private let openWinner: (CXRaces.Winner) -> Void
    /// Opens the rider screen for a "Past winners" row.
    private let openPastWinner: (CXRaces.Winner) -> Void
    /// Opens the rider screen for a row of the results panel.
    private let openResultRider: (CXRaces.RiderResult) -> Void
    /// Fetches the on-demand part of the screen; injectable so previews never hit the network.
    private let loadDetail: (DTO.CXCalendarEvent, Bool) async -> DTO.CXEventDetail

    @State private var detail: DTO.CXEventDetail
    @State private var isLoading: Bool

    init(
        event: DTO.CXCalendarEvent,
        detail: DTO.CXEventDetail? = nil,
        loadDetail: @escaping (DTO.CXCalendarEvent, Bool) async -> DTO.CXEventDetail = {
            await Service.getCxEventDetail(
                $0,
                hasStarted: $1
            )
        },
        openPastWinner: @escaping (CXRaces.Winner) -> Void = { _ in },
        openResultRider: @escaping (CXRaces.RiderResult) -> Void = { _ in },
        openWinner: @escaping (CXRaces.Winner) -> Void = { _ in },
        openFullResults: @escaping ([DTO.CX24Homepage.CategoryResult]) -> Void = { _ in },
        openURL: @escaping (URL) -> Void
    ) {
        self.event = event
        self.openURL = openURL
        self.openWinner = openWinner
        self.openFullResults = openFullResults
        self.openResultRider = openResultRider
        self.openPastWinner = openPastWinner
        self.loadDetail = loadDetail
        _detail = State(initialValue: detail ?? .empty)
        _isLoading = State(initialValue: detail == nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                summaryPanel

                if !winnerName.isEmpty {
                    winnerPanel
                }

                if isLoading {
                    VStack(alignment: .leading, spacing: 20) {
                        // Results only exist from race day on, so an upcoming race shows none.
                        if status.hasStarted {
                            resultsPanel(DTO.CX24Homepage.CategoryResult.placeholders)
                        }
                        tvPanel(UI.tvPlaceholders)
                        pastWinnersPanel(DTO.CXRacePage.PastWinner.placeholders)
                        aboutPanel("About the race placeholder. A couple of lines of text stand in for the summary of the race until it loads.")
                    }
                    .redacted(reason: .placeholder)
                    .shimmering()
                    .disabled(true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.tr("Loading the race"))
                } else {
                    if !detail.results.isEmpty {
                        resultsPanel(detail.results)
                    }
                    if let channels = detail.page?.tvChannels, !channels.isEmpty {
                        tvPanel(channels)
                    }
                    if let page = detail.page, !page.pastWinners.isEmpty {
                        pastWinnersPanel(page.pastWinners)
                    }
                    if let summary = detail.page?.summary, !summary.isEmpty {
                        aboutPanel(summary)
                    }
                }

                if !links.isEmpty {
                    linksPanel
                }
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(Color.tribuneru(.mudPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle(event.series.title)
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
        VStack(spacing: 0) {
            ZStack {
                CXSeriesArt(series: event.series)
                ImageScrim(
                    top: 0.5,
                    topEnd: 0.34,
                    bottom: 0.8,
                    bottomEnd: 0.46,
                    tint: .tribuneru(.mudPageBackground)
                )
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        MudTag(
                            title: status.title.uppercased(with: L10n.locale),
                            color: status.color
                        )
                        Spacer(minLength: 0)
                        if let countdown {
                            TribuneruText(
                                content: countdown,
                                style: .vaporPill,
                                color: .tribuneru(.mudTextPrimary),
                                lineLimit: 1
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(Color.tribuneru(.mudPageBackground).opacity(0.62))
                            )
                        }
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        TribuneruText(
                            content: event.race,
                            style: .vaporHeroTitle,
                            color: .tribuneru(.white(level: 1)),
                            lineLimit: 2
                        )
                        .artTitleShadow()
                        TribuneruText(
                            content: [event.series.title, event.raceClass]
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
            .clipped()

            VStack(spacing: 0) {
                InfoRow(
                    systemImage: "calendar",
                    title: L10n.tr("Date"),
                    value: formattedDate
                )
                divider
                InfoRow(
                    systemImage: "mappin.and.ellipse",
                    title: L10n.tr("Country"),
                    value: event.raceCountry ?? "-",
                    flagURL: event.flagURL
                )
                if let classDescription = CXRaces.raceClassDescription(event.raceClass) {
                    divider
                    InfoRow(
                        systemImage: "flag.checkered",
                        title: L10n.tr("Class"),
                        value: "\(event.raceClass) · \(classDescription)"
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .mudCard()
    }

    // MARK: - Winner -

    private var winnerPanel: some View {
        MudPanel(title: L10n.tr("Winner")) {
            Button {
                openWinner(
                    CXRaces.Winner(
                        event: event,
                        result: winningResult
                    )
                )
            } label: {
                MudCardBox {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.tribuneru(.mudAccent))
                        VaporFlagView(url: event.winnerFlagURL ?? winningResult?.countryFlagURL)
                        VStack(alignment: .leading, spacing: 2) {
                            TribuneruText(
                                content: winnerName,
                                style: .vaporWinnerName,
                                color: .tribuneru(.mudTextPrimary),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: [L10n.tr("Men Elite"), event.winnerCountry, winningResult?.time]
                                    .compactMap { $0 }
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · "),
                                style: .vaporMeta,
                                color: .tribuneru(.mudTextSecondary),
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

    private func resultsPanel(_ allResults: [DTO.CX24Homepage.CategoryResult]) -> some View {
        MudPanel(title: L10n.tr("Results")) {
            MudCardBox {
                TribuneruText(
                    content: L10n.tr("MEN ELITE · TOP %lld", min(UI.resultsLimit, allResults.count)),
                    style: .vaporGroupLabel,
                    color: .tribuneru(.mudTextSecondary)
                )
                .padding(.bottom, 8)

                let results = Array(allResults.prefix(UI.resultsLimit))
                ForEach(results.indices, id: \.self) { index in
                    Button {
                        openResultRider(
                            CXRaces.RiderResult(
                                result: results[index],
                                event: event
                            )
                        )
                    } label: {
                        ResultRow(result: results[index])
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < results.count - 1 {
                        divider
                    }
                }

                if !allResults.isEmpty {
                    Button {
                        openFullResults(allResults)
                    } label: {
                        MudMoreLink(title: L10n.tr("full results"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("event-full-results")
                }
            }
        }
    }

    // MARK: - TV info -

    private func tvPanel(_ channels: [DTO.CXRacePage.TVChannel]) -> some View {
        MudPanel(title: L10n.tr("TV Info & Livestream")) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 10, alignment: .top)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(channels.indices, id: \.self) { index in
                    let channel = channels[index]
                    Button {
                        if let url = channel.url {
                            openURL(url)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            CachedImageView(
                                imageUrl: channel.logoURL,
                                cornerRadius: 8
                            )
                            .frame(height: 40)
                            TribuneruText(
                                content: channel.name,
                                style: .vaporMeta,
                                color: .tribuneru(.mudTextPrimary),
                                lineLimit: 2
                            )
                            .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.tribuneru(.mudCardSurface))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(
                                    Color.tribuneru(.mudTextPrimary).opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tv-channel-\(channel.name)")
                }
            }
        }
    }

    // MARK: - Past winners -

    private func pastWinnersPanel(_ winners: [DTO.CXRacePage.PastWinner]) -> some View {
        let winners = Array(winners.prefix(UI.pastWinnersLimit))
        return MudPanel(title: L10n.tr("Past winners")) {
            MudCardBox {
                ForEach(winners.indices, id: \.self) { index in
                    let winner = winners[index]
                    Button {
                        openPastWinner(
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
                                color: .tribuneru(.mudTextSecondary),
                                lineLimit: 1
                            )
                            .frame(width: 44, alignment: .leading)
                            VaporFlagView(url: winner.countryFlagURL)
                            TribuneruText(
                                content: winner.rider,
                                style: .vaporRaceNameResult,
                                color: .tribuneru(.mudTextPrimary),
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
        MudPanel(title: L10n.tr("About")) {
            MudCardBox {
                TribuneruText(
                    content: summary,
                    style: .vaporFeedDetail,
                    color: .tribuneru(.mudTextSecondary),
                    lineLimit: 8
                )
            }
        }
    }

    // MARK: - Links -

    private var linksPanel: some View {
        MudPanel(title: L10n.tr("Links")) {
            MudCardBox {
                let items = links
                ForEach(items.indices, id: \.self) { index in
                    let link = items[index]
                    Button {
                        link.handler()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: link.systemImage)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.tribuneru(.mudAccent))
                                .frame(width: 20)
                            TribuneruText(
                                content: link.title,
                                style: .vaporRaceNameNext,
                                color: .tribuneru(.mudTextPrimary),
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
                    title: L10n.tr("Race video"),
                    systemImage: "play.rectangle.fill"
                ) {
                    openURL(videoURL)
                }
            )
        }
        if let websiteURL = event.websiteURL {
            links.append(
                .init(
                    title: L10n.tr("Official website"),
                    systemImage: "globe"
                ) {
                    openURL(websiteURL)
                }
            )
        }
        return links
    }

    // MARK: - Helpers -

    private var divider: some View {
        TribunerosDivider(
            height: 0.5,
            color: Color.tribuneru(.mudTextPrimary).opacity(0.08)
        )
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.tribuneru(.mudTextSecondary))
    }

    private var formattedDate: String {
        guard let date = event.eventDate else { return event.date }
        return CXRaces.displayDate(date, pattern: "EEEE d MMMM yyyy")
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
        case 0: return L10n.tr("Today")
        case 1: return L10n.tr("Tomorrow")
        default: return L10n.tr("In %lld days", days)
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
            content: title.uppercased(with: L10n.locale),
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
            case .upcoming: L10n.tr("Upcoming")
            case .today: L10n.tr("Today")
            case .finished: L10n.tr("Finished")
            case .cancelled: L10n.tr("Cancelled")
            }
        }

        var color: Color {
            switch self {
            case .upcoming: .tribuneru(.mudTextSecondary)
            case .today: .tribuneru(.mudLive)
            case .finished: .tribuneru(.mudAccent)
            case .cancelled: .tribuneru(.mudNegative)
            }
        }
    }

    struct DetailLink {
        let title: String
        let systemImage: String
        let handler: () -> Void
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
                    .foregroundColor(.tribuneru(.mudTextSecondary))
                    .frame(width: 18)
                TribuneruText(
                    content: title,
                    style: .vaporMeta,
                    color: .tribuneru(.mudTextSecondary),
                    lineLimit: 1
                )
                .frame(width: 64, alignment: .leading)
                if let flagURL {
                    VaporFlagView(url: flagURL)
                }
                TribuneruText(
                    content: value,
                    style: .vaporRaceNameResult,
                    color: .tribuneru(.mudTextPrimary),
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
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 1
                )
                .frame(width: 22, alignment: .leading)
                VaporFlagView(url: result.countryFlagURL)
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: result.rider,
                        style: .vaporRaceNameResult,
                        color: .tribuneru(.mudTextPrimary),
                        lineLimit: 1
                    )
                    if !result.team.isEmpty {
                        TribuneruText(
                            content: result.team,
                            style: .vaporMeta,
                            color: .tribuneru(.mudTextSecondary),
                            lineLimit: 1
                        )
                    }
                }
                Spacer(minLength: 0)
                TribuneruText(
                    content: result.time,
                    style: .vaporFinishTime,
                    color: .tribuneru(.mudTextSecondary),
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
            title: "Middelkerke", // l10n:ignore
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
                // Never finishes, so the preview stays on the placeholders.
                try? await Task.sleep(for: .seconds(3600))
                return .empty
            }
        ) { _ in }
    }
}

#endif
