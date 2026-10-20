//
//  CXRaces.Ranking.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension CXRaces.Ranking {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == CXRaces.Ranking.Domain, Interactor.UseCase == CXRaces.Ranking.UseCase {

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
            case .selectCategory(let index):
                interactor.useCase(.selectCategory(index))
            case .openRow(let index):
                guard let destination = Self.destination(
                    forRow: index,
                    domain: interactor.domain
                ) else { return }
                router.routeTo(destination)
            }
        }

        static func destination(
            forRow index: Int,
            domain: Domain
        ) -> Router.Destination? {
            guard let page = domain.load.value, page.rows.indices.contains(index) else { return nil }
            let standing = CXRaces.RiderStanding(
                row: page.rows[index],
                page: page,
                pageURL: domain.url,
                rankingLogoURL: domain.context.logoURL
            )
            return .cxZone(.riderDetail(.standing(standing)))
        }

        static func mapToViewState(_ domain: Domain) -> ViewState {
            let page = domain.load.value
            let title = page?.title.isEmpty == false ? page?.title : nil
            let chips: [ViewState.Chip]? = domain.categories.isEmpty
                ? nil
                : domain.categories.enumerated().map { index, category in
                    ViewState.Chip(
                        id: index,
                        title: category.title,
                        isSelected: index == domain.selectedIndex
                    )
                }
            let body: ViewState.Body
            switch domain.load {
            case .idle, .loading:
                body = .loading
            case .loaded(let page):
                body = page.rows.isEmpty
                    ? .unavailable(L10n.tr("No riders in this ranking yet."))
                    : .loaded(
                        page.rows.enumerated().map { index, row in
                            ViewState.Row(
                                id: index,
                                position: "\(row.position)",
                                rider: row.rider,
                                flagURL: row.countryFlagURL,
                                team: row.team?.isEmpty == false ? row.team : nil,
                                points: row.points
                            )
                        }
                    )
            case .failed:
                body = .unavailable(L10n.tr("This ranking isn’t available yet. It may not have started this season, or the connection failed."))
            }
            return ViewState(
                title: title ?? domain.context.title,
                logoURL: domain.context.logoURL,
                chips: chips,
                body: body
            )
        }
    }
}
