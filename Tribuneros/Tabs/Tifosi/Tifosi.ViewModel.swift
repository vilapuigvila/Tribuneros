//
//  Tifosi.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension Tifosi {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == Tifosi.Domain, Interactor.UseCase == Tifosi.UseCase {

        @Published private(set) var stateView: Tifosi.ViewState

        let router: Router
        let interactor: Interactor

        init(router: Router, interactor: Interactor) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(from: interactor.domain)
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { Self.mapToViewState(from: $0) }
                .assign(to: &$stateView)
        }

        func action(_ action: Tifosi.Action) {
            switch action {
            case .didSelectChannel(let channel):
                interactor.useCase(.selectChannel(channel))
            }
        }

        static func mapToViewState(from domain: Tifosi.Domain) -> Tifosi.ViewState {
            let scope = domain.filter == .everything
                ? L10n.tr("TV, radio and social")
                : domain.filter.title
            let date = L10n.dateFormatter(template: "EEEddMMM").string(from: domain.date)
            return Tifosi.ViewState(
                dateLine: "\(date) · \(scope)",
                chips: Tifosi.Channel.chips.map {
                    Tifosi.Representable.Chip(
                        channel: $0,
                        title: $0.title,
                        isSelected: $0 == domain.filter
                    )
                },
                race: domain.race,
                leader: domain.leader,
                chase: domain.chase
            )
        }
    }
}
