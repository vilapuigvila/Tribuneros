//
//  CXRaces.Interactor.swift
//  Tribuneros
//
//  Created by albert vila on 5/1/26.
//

import Foundation
import Combine
import Alfy

extension CXRaces {
    
    struct Domain: Equatable, Sendable {
        let races: DTO.CX24Homepage
        let calendar: [DTO.CXCalendarEvent]
        let standings: DTO.CXStandings
        let loading: Bool
        let error: EquatableError?
        var schedules: SeriesLens.Schedules = [:]
        
        static var empty: Domain {
            .init(races: .init(sections: []), calendar: [], standings: .init(items: []), loading: false, error: nil)
        }
    }
    
    enum UseCase: Sendable {
        case request
    }
}

extension CXRaces {
    final class InteractorImpl: InteractorProtocol {
        typealias Domain = CXRaces.Domain
        
        var domain: CXRaces.Domain { subject.value }
        private let subject = CurrentValueSubject<CXRaces.Domain, Never>(.empty)
        
        var publisher: AnyPublisher<CXRaces.Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        
        private var task: Task<Void, Never>?
        
        func useCase(_ useCase: CXRaces.UseCase) {
            switch useCase {
            case .request:
                request()
            }
        }
        
        private func request() {
            task?.cancel()
            
            let current = domain
            subject.send(
                .init(
                    races: current.races,
                    calendar: current.calendar,
                    standings: current.standings,
                    loading: true,
                    error: nil,
                    schedules: current.schedules
                )
            )
            
            task = Task { [weak self] in
                guard let self else { return }
                do {
                    async let calendarTask = Service.getCxAllCalendarEvents()
                    async let racesTask = Service.getCxEvents()
                    async let standings = Service.getCxStandings()
                    
                    let (racesResult, calendarResult, standingsResult) = try await (racesTask, calendarTask, standings)
                    try Task.checkCancellation()
                    
                    self.subject.send(
                        .init(
                            races: racesResult,
                            calendar: calendarResult,
                            standings: standingsResult,
                            loading: false,
                            error: nil,
                            schedules: current.schedules
                        )
                    )

                    let schedules = await Self.todaySchedules(in: calendarResult)
                    try Task.checkCancellation()
                    guard !schedules.isEmpty else { return }
                    self.subject.send(
                        .init(
                            races: racesResult,
                            calendar: calendarResult,
                            standings: standingsResult,
                            loading: false,
                            error: nil,
                            schedules: schedules
                        )
                    )
                } catch {
                    guard !Task.isCancelled else { return }
                    nonFatalCrashlytics(false, error.localizedDescription)
                    self.subject.send(
                        .init(
                            races: current.races,
                            calendar: current.calendar,
                            standings: current.standings,
                            loading: false,
                            error: error.toEquatableError(),
                            schedules: current.schedules
                        )
                    )
                }
            }
        }

        /// Only today's non-cancelled races need a start time; a failed fetch just means no entry.
        static func todaySchedules(
            in calendar: [DTO.CXCalendarEvent],
            now: Date = Date()
        ) async -> SeriesLens.Schedules {
            let today = calendar
                .filter { !$0.isCancelled && $0.raceURL != nil }
                .filter { event in event.eventDate.map { Calendar.current.isDate($0, inSameDayAs: now) } ?? false }
            return await withTaskGroup(of: (URL, [DTO.CXRacePage.ScheduledStart]).self) { group in
                for event in today {
                    guard let url = event.raceURL else { continue }
                    group.addTask { (url, await Service.getCxRaceSchedule(event)) }
                }
                var schedules: SeriesLens.Schedules = [:]
                for await (url, schedule) in group where !schedule.isEmpty {
                    schedules[url] = schedule
                }
                return schedules
            }
        }
    }
}
