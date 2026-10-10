//
//  HomeRacesViewModel.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import Foundation
import Combine
import SwiftUI

final class HomeRacesViewModel<Interactor: InteractorProtocol>: ObservableObject
where Interactor.Domain == HomeRacesDomain, Interactor.UseCase == HomeRaces.UseCase {
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var stateView: HomeRaces.ViewState = .idle
    let router: Router
    
    let interactor: Interactor
    
    init(interactor: Interactor, router: Router) {
        self.router = router
        self.interactor = interactor
        registerPublisher()
    }
    
    private func registerPublisher() {
        interactor
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] domain in
//                self?.stateView = .loaded(.mockFull) // "avpv" change it
                self?.stateView = self?.mapToHomeRacesState(domain) ?? .idle
            }
            .store(in: &cancellables)
    }
    
    func action(_ action: HomeRaces.Action) {
        switch action {
        case .onAppear:
            interactor.useCase(.requestDayRaces(date: Date()))
        case .onDisappear:
            break
        case .toggleReveal(let race):
            interactor.useCase(.toggleReveal(key: race.revealKey))
        case .dismissSpoilerHint:
            interactor.useCase(.dismissSpoilerHint)
        case .openLink(let url):
            router.routeTo(.web(url))
        case .openRaceResult(let raceFinished):
            router.routeTo(.raceResultDetail(raceFinished))
        case .openRacePreview(let preview):
            router.routeTo(.racePreview(preview))
        case .navigate(let destiantion):
            switch destiantion {
            case .nextToFinishRace(let index):
                router.routeTo(.nextToFinishRace(index: index))
            case .liveRace(let index):
                routeToLiveRace(index: index)
            case .todayRaces:
                router.routeTo(.todayRaces)
            case .yesterdayResults:
                router.routeTo(.yesterdayResults)
            case .historyResults:
                router.routeTo(.historyResults)
            case .detail:
                nonFatalCrashlytics(false, "can't navigate to detail")
                break
//                switch detail {
//                case .race(let url):
//                    guard let url else {
////                        stateView = .error(.raceInfoFetchFailure)
//                        return
//                    }
//                    router.routeTo(.detail(.race(urlInfo: url)))
//                }
            default:
                nonFatalCrashlytics(false, "not implemented")
           }
        }
    }
    
    /// `stateView.result` is empty until the page loads, so an index past the end falls back to the race detail route.
    private func routeToLiveRace(index: Int) {
        let races = stateView.result.sections.nextToFinish
        guard races.indices.contains(index) else {
            router.routeTo(.nextToFinishRace(index: index))
            return
        }
        let race = races[index]
        let context = HomeRaces.LiveRace.Context(
            name: race.title,
            subtitle: [race.subtitle, race.raceType]
                .filter { !$0.isEmpty }
                .joined(separator: " · "),
            flagCode: race.flagCode,
            url: HomeRaces.LiveRace.Context.liveURL(urlPath: race.urlPath)
        )
        router.routeTo(.liveRace(context))
    }

    private func mapToHomeRacesState(_ domain: HomeRacesDomain) -> HomeRaces.ViewState {
        if domain.loading {
            return .loading
        } else {
            if let error = domain.error {
                guard let errorType = error.asError(type: HomeRaces.ErrorReason.self) else {
                    return .error(.networkFailure)
                }
                return .error(errorType.asErrorView)
            } else {
                return .loaded(
                    HomeRaces.Representable(
                        sections: .init(
                            title: "",
                            nextToFinish: nextToFinish(domain),
                            racesFinished: finishedRaces(domain.todayRaces, revealed: domain.revealedRaces),
                            yesterdayResults: finishedRaces(domain.yesterdayResults, revealed: domain.revealedRaces),
                            historyResults: finishedRaces(domain.historyResults, revealed: domain.revealedRaces),
                            previews: previews(domain),
                            firstFinishExpected: HomeRaces.TodayRaces.firstFinishTime(nextToFinish(domain))
                        ),
                        staleCopy: domain.staleCopy,
                        showSpoilerHint: domain.showSpoilerHint
                    )
                )
            }
        }
    }
    private static func errorDueEmptyData(_ domain: HomeRacesDomain) -> Bool {
        domain.nextToFinishRaces.isEmpty && domain.todayRaces.isEmpty &&
        domain.yesterdayResults.isEmpty && domain.tomorrowRaces.isEmpty
    }
    
    private func nextToFinish(_ domain: HomeRacesDomain) -> [HomeRaces.Representable.RaceNext] {
        HomeRaces.TodayRaces.build(
            nextToFinish: domain.nextToFinishRaces,
            liveStats: domain.liveStatsRaces,
            startTimes: domain.startTimes
        )
    }
    
    /// Previews show whenever PCS lists any: under the resting card when Today has no races,
    /// otherwise under the Today hero (the first race keeps the first section).
    private func previews(_ domain: HomeRacesDomain) -> [HomeRaces.Representable.RacePreview] {
        domain.previews.map {
            HomeRaces.Representable.RacePreview(
                countdown: $0.countdown,
                name: $0.name,
                url: $0.url
            )
        }
    }

    private func finishedRaces(
        _ results: [DTO.TodayResult],
        revealed: Set<String>
    ) -> [HomeRaces.Representable.RaceFinished] {
        results.map { race in
            var finished = HomeRaces.Representable.RaceFinished(
                race: race.raceName,
                raceDetails: race.raceDetails,
                winnerImgURL: race.winner,
                podium: race.podium.map { HomeRaces.Representable.RaceFinished.Winner($0) },
                isCancel: false,
                raceURL: race.raceURL,
                raceCountryCode: race.raceCountryCode ?? ""
            )
            finished.visibility = revealed.contains(finished.revealKey) ? .shown : .hidden
            return finished
        }
    }
}
