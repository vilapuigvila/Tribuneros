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
        case didTapOnRace(URL?)
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

// MARK: - ErrorView -
extension CXRaces {
    enum ErrorView: Error {
        case unknown
    }
}
