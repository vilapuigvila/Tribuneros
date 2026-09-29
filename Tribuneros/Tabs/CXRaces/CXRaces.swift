//
//  CXRaces.swift
//  Tribuneros
//
//  Created by albert vila on 5/1/26.
//

import Foundation

enum CXRaces { }

// MARK: - View Action -
extension CXRaces {
    enum Action {
        case didAppeared
        case didTapOnNextRaces
        case didTapOnLatestResults
        case didTapOnCalendarEvent(DTO.CXCalendarEvent)
        case didTapOnLink(URL)
        case didTapOnWinner(CXRaces.Winner, from: DTO.CXCalendarEvent)
        case didTapOnWinnerRace(DTO.CXCalendarEvent, openedFrom: DTO.CXCalendarEvent?)
        /// A "Recent results" row; `rider` is whose page it is, used when the row is a win.
        case didTapOnRiderResult(DTO.CXRiderPage.Result, rider: CXRaces.RiderRef)
        case didTapOnStandingRider(CXRaces.RiderStanding)
        case didTapOnPodiumRider(CXRaces.RiderPodium)
        case didTapOnResultRider(CXRaces.RiderResult)
        case didTapOnPastWinnerRider(CXRaces.Winner)
        case didTapOnRaceDetail(DTO.CX24Homepage.Race)
        case didTapOnStandings
    }
}

// MARK: - View State -
extension CXRaces {
    
    enum ViewState {
        case idle
        case loading
        case loaded(Representable)
        case error(CXRaces.ErrorView)
        
        var result: Representable {
            guard case .loaded(let result) = self else {
                return .init(calendarEvents: [], races: .init(sections: []), standings: .init(items: []))
            }
            return result
        }
        var isCalendarEventsEmpty: Bool { result.calendarEvents.isEmpty }
        var isRacesEmpty: Bool { result.races.sections.isEmpty }
    }
    
    struct Representable: Identifiable {
        let id = UUID()
        let calendarEvents: [DTO.CXCalendarEvent]
        let races: DTO.CX24Homepage
        let standings: DTO.CXStandings
        
        func nextThreeEvents() -> [DTO.CXCalendarEvent] {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())

            return calendarEvents
                .compactMap { event -> (DTO.CXCalendarEvent, Date)? in
                    guard let eventDate = event.eventDate else { return nil }
                    return (event, eventDate)
                }
                .filter { _, eventDate in
                    eventDate >= startOfToday   // today or later
                }
                .sorted { $0.1 < $1.1 }         // sort by date ascending
                .prefix(3)
                .map { $0.0 }                   // back to [CXCalendarEvent]
        }
    }
}

// MARK: - Race series (calendar filters) -
extension CXRaces {

    /// The kind of race a calendar event belongs to, used by the "All races" filter chips.
    /// cyclocross24 has no series field, so it's inferred from the race name and UCI class.
    enum RaceSeries: String, CaseIterable, Identifiable, Hashable {
        case worldCup
        case superprestige
        case x2oTrofee
        case exactCross
        case championships
        case otherBelgian
        case others

        var id: String { rawValue }

        var title: String {
            switch self {
            case .worldCup: "World Cup"
            case .superprestige: "Superprestige"
            case .x2oTrofee: "X2O Trofee"
            case .exactCross: "Exact Cross"
            case .championships: "Championships"
            case .otherBelgian: "Other Belgian"
            case .others: "Others"
            }
        }

        /// Checked in declaration order, so a series match wins over "Belgian".
        static func of(race name: String, raceClass: String, country: String?) -> RaceSeries {
            let name = name.lowercased()
            let raceClass = raceClass.uppercased().trimmingCharacters(in: .whitespaces)
            if name.contains("world cup") || raceClass == "CDM" {
                return .worldCup
            }
            if name.contains("superprestige") {
                return .superprestige
            }
            if name.contains("x2o") || name.contains("badkamers") || name.contains("trofee") {
                return .x2oTrofee
            }
            if name.contains("exact cross") || name.contains("exactcross") {
                return .exactCross
            }
            if name.contains("championship") || ["CM", "CN", "CC"].contains(raceClass) {
                return .championships
            }
            if country?.caseInsensitiveCompare("Belgium") == .orderedSame {
                return .otherBelgian
            }
            return .others
        }
    }

