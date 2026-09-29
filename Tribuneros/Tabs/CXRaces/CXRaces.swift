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
        case didTapOnWinner(CXRaces.Winner)
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

        init(
            event: DTO.CXCalendarEvent,
            result: DTO.CX24Homepage.CategoryResult?
        ) {
            name = event.winnerName
            riderURL = event.winnerURL
            flagURL = event.winnerFlagURL ?? result?.countryFlagURL
            country = event.winnerCountry
            race = event.race
            raceFlagURL = event.flagURL
            raceClass = event.raceClass
            series = event.series
            dateText = event.eventDate.map { WinnerDate.formatter.string(from: $0) } ?? event.date
            resultsURL = event.resultsURL
            self.result = result
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
        }
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

extension DTO.CXCalendarEvent {
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
