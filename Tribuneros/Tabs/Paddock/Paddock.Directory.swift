//
//  Paddock.Directory.swift
//  Tribuneros
//
//  Paddock's "Races | Teams" section: types the view state carries and the mapping from the
//  scraped PCS rows. The section previews three rows; "See all" pushes the full list.
//

import Foundation

extension Paddock {

    /// The two sides of the directory section's segmented control.
    enum Directory: CaseIterable, Hashable, Sendable {
        case races
        case teams

        var title: String {
            switch self {
            case .races: L10n.tr("Races")
            case .teams: L10n.tr("Teams")
            }
        }

        var seeAllTitle: String {
            switch self {
            case .races: L10n.tr("See all races")
            case .teams: L10n.tr("See all teams")
            }
        }
    }

    /// One side's rows while they load, once loaded, or when the page couldn't be read.
    enum Listing<Item: Equatable & Sendable>: Equatable {
        case loading
        case loaded([Item])
        case failed

        var items: [Item] {
            if case .loaded(let items) = self { return items }
            return []
        }
    }

    struct RaceItem: Identifiable, Equatable, Hashable, Sendable {
        var id: String { path }
        let path: String
        let name: String
        /// "20 Jan", or PCS's own text when it isn't a date we can read.
        let dateLabel: String
        let raceClass: String
        let countryCode: String
        let startDate: Date?

        static let placeholders: [RaceItem] = (1...3).map { index in
            RaceItem(
                path: "placeholder-\(index)",
                name: "Race name placeholder", // l10n:ignore: redacted stand-in
                dateLabel: "00 Jan", // l10n:ignore: redacted stand-in
                raceClass: "2.UWT", // l10n:ignore: redacted stand-in
                countryCode: "",
                startDate: nil
            )
        }
    }

    struct TeamItem: Identifiable, Equatable, Hashable, Sendable {
        var id: String { path }
        let path: String
        let name: String
        let division: String
        let countryCode: String

        /// "UAE Team Emirates - XRG" → "UT": the circle's stand-in logo, like the press monogram.
        var monogram: String {
            let words = name
                .split { !$0.isLetter && !$0.isNumber }
                .filter { !$0.isEmpty }
            let letters = words.count > 1
                ? words.prefix(2).compactMap(\.first).map(String.init).joined()
                : String(words.first?.prefix(2) ?? "")
            return letters.uppercased()
        }

        static let placeholders: [TeamItem] = (1...3).map { index in
            TeamItem(
                path: "placeholder-\(index)",
                name: "Team name placeholder", // l10n:ignore: redacted stand-in
                division: "WorldTour", // l10n:ignore: redacted stand-in
                countryCode: ""
            )
        }
    }

    /// The teams of one division ("UCI WorldTeams", "UCI ProTeams"), in page order, for the full list's sections.
    struct TeamGroup: Identifiable, Equatable, Sendable {
        var id: String { division }
        /// PCS's heading; "" for teams the page listed under no heading.
        let division: String
        let teams: [TeamItem]

        /// The segment's title: PCS's heading, or "Teams" for the unheaded group.
        var title: String { division.isEmpty ? L10n.tr("Teams") : division }
    }

    /// Splits the teams by division, keeping the order of first appearance and each division's own order.
    static func teamGroups(_ teams: [TeamItem]) -> [TeamGroup] {
        var order: [String] = []
        var byDivision: [String: [TeamItem]] = [:]
        for team in teams {
            if byDivision[team.division] == nil { order.append(team.division) }
            byDivision[team.division, default: []].append(team)
        }
        return order.map { TeamGroup(division: $0, teams: byDivision[$0] ?? []) }
    }

    /// The season the list is for: the year most team paths end in ("team/lidl-trek-2026"), nil when none do.
    static func teamsSeason(_ teams: [TeamItem]) -> Int? {
        let counts = teams.compactMap { pathYear($0.path) }.reduce(into: [Int: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }

    /// Rows the section shows before "See all".
    static let directoryPreviewLimit = 3

    /// The next races first: the first rows dated today or later, else the first rows of the list.
    static func previewRaces(
        _ races: [RaceItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [RaceItem] {
        let today = calendar.startOfDay(for: now)
        let upcoming = races.filter { ($0.startDate ?? .distantPast) >= today }
        return Array((upcoming.isEmpty ? races : upcoming).prefix(directoryPreviewLimit))
    }

    // MARK: - Mapping from the scraped rows -

    static func raceItem(
        from race: DTO.PCSRace,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RaceItem {
        let start = raceStart(
            from: race.dateText,
            now: now,
            calendar: calendar,
            year: pathYear(race.path)
        )
        return RaceItem(
            path: race.path,
            name: race.name,
            dateLabel: start.map { L10n.dateFormatter(template: "d MMM").string(from: $0) } ?? race.dateText,
            raceClass: race.raceClass,
            countryCode: race.countryCode,
            startDate: start
        )
    }

    static func teamItem(from team: DTO.PCSTeam) -> TeamItem {
        TeamItem(
            path: team.path,
            name: team.name,
            division: team.division,
            countryCode: team.countryCode
        )
    }

    /// PCS prints "19.01" (no year: the one in the race path, else the current one) or "2027-01-19"; a range
    /// ("19.01 - 24.01") starts on its first date.
    static func raceStart(
        from text: String,
        now: Date,
        calendar: Calendar,
        year: Int? = nil
    ) -> Date? {
        let first = text
            .split(whereSeparator: { $0 == "-" && text.contains(" - ") || $0 == "–" })
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? text
        for format in ["yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy"] {
            if let date = parse(first, format: format, calendar: calendar) {
                return date
            }
        }
        let parts = first.split(whereSeparator: { $0 == "." || $0 == "/" }).compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var components = calendar.dateComponents([.year], from: now)
        components.year = year ?? components.year
        components.day = parts[0]
        components.month = parts[1]
        return calendar.date(from: components)
    }

    /// The calendar lists next season's races from the autumn, so the year comes from the slug, not the clock.
    static func pathYear(_ path: String) -> Int? {
        path.split(separator: "-").last.flatMap { Int($0) }.flatMap { (1900...2100).contains($0) ? $0 : nil }
    }

    private static func parse(
        _ text: String,
        format: String,
        calendar: Calendar
    ) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.date(from: text)
    }
}
