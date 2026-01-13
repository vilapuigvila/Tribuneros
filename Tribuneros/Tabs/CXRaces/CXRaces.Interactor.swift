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
                    error: nil
                )
            )
            
            task = Task { [weak self] in
                guard let self else { return }
                do {
                    async let calendarTask = Requester.getCxAllCalendarEvents()
                    async let racesTask = Requester.getCxEvents()
                    async let standings = Requester.getCxStandings()
                    
                    let (racesResult, calendarResult, standingsResult) = try await (racesTask, calendarTask, standings)
                    try Task.checkCancellation()
                    
                    self.subject.send(
                        .init(
                            races: racesResult,
                            calendar: calendarResult,
                            standings: standingsResult,
                            loading: false,
                            error: nil
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
                            error: error.toEquatableError()
                        )
                    )
                }
            }
        }
        /*
        private func requestLatestResults() async throws -> DTO.CX24Homepage {
            try await Requester.getCxEvents()
        }

        private func requestCalendarEvents() async throws -> [DTO.CXCalendarEvent] {
            try await Requester.getCxAllCalendarEvents()
        }*/
    }
}