    /// UCI class codes as shown on cyclocross24, spelled out for the detail screen.
    static func raceClassDescription(_ raceClass: String) -> String? {
        switch raceClass.uppercased().trimmingCharacters(in: .whitespaces) {
        case "CDM": "UCI World Cup"
        case "CM": "UCI World Championships"
        case "CC": "Continental Championships"
        case "CN": "National Championships"
        case "C1": "UCI Class 1"
        case "C2": "UCI Class 2"
        case "C3": "UCI Class 3"
        default: nil
        }
    }
}

// MARK: - Winner -
extension CXRaces {

    /// Everything the winner screen needs, built either from a calendar event's winner (this
    /// season) or from a past edition listed on the race page.
    struct Winner: Hashable {
        let name: String
        let riderURL: URL?
        let flagURL: URL?
        let country: String?
        let race: String
        let raceFlagURL: URL?
        let raceClass: String
        let series: RaceSeries
        /// A full date for this season's winner, only the year for a past edition.
        let dateText: String
        /// The winning edition's results page; the screen loads `result` from it when missing.
        let resultsURL: URL?
        /// The winner's results row (time, team, age), when the caller already has it.
        let result: DTO.CX24Homepage.CategoryResult?
        /// The winning edition as a calendar event, to open it in `CXEventDetailView`.
        let raceEvent: DTO.CXCalendarEvent

        init(
            event: DTO.CXCalendarEvent,
            result: DTO.CX24Homepage.CategoryResult?
        ) {
            name = event.winnerName.isEmpty ? (result?.rider ?? "") : event.winnerName
            riderURL = event.winnerURL ?? result?.riderURL
            flagURL = event.winnerFlagURL ?? result?.countryFlagURL
            country = event.winnerCountry
            race = event.race
            raceFlagURL = event.flagURL
            raceClass = event.raceClass
            series = event.series
            dateText = event.eventDate.map { WinnerDate.formatter.string(from: $0) } ?? event.date
            resultsURL = event.resultsURL
            self.result = result
            raceEvent = event
        }

        init(
            event: DTO.CXCalendarEvent,
            pastWinner: DTO.CXRacePage.PastWinner
        ) {
            name = pastWinner.rider
            riderURL = pastWinner.riderURL
            flagURL = pastWinner.countryFlagURL
            country = nil
            race = event.race
            raceFlagURL = event.flagURL
            raceClass = event.raceClass
            series = event.series
            dateText = pastWinner.year
            resultsURL = pastWinner.resultsURL
            result = nil
            // Same race, that edition's winner and results. Only the year is known, so the detail
            // shows it as the date; the winner name marks the edition as finished.
            let resultsID = pastWinner.resultsURL?.path
                .split(separator: "/")
                .last
                .flatMap { Int($0) }
            raceEvent = .init(
                date: pastWinner.year,
                race: event.race,
                raceClass: event.raceClass,
                flagURL: event.flagURL,
                winnerName: pastWinner.rider,
                isCancelled: false,
                raceID: resultsID,
                raceSlug: event.raceSlug,
                raceURL: event.raceURL,
                resultsURL: pastWinner.resultsURL,
                videoURL: nil,
                websiteURL: event.websiteURL,
                raceCountry: event.raceCountry,
                winnerURL: pastWinner.riderURL,
                winnerCountry: nil,
                winnerFlagURL: pastWinner.countryFlagURL
            )
        }

        /// A win in a rider's "Recent results": the rider is known from their screen, the race
        /// is `raceEvent` (from `CXRaces.calendarEvent(for:in:)`). The time, team and age load from
        /// the race's results page, like a past winner's.
        init(
            riderResult: DTO.CXRiderPage.Result,
            rider: RiderRef,
            raceEvent: DTO.CXCalendarEvent
        ) {
            name = rider.name
            riderURL = rider.riderURL
            flagURL = rider.flagURL
            country = rider.country
            race = raceEvent.race
            raceFlagURL = raceEvent.flagURL
            raceClass = raceEvent.raceClass
            series = raceEvent.series
            dateText = raceEvent.eventDate.map { WinnerDate.formatter.string(from: $0) } ?? riderResult.date
            resultsURL = raceEvent.resultsURL
            result = nil
            // A race built from the row has no winner yet; give it this rider so its detail
            // shows them before the results load.
            self.raceEvent = raceEvent.winnerName.isEmpty
                ? raceEvent.withWinner(rider)
                : raceEvent
        }
    }

