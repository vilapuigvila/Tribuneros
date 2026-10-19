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

        static let roundsLeftLimit = 3

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

// MARK: - Rider initials -
extension CXRaces {

    /// "VAN DER POEL Mathieu" → "MV": cyclocross24 writes the surname first, in capitals.
    static func riderInitials(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let surname = words.first, let given = words.last else { return "" }
        return String(given.prefix(1) + surname.prefix(1)).uppercased()
    }
}
