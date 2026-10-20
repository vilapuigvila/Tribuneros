//
//  CXRaces.FullResults.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension CXRaces.FullResults {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == CXRaces.FullResults.Domain, Interactor.UseCase == CXRaces.FullResults.UseCase {

        @Published private(set) var stateView: ViewState

        let router: Router
        let interactor: Interactor

        init(
            router: Router,
            interactor: Interactor
        ) {
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
            case .openRow(let index):
                guard let destination = Self.destination(
                    forRow: index,
                    domain: interactor.domain
                ) else { return }
                router.routeTo(destination)
            }
        }

        /// The winner's row opens the winner screen, any other the rider screen, as in the top 10.
        static func destination(
            forRow index: Int,
            domain: Domain
        ) -> Router.Destination? {
            guard let results = domain.load.value, results.indices.contains(index) else { return nil }
            let result = results[index]
            if result.position == "1" {
                return .cxZone(
                    .winnerDetail(
                        CXRaces.Winner(
                            event: domain.event,
                            result: result
                        ),
                        from: domain.event
                    )
                )
            }
            return .cxZone(
                .riderDetail(
                    .result(
                        CXRaces.RiderResult(
                            result: result,
                            event: domain.event
                        )
                    )
                )
            )
        }

        static func mapToViewState(_ domain: Domain) -> ViewState {
            let title = domain.event.race
            switch domain.load {
            case .idle, .loading:
                return ViewState(
                    title: title,
                    subtitle: L10n.tr("Men Elite").uppercased(with: L10n.locale),
                    body: .loading
                )
            case .loaded(let results):
                return ViewState(
                    title: title,
                    subtitle: L10n.tr("MEN ELITE · %lld RIDERS", results.count),
                    body: .loaded(
                        results.enumerated().map { index, result in
                            ViewState.Row(
                                id: index,
                                position: result.position,
                                rider: result.rider,
                                team: result.team,
                                time: result.time,
                                flagURL: result.countryFlagURL
                            )
                        }
                    )
                )
            case .failed:
                return ViewState(
                    title: title,
                    subtitle: L10n.tr("Men Elite").uppercased(with: L10n.locale),
                    body: .unavailable(L10n.tr("Couldn’t load the results. Check your connection and try again."))
                )
            }
        }
    }
}