    /// Who a rider screen is about, as shown on it: enough to open the winner screen for one of
    /// their wins.
    struct RiderRef: Hashable {
        let name: String
        let riderURL: URL?
        let flagURL: URL?
        let country: String?
    }

    private enum WinnerDate {
        static let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMMM yyyy"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }()
    }
}

// MARK: - Rider standing -
extension CXRaces {

    /// A rider's place in one standings table (e.g. UCI Ranking, Men Elite), what the rider
    /// screen opened from the Standings list shows alongside the rider page.
    struct RiderStanding: Hashable {
        let rider: String
        let riderURL: URL?
        let flagURL: URL?
        let position: Int
        let points: String
        let rankingTitle: String
        let rankingLogoURL: URL?
        let category: String
        /// The standings table itself (the category's page, else the ranking's).
        let standingsURL: URL?

        init(
            leader: DTO.CXStandings.Leader,
            category: DTO.CXStandings.Category,
            item: DTO.CXStandings.Item
        ) {
            rider = leader.rider
            riderURL = leader.riderURL
            flagURL = leader.countryFlagURL
            position = leader.position
            points = leader.points
            rankingTitle = item.title
            rankingLogoURL = item.logoURL
            self.category = category.title
            standingsURL = category.url ?? item.url
        }
    }
}

// MARK: - Rider podium -
extension CXRaces {

    /// A rider's podium place in one category of a latest-results race, what the rider screen
    /// opened from the Latest results rows shows alongside the rider page.
    struct RiderPodium: Hashable {
        let rider: String
        let riderURL: URL?
        let flagURL: URL?
        let country: String
        let position: Int
        let time: String
        let category: String
        /// The whole race, so the rider screen can open its results.
        let race: DTO.CX24Homepage.Race

        init(
            podium: DTO.CX24Homepage.Podium,
            category: DTO.CX24Homepage.Category,
            race: DTO.CX24Homepage.Race
        ) {
            rider = podium.rider
            riderURL = podium.riderURL
            flagURL = podium.countryFlagURL
            country = podium.country
            position = podium.position
            time = podium.time
            self.category = category.title
            self.race = race
        }
    }

    /// A rider's row in a race's full results (a race opened from Latest results, or a calendar
    /// race's Men Elite top 10).
    struct RiderResult: Hashable {
        let result: DTO.CX24Homepage.CategoryResult
        let category: String
        let raceTitle: String
        let raceFlagURL: URL?
        /// "4 January 2026 · Zonhoven, Belgium", or whatever the opening screen knows.
        let raceMeta: String

        init(
            result: DTO.CX24Homepage.CategoryResult,
            category: String,
            race: DTO.CX24Homepage.Race
        ) {
            self.result = result
            self.category = category
            raceTitle = race.title
            raceFlagURL = race.countryFlagURL
            raceMeta = [race.date, race.location]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }

