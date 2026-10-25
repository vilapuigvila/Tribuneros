//
//  CXRaces.SeriesLens.swift
//  Tribuneros
//

import Foundation

extension CXRaces {

    /// What the CX Zone screen shows for one race series: its rounds from the calendar, the
    /// next and last one, the leaders of its standings and the last round's podium.
    struct SeriesLens {

        struct Round: Identifiable, Equatable {
            /// 1-based place in the series' season calendar.
            let number: Int
            let event: DTO.CXCalendarEvent
            let date: Date

            var id: Int { number }
        }

        struct Leader: Identifiable, Equatable {
            let standing: RiderStanding
            let imageURL: URL?
            /// Points ahead of second place; `nil` when the standing isn't plain points.
            let gap: String?

            var id: String { standing.category }
        }

        struct LastPodium: Equatable {
            let race: DTO.CX24Homepage.Race
            let category: DTO.CX24Homepage.Category

            var podium: [DTO.CX24Homepage.Podium] { Array(category.podium.prefix(3)) }
        }

        static let roundsLeftLimit = 2

        let series: RaceSeries
        let rounds: [Round]
        let doneCount: Int
        let nextRound: Round?
        let lastRound: Round?
        let leaders: [Leader]
        let lastPodium: LastPodium?

        init(
            series: RaceSeries,
            representable: Representable,
            now: Date = Date()
        ) {
            let startOfToday = Calendar.current.startOfDay(for: now)
            let dated = representable.calendarEvents
                .filter { !$0.isCancelled && $0.series == series }
                .compactMap { event in event.eventDate.map { (event, $0) } }
                .sorted { $0.1 < $1.1 }
            let rounds = dated.enumerated().map { index, pair in
                Round(number: index + 1, event: pair.0, date: pair.1)
            }
            self.series = series
            self.rounds = rounds
            doneCount = rounds.filter { $0.date < startOfToday }.count
            nextRound = rounds.first { $0.date >= startOfToday }
            lastRound = rounds.last { $0.date < startOfToday }
            leaders = Self.leaders(of: series, in: representable.standings)
            lastPodium = lastRound.flatMap {
                Self.podium(of: $0.event, in: representable.races)
            }
        }

        var roundsLeft: [Round] {
            guard let nextRound else { return [] }
            return rounds
                .filter { $0.number > nextRound.number }
                .prefix(Self.roundsLeftLimit)
                .map { $0 }
        }

        /// Whole days from today to `round`, 0 on the day itself.
        func days(
            to round: Round,
            now: Date = Date()
        ) -> Int {
            let calendar = Calendar.current
            return calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: now),
                to: calendar.startOfDay(for: round.date)
            ).day ?? 0
        }
    }
}

// MARK: - Series available this season -
extension CXRaces.SeriesLens {

    /// The series with at least one round on the calendar, in the chips' order.
    static func availableSeries(in calendarEvents: [DTO.CXCalendarEvent]) -> [CXRaces.RaceSeries] {
        let present = Set(
            calendarEvents
                .filter { !$0.isCancelled && $0.eventDate != nil }
                .map(\.series)
        )
        return CXRaces.RaceSeries.allCases.filter { present.contains($0) }
    }

    /// "2026–27": the season starts in July, like the calendar scrape's season.
    static func seasonLabel(now: Date = Date()) -> String {
        let components = Calendar.current.dateComponents([.year, .month], from: now)
        let year = components.year ?? 0
        let start = (components.month ?? 1) >= 7 ? year : year - 1
        return String(format: "%d–%02d", start, (start + 1) % 100)
    }
}

// MARK: - Standings and podium lookups -
extension CXRaces.SeriesLens {

    /// Words in a standings title that tie it to a series; the series without one have no table.
    private static func standingsKeywords(of series: CXRaces.RaceSeries) -> [String] {
        switch series {
        case .worldCup: ["world cup"]
        case .superprestige: ["superprestige"]
        case .x2oTrofee: ["x2o", "trofee"]
        case .exactCross: ["exact cross", "exactcross"]
        case .championships, .otherBelgian, .others: []
        }
    }

    private static func leaders(
        of series: CXRaces.RaceSeries,
        in standings: DTO.CXStandings
    ) -> [Leader] {
        let keywords = standingsKeywords(of: series)
        guard !keywords.isEmpty,
              let item = standings.items.first(where: { item in
                  let title = item.title.lowercased()
                  return keywords.contains { title.contains($0) }
              }) else { return [] }
        return item.categories
            .filter { !$0.leaders.isEmpty }
            .prefix(2)
            .map { category in
                let first = category.leaders[0]
                let second = category.leaders.dropFirst().first
                return Leader(
                    standing: CXRaces.RiderStanding(
                        leader: first,
                        category: category,
                        item: item
                    ),
                    imageURL: category.leaderImageURL,
                    gap: gap(first: first, second: second)
                )
            }
    }

    private static func gap(
        first: DTO.CXStandings.Leader,
        second: DTO.CXStandings.Leader?
    ) -> String? {
        guard let second,
              let firstPoints = Int(first.points),
              let secondPoints = Int(second.points) else { return nil }
        return "+\(firstPoints - secondPoints)"
    }

