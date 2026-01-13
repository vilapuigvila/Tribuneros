//
//  CXRaces.ViewModel.swift
//  Tribuneros
//
//  Created by albert vila on 5/1/26.
//

import Foundation
import Combine

extension CXRaces {
    
    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == CXRaces.Domain, Interactor.UseCase == CXRaces.UseCase {
        
        @Published private(set) var stateView: CXRaces.ViewState = .idle
        
        let router: Router
        let interactor: Interactor
        
        init(router: Router, interactor: Interactor) {
            self.router = router
            self.interactor = interactor
            registerPublisher()
        }
        
        private func registerPublisher() {
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .scan(stateView) { current, domain in
                    Self.mapToRepresentable(from: domain, currentRepresentable: current)
                }
                .assign(to: &$stateView)
        }
        
        var isRequiredRequestData: Bool {
            if case .idle = stateView {
                return true
            }
            return stateView.isRacesEmpty || stateView.isCalendarEventsEmpty
        }
        
        func action(_ action: CXRaces.Action) {
            switch action {
            case .didAppeared:
                interactor.useCase(.request)
            case .didTapOnNextRaces:
                router.routeTo(.cxZone(.allRaces))
            case .didTapOnLatestResults:
                router.routeTo(.cxZone(.latestResults))
            case .didTapOnRace(let url):
                guard let url else { return }
                router.routeTo(.detail(.race(urlInfo: url.absoluteString)))
            case .didTapOnRaceDetail(let race):
                router.routeTo(.cxZone(.raceDetail(race)))
            case .didTapOnStandings:
                router.routeTo(.cxZone(.standings))
            }
        }
        
        static func mapToRepresentable(
            from domain: CXRaces.Domain,
            currentRepresentable: CXRaces.ViewState
        ) -> CXRaces.ViewState {
            if domain.error != nil {
                return .error(.unknown)
            } else if domain.loading {
                return .loading
            } else if domain.races.sections.isEmpty {
                return .error(.unknown)
            }
            return .loaded(.init(calendarEvents: domain.calendar, races: domain.races, standings: domain.standings))
        }
    }
}

private enum CXCalendarEventDate {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}

extension DTO.CXCalendarEvent {
    var eventDate: Date? {
        CXCalendarEventDate.formatter.date(from: date)
    }
}
