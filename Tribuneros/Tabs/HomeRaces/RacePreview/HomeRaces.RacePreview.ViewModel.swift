//
//  HomeRaces.RacePreview.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension HomeRaces.RacePreview {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == HomeRaces.RacePreview.Domain, Interactor.UseCase == HomeRaces.RacePreview.UseCase {

        @Published private(set) var stateView: ViewState

        let router: Router
        let interactor: Interactor

        init(
            preview: HomeRaces.Representable.RacePreview,
            router: Router,
            interactor: Interactor
        ) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(
                preview: preview,
                domain: interactor.domain
            )
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { domain in
                    Self.mapToViewState(
                        preview: preview,
                        domain: domain
                    )
                }
                .assign(to: &$stateView)
        }

        func action(_ action: Action) {
            switch action {
            case .onAppear:
                interactor.useCase(.load)
            case .openOnPCS:
                guard let url = stateView.pcsURL else { return }
                router.routeTo(.web(url))
            }
        }

        static func mapToViewState(
            preview: HomeRaces.Representable.RacePreview,
            domain: Domain
        ) -> ViewState {
            switch domain.load {
            case .idle, .loading:
                return ViewState(
                    title: preview.name,
                    subtitle: "",
                    body: .loading,
                    pcsURL: preview.url
                )
            case .loaded(let page):
                return ViewState(
                    title: preview.name,
                    subtitle: subtitle(page),
                    body: .loaded(content(page)),
                    pcsURL: preview.url
                )
            case .failed:
                return ViewState(
                    title: preview.name,
                    subtitle: "",
                    body: .unavailable("Couldn't load the race preview."),
                    pcsURL: preview.url
                )
            }
        }

        /// "Stage 6  ·  Pandan Indah › Rembau  (121.3km)"
        private static func subtitle(_ page: DTO.PreviewPage) -> String {
            let route = HomeRaces.RaceResult.Route(
                from: page.from,
                to: page.to,
                distance: page.distance
            )
            return [page.stage, route.text]
                .compactMap { $0 }
                .joined(separator: "  ·  ")
        }

        private static func content(_ page: DTO.PreviewPage) -> ViewState.Content {
            ViewState.Content(
                start: start(page),
                keypoints: page.keypoints.map {
                    ViewState.Keypoint(
                        km: $0.km,
                        type: $0.type,
                        name: $0.name
                    )
                },
                facts: page.facts.enumerated().map { index, fact in
                    ViewState.Fact(
                        id: index,
                        text: fact.text,
                        header: fact.header,
                        rows: fact.rows
                    )
                }
            )
        }

        /// "02/10 09:12 (03:12 CET)"
        private static func start(_ page: DTO.PreviewPage) -> String? {
            switch (page.start, page.startCET) {
            case (let local?, let cet?):
                return "\(local) (\(cet) CET)"
            case (let local?, nil):
                return local
            case (nil, let cet?):
                return "\(cet) CET"
            case (nil, nil):
                return nil
            }
        }
    }
}
