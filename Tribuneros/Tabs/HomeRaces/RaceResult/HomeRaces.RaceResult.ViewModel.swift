//
//  HomeRaces.RaceResult.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension HomeRaces.RaceResult {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == HomeRaces.RaceResult.Domain, Interactor.UseCase == HomeRaces.RaceResult.UseCase {

        @Published private(set) var stateView: ViewState

        let router: Router
        let interactor: Interactor

        init(
            race: HomeRaces.Representable.RaceFinished,
            router: Router,
            interactor: Interactor
        ) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(
                race: race,
                domain: interactor.domain
            )
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { domain in
                    Self.mapToViewState(
                        race: race,
                        domain: domain
                    )
                }
                .assign(to: &$stateView)
        }

        func action(_ action: Action) {
            switch action {
            case .onAppear:
                interactor.useCase(.load)
            case .select(let classification):
                interactor.useCase(.select(classification))
            case .openFullResults:
                guard let url = stateView.fullResultsURL else { return }
                router.routeTo(.web(url))
            }
        }

        static func mapToViewState(
            race: HomeRaces.Representable.RaceFinished,
            domain: Domain
        ) -> ViewState {
            let descriptor = domain.descriptor
            let stagePage: DTO.RaceResultPage? = {
                guard case .loaded(let page) = domain.stage else { return nil }
                return page
            }()
            return ViewState(
                title: race.race,
                subtitle: descriptor.subtitle(page: stagePage),
                winnerImgURL: race.winnerImgURL,
                classifications: descriptor.classifications,
                selected: domain.selected,
                table: table(
                    domain.load(for: domain.selected),
                    selected: domain.selected,
                    podium: race.podium
                ),
                fullResultsURL: descriptor.url(for: domain.selected) ?? race.raceURL
            )
        }

        private static func table(
            _ load: Load,
            selected: Classification,
            podium: [HomeRaces.Representable.RaceFinished.Winner]
        ) -> ViewState.Table {
            switch load {
            case .idle, .loading:
                return .loading
            case .loaded(let page):
                return .loaded(
                    rows(
                        page.rows.map {
                            (
                                position: $0.position,
                                name: $0.name,
                                team: $0.team,
                                time: $0.time
                            )
                        }
                    )
                )
            case .failed:
                // The homepage podium is the tapped page's top 3, so it stands in only for `.stage`.
                switch selected {
                case .stage:
                    return .unavailable(
                        fallback: rows(
                            podium.map {
                                (
                                    position: $0.position,
                                    name: $0.name,
                                    team: $0.team,
                                    time: $0.time
                                )
                            }
                        ),
                        message: "Couldn't load the full results. Showing the podium."
                    )
                case .gc:
                    return .unavailable(
                        fallback: [],
                        message: "Couldn't load the general classification."
                    )
                }
            }
        }

        private static func rows(
            _ entries: [(position: String, name: String, team: String, time: String)]
        ) -> [ViewState.Row] {
            entries.enumerated().map { index, entry in
                ViewState.Row(
                    position: entry.position,
                    name: entry.name,
                    team: cleaned(entry.team),
                    time: displayTime(
                        entry.time,
                        isLeader: index == 0
                    )
                )
            }
        }

        /// The leader keeps the time PCS prints; everyone else shows a gap: "+0:12", or "s.t."
        /// for the same time (PCS writes ",," or a zero gap).
        static func displayTime(
            _ raw: String,
            isLeader: Bool
        ) -> String {
            let time = cleaned(raw)
            if isLeader {
                return time == ",," ? "" : time
            }
            if time == ",," || ["0:00", "00:00", "+0:00", "+00:00"].contains(time) {
                return "s.t."
            }
            if time.isEmpty || time.hasPrefix("+") {
                return time
            }
            return "+" + time
        }

        /// The homepage parsers write "#" for a missing value.
        private static func cleaned(_ value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed == "#" ? "" : trimmed
        }
    }
}