        init(
            result: DTO.CX24Homepage.CategoryResult,
            event: DTO.CXCalendarEvent
        ) {
            self.result = result
            category = "Men Elite"
            raceTitle = event.race
            raceFlagURL = event.flagURL
            raceMeta = [event.date, event.raceCountry ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
    }

    /// Where the rider screen was opened from, which decides its context panel.
    enum RiderContext: Hashable {
        case standing(RiderStanding)
        case podium(RiderPodium)
        case result(RiderResult)
        /// A past edition's winner, from a race's "Past winners" list.
        case win(Winner)

        var rider: String {
            switch self {
            case .standing(let standing): standing.rider
            case .podium(let podium): podium.rider
            case .result(let result): result.result.rider
            case .win(let winner): winner.name
            }
        }

        var riderURL: URL? {
            switch self {
            case .standing(let standing): standing.riderURL
            case .podium(let podium): podium.riderURL
            case .result(let result): result.result.riderURL
            case .win(let winner): winner.riderURL
            }
        }

        var flagURL: URL? {
            switch self {
            case .standing(let standing): standing.flagURL
            case .podium(let podium): podium.flagURL
            case .result(let result): result.result.countryFlagURL
            case .win(let winner): winner.flagURL
            }
        }

        var position: String {
            switch self {
            case .standing(let standing): "\(standing.position)"
            case .podium(let podium): "\(podium.position)"
            case .result(let result): result.result.position
            case .win: "1"
            }
        }

        var category: String {
            switch self {
            case .standing(let standing): standing.category
            case .podium(let podium): podium.category
            case .result(let result): result.category
            case .win: "Men Elite"
            }
        }

        /// Known before the rider page loads: only podiums carry a country name.
        var country: String? {
            switch self {
            case .standing, .result: nil
            case .podium(let podium): podium.country.isEmpty ? nil : podium.country
            case .win(let winner): winner.country
            }
        }

        /// A past win's results page, when its winning row (time, team, age) still has to load.
        var winResultsURL: URL? {
            guard case .win(let winner) = self, winner.result == nil else { return nil }
            return winner.resultsURL
        }

        /// Known before the rider page loads: only results carry a team.
        var team: String? {
            switch self {
            case .standing, .podium, .win: nil
            case .result(let result): result.result.team.isEmpty ? nil : result.result.team
            }
        }
    }
}

// MARK: - Rider result → calendar event -
extension CXRaces {

    /// The calendar event a rider-page result points at: this season's calendar entry when one
    /// matches (by results/race link, then by date and name), otherwise a minimal event built from
    /// the result itself, enough for `CXEventDetailView` to load that race's results.
    static func calendarEvent(
        for result: DTO.CXRiderPage.Result,
        in calendar: [DTO.CXCalendarEvent]
    ) -> DTO.CXCalendarEvent {
        let date = normalizedCalendarDate(result.date)
        let path = result.raceURL.map(normalizedPath)

        if let path, let match = calendar.first(where: { event in
            [event.resultsURL, event.raceURL].contains { $0.map(normalizedPath) == path }
        }) {
            return match
        }
        let name = result.race.lowercased()
        if let match = calendar.first(where: { event in
            event.date == date
                && (event.race.lowercased().contains(name) || name.contains(event.race.lowercased()))
        }) {
            return match
        }

        // `/race/<numeric id>/` is a results page, `/race/<slug>/` the race page.
        let components = path?.split(separator: "/").map(String.init) ?? []
        let raceID = components.count >= 2 && components[0] == "race" ? Int(components[1]) : nil
        return .init(
            date: date,
            race: result.race,
            raceClass: "",
            flagURL: nil,
            winnerName: "",
            isCancelled: false,
            raceID: raceID,
            raceSlug: raceID == nil && components.count >= 2 ? components[1] : nil,
            raceURL: raceID == nil ? result.raceURL : nil,
            resultsURL: raceID != nil ? result.raceURL : nil,
            videoURL: nil,
            websiteURL: nil,
            raceCountry: nil,
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
    }

    /// Rider pages may write "4.1.2026" or "04/01/2026"; the calendar uses "04-01-2026".
    private static func normalizedCalendarDate(_ date: String) -> String {
        let parts = date.split { "-./".contains($0) }.map(String.init)
        guard parts.count == 3 else { return date }
        let pad = { (part: String) in part.count == 1 ? "0" + part : part }
        return "\(pad(parts[0]))-\(pad(parts[1]))-\(parts[2])"
    }
}

extension DTO.CXCalendarEvent {
    /// The same event with `rider` as its winner.
    func withWinner(_ rider: CXRaces.RiderRef) -> Self {
        .init(
            date: date,
            race: race,
            raceClass: raceClass,
            flagURL: flagURL,
            winnerName: rider.name,
            isCancelled: isCancelled,
            raceID: raceID,
            raceSlug: raceSlug,
            raceURL: raceURL,
            resultsURL: resultsURL,
            videoURL: videoURL,
            websiteURL: websiteURL,
            raceCountry: raceCountry,
            winnerURL: rider.riderURL,
            winnerCountry: rider.country,
            winnerFlagURL: rider.flagURL
        )
    }

    var series: CXRaces.RaceSeries {
        .of(
            race: race,
            raceClass: raceClass,
            country: raceCountry
        )
    }
}

// MARK: - ErrorView -
extension CXRaces {
    enum ErrorView: Error {
        case unknown
    }
}
