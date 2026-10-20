//
//  CXRaces.RiderResults.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension CXRaces.RiderResults {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == CXRaces.RiderResults.Domain, Interactor.UseCase == CXRaces.RiderResults.UseCase {

        @Published private(set) var stateView: ViewState

        let router: Router
        let interactor: Interactor
        /// This season's calendar, to open a row's race like "Recent results" does.
        private let calendar: [DTO.CXCalendarEvent]

        init(
            calendar: [DTO.CXCalendarEvent],
            router: Router,
            interactor: Interactor
        ) {
            self.calendar = calendar
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(interactor.domain)
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map(Self.mapToViewState)
                .assign(to: &$stateView)
        }

        func action(_ action: Action) {
            switch action {
            case .onAppear:
                interactor.useCase(.load)
            case .openResult(let index):
                guard let destination = Self.destination(
                    forResult: index,
                    domain: interactor.domain,
                    calendar: calendar
                ) else { return }
                router.routeTo(destination)
            }
        }

        static func destination(
            forResult index: Int,
            domain: Domain,
            calendar: [DTO.CXCalendarEvent]
        ) -> Router.Destination? {
            guard let results = domain.load.value?.results,
                  results.indices.contains(index),
                  results[index].raceURL != nil else { return nil }
            return CXRaces.destination(
                forRiderResult: results[index],
                rider: domain.rider,
                calendar: calendar
            )
        }

        static func mapToViewState(_ domain: Domain) -> ViewState {
            switch domain.load {
            case .idle, .loading:
                return ViewState(
                    title: domain.rider.name,
                    subtitle: "",
                    body: .loading
                )
            case .loaded(let page):
                let title = page.name.isEmpty ? domain.rider.name : page.name
                guard !page.results.isEmpty else {
                    return ViewState(
                        title: title,
                        subtitle: "",
                        body: .unavailable(L10n.tr("No results for this rider yet."))
                    )
                }
                return ViewState(
                    title: title,
                    subtitle: L10n.tr("%lld RESULTS", page.results.count),
                    body: .loaded(CXRaces.RiderResults.seasons(page.results))
                )
            case .failed:
                return ViewState(
                    title: domain.rider.name,
                    subtitle: "",
                    body: .unavailable(L10n.tr("Couldn’t load the rider’s results. Check your connection and try again."))
                )
            }
        }
    }
}
