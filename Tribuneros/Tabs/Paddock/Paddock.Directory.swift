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

    /// The pushed races list's switch: PCS's men's calendar or its Women's WorldTour (`races.php?circuit=24`).
    enum RaceCircuit: CaseIterable, Hashable, Sendable {
        case men
        case women

        var title: String {
            switch self {
            case .men: L10n.tr("Men")
            case .women: L10n.tr("Women")
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
        /// Last day of a stage race ("24 Jan"); nil for a one-day race or when PCS gave no range.
        var endDate: Date? = nil
        var endLabel: String? = nil
        /// The edition's year, from the path ("race/tour-down-under-2027"), else from the start date.
        var season: Int? = nil

        static let placeholders: [RaceItem] = (1...3).map { index in
            RaceItem(
                path: "placeholder-\(index)",
                name: "Race name placeholder", // l10n:ignore: redacted stand-in
                dateLabel: "00 Jan", // l10n:ignore: redacted stand-in
                raceClass: "2.UWT", // l10n:ignore: redacted stand-in
                countryCode: "",
                startDate: nil,
                endDate: nil,
                endLabel: "00 Jan", // l10n:ignore: redacted stand-in
                season: 2027
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
        let year = pathYear(race.path)
        let start = raceStart(
            from: race.dateText,
            now: now,
            calendar: calendar,
            year: year
        )
        let end = raceEnd(
            from: race.dateText,
            now: now,
            calendar: calendar,
            year: year
        )
        let formatter = L10n.dateFormatter(template: "d MMM")
        return RaceItem(
            path: race.path,
            name: race.name,
            dateLabel: start.map { formatter.string(from: $0) } ?? race.dateText,
            raceClass: race.raceClass,
            countryCode: race.countryCode,
            startDate: start,
            endDate: end,
            endLabel: end.map { formatter.string(from: $0) },
            season: year ?? start.map { calendar.component(.year, from: $0) }
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
        guard let first = dateParts(text).first else { return nil }
        return day(first, now: now, calendar: calendar, year: year)
    }

    /// The last day of a range ("19.01 - 24.01" → 24 Jan); nil for a single date. A range that runs past
    /// New Year ("28.12 - 03.01") ends in the following year.
    static func raceEnd(
        from text: String,
        now: Date,
        calendar: Calendar,
        year: Int? = nil
    ) -> Date? {
        let parts = dateParts(text)
        guard parts.count == 2,
              let start = day(parts[0], now: now, calendar: calendar, year: year),
              let end = day(parts[1], now: now, calendar: calendar, year: year)
        else {
            return nil
        }
        if end < start {
            return calendar.date(byAdding: .year, value: 1, to: end)
        }
        return end
    }

    /// "19.01 - 24.01" → ["19.01", "24.01"]; a hyphen only splits when spaced, so "2027-01-19" stays whole.
    private static func dateParts(_ text: String) -> [String] {
        let spaced = text.contains(" - ")
        let parts = text
            .split(whereSeparator: { $0 == "-" && spaced || $0 == "–" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? [text] : parts
    }

    private static func day(
        _ text: String,
        now: Date,
        calendar: Calendar,
        year: Int?
    ) -> Date? {
        for format in ["yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy"] {
            if let date = parse(text, format: format, calendar: calendar) {
                return date
            }
        }
        let parts = text.split(whereSeparator: { $0 == "." || $0 == "/" }).compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var components = calendar.dateComponents([.year], from: now)
        components.year = year ?? components.year
        components.day = parts[0]
        components.month = parts[1]
        return calendar.date(from: components)
    }

    /// The calendar lists next season's races from the autumn, so the year comes from the slug, not the clock.
    /// PCS sometimes adds a digit to the year ("tour-de-france-femmes-20271"): the first four digits are the year.
    static func pathYear(_ path: String) -> Int? {
        guard let last = path.split(separator: "-").last,
              last.count == 4 || last.count == 5,
              last.allSatisfy(\.isNumber)
        else {
            return nil
        }
        return Int(last.prefix(4)).flatMap { (1900...2100).contains($0) ? $0 : nil }
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

// MARK: - Pushed races list -

extension Paddock {

    /// State of the pushed races list: which circuit is selected and the women's calendar, which is only fetched
    /// the first time "Women" is picked (the men's rows come from the Paddock screen's own state).
    @MainActor
    final class RacesListModel: ObservableObject {
        @Published var circuit: RaceCircuit = .men
        @Published private(set) var women: Listing<RaceItem> = .loading

        private let fetchWomen: () async -> [DTO.PCSRace]?
        private var task: Task<Void, Never>?

        init(fetchWomen: @escaping () async -> [DTO.PCSRace]? = { await Service.getPCSWomenRaces() }) {
            self.fetchWomen = fetchWomen
        }

        func select(_ circuit: RaceCircuit) {
            self.circuit = circuit
            if circuit == .women {
                loadWomen()
            }
        }

        /// Starts the women's fetch unless it is running or already loaded; a failed one is tried again.
        func loadWomen(
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            guard task == nil else { return }
            if case .loaded = women { return }
            if case .failed = women { women = .loading }
            task = Task { [weak self, fetchWomen] in
                let races = await fetchWomen()
                guard let self else { return }
                if let races {
                    self.women = Listing<RaceItem>.loaded(
                        races.map { Paddock.raceItem(from: $0, now: now, calendar: calendar) }
                    )
                } else {
                    self.women = Listing<RaceItem>.failed
                }
                self.task = nil
            }
        }
    }
}