    /// The homepage's latest result for `event`, matched by race name, with its Men Elite
    /// category (else the first one).
    private static func podium(
        of event: DTO.CXCalendarEvent,
        in homepage: DTO.CX24Homepage
    ) -> LastPodium? {
        let name = event.race.lowercased()
        let races = homepage.sections.flatMap(\.races)
        guard let race = races.first(where: { race in
            let title = race.title.lowercased()
            return title == name || title.contains(name) || name.contains(title)
        }) else { return nil }
        let category = race.categories.first {
            $0.title.caseInsensitiveCompare("Men Elite") == .orderedSame && !$0.podium.isEmpty
        } ?? race.categories.first { !$0.podium.isEmpty }
        return category.map { LastPodium(race: race, category: $0) }
    }
}

// MARK: - Next to start -
extension CXRaces.SeriesLens {

    struct Upcoming: Equatable {
        let event: DTO.CXCalendarEvent
        /// Whole days from today, 0 on the day itself.
        let days: Int
    }

    /// Races inside this many days feature in the dock.
    static let featuredWindowDays = 7

    /// Men Elite lasts about an hour; the race counts as over this long after its start.
    static let menEliteDuration: TimeInterval = 60 * 60

    /// The usual Men Elite slot, assumed when the race page has no schedule.
    static let fallbackMenEliteStart = "15:00"

    /// Race schedules by the event's race page URL.
    typealias Schedules = [URL: [DTO.CXRacePage.ScheduledStart]]

    /// The soonest non-cancelled race of any series that is not over yet, if it is today or within the window.
    static func upcoming(
        in calendarEvents: [DTO.CXCalendarEvent],
        schedules: Schedules = [:],
        now: Date = Date()
    ) -> Upcoming? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let next = calendarEvents
            .filter { !$0.isCancelled }
            .compactMap { event in event.eventDate.map { (event, $0) } }
            .filter { $0.1 >= startOfToday }
            .filter { event, date in
                guard date < calendar.date(byAdding: .day, value: 1, to: startOfToday)! else { return true }
                return !isMenEliteOver(event, schedule: event.raceURL.flatMap { schedules[$0] }, now: now)
            }
            .min { $0.1 < $1.1 }
        guard let next else { return nil }
        let days = calendar.dateComponents(
            [.day],
            from: startOfToday,
            to: calendar.startOfDay(for: next.1)
        ).day ?? 0
        guard days <= featuredWindowDays else { return nil }
        return Upcoming(
            event: next.0,
            days: days
        )
    }

    /// A race day is over once the calendar lists a winner or Men Elite started more than an hour ago.
    static func isMenEliteOver(
        _ event: DTO.CXCalendarEvent,
        schedule: [DTO.CXRacePage.ScheduledStart]?,
        now: Date
    ) -> Bool {
        if !event.winnerName.isEmpty { return true }
        guard let start = menEliteStart(of: event, schedule: schedule) else { return false }
        return now >= start.addingTimeInterval(menEliteDuration)
    }

    /// The Men Elite start in the venue's time zone: its schedule row, else the last row, else 15:00.
    static func menEliteStart(
        of event: DTO.CXCalendarEvent,
        schedule: [DTO.CXRacePage.ScheduledStart]?
    ) -> Date? {
        guard let eventDate = event.eventDate else { return nil }
        let row = schedule?.first { $0.category.caseInsensitiveCompare("Men Elite") == .orderedSame }
            ?? schedule?.last
        let parts = (row?.time ?? fallbackMenEliteStart).split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        var venueCalendar = Calendar(identifier: .gregorian)
        venueCalendar.timeZone = venueTimeZone(country: event.raceCountry)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: eventDate)
        components.hour = parts[0]
        components.minute = parts[1]
        return venueCalendar.date(from: components)
    }

    /// Exact US zones aren't worth more than one.
    static func venueTimeZone(country: String?) -> TimeZone {
        let identifier = switch country?.lowercased() {
        case "great britain", "ireland": "Europe/London"
        case "united states": "America/New_York"
        case "canada": "America/Toronto"
        default: "Europe/Brussels"
        }
        return TimeZone(identifier: identifier) ?? .current
    }
}

// MARK: - Latest result -
extension CXRaces.SeriesLens {

    /// The first race of the first non-empty section: cyclocross24 lists the newest first.
    static func latestRace(in homepage: DTO.CX24Homepage) -> DTO.CX24Homepage.Race? {
        homepage.sections.first { !$0.races.isEmpty }?.races.first
    }

    /// The other races on the homepage, shown as "+N" beside the latest one.
    static func otherLatestResultCount(in homepage: DTO.CX24Homepage) -> Int {
        max(homepage.sections.reduce(0) { $0 + $1.races.count } - 1, 0)
    }

    /// The Men Elite winner of a race, else the first category's winner.
    static func winner(of race: DTO.CX24Homepage.Race) -> DTO.CX24Homepage.Podium? {
        let category = race.categories.first {
            $0.title.caseInsensitiveCompare("Men Elite") == .orderedSame && !$0.podium.isEmpty
        } ?? race.categories.first { !$0.podium.isEmpty }
        return category?.podium.first
    }
}

// MARK: - Rider initials -
extension CXRaces {

    /// "VAN DER POEL Mathieu" → "MV": cyclocross24 writes the surname first, in capitals.
    static func riderInitials(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let surname = words.first, let given = words.last else { return "" }
        return String(given.prefix(1) + surname.prefix(1)).uppercased()
    }
}
