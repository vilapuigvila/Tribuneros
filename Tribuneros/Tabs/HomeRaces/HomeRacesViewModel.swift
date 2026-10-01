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
        case .spoilerModeResultToday:
            interactor.useCase(.spoilerModeResultToday)
        case .spoilerModeResultYesterday:
            interactor.useCase(.spoilerModeResultYesterday)
        case .openLink(let url):
            router.routeTo(.web(url))
        case .openRaceResult(let raceFinished):
            router.routeTo(.raceResultDetail(raceFinished))
        case .navigate(let destiantion):
            switch destiantion {
            case .nextToFinishRace(let index):
                router.routeTo(.nextToFinishRace(index: index))
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
                            spoilerMode: spoilerMode(domain),
                            nextToFinish: nextToFinish(domain),
                            racesFinished: finishedRaces(domain.todayRaces),
                            yesterdayResults: finishedRaces(domain.yesterdayResults),
                            historyResults: finishedRaces(domain.historyResults)
                        ),
                        staleCopy: domain.staleCopy
                    )
                )
            }
        }
    }
    private static func errorDueEmptyData(_ domain: HomeRacesDomain) -> Bool {
        domain.nextToFinishRaces.isEmpty && domain.todayRaces.isEmpty &&
        domain.yesterdayResults.isEmpty && domain.tomorrowRaces.isEmpty
    }
    
    private func spoilerMode(_ domain: HomeRacesDomain) -> HomeRaces.SpoilerMode {
        HomeRaces.SpoilerMode(
            isSpoilerModeResultsToday: domain.isOnSpoilerModeResultsToday,
            isSpoilerModeResultsYesterday: domain.isOnSpoilerModeResultsYesterday
        )
    }
    
    private func nextToFinish(_ domain: HomeRacesDomain) -> [HomeRaces.Representable.RaceNext] {
        HomeRaces.TodayRaces.build(
            nextToFinish: domain.nextToFinishRaces,
            liveStats: domain.liveStatsRaces
        )
    }
    
    private func finishedRaces(_ results: [DTO.TodayResult]) -> [HomeRaces.Representable.RaceFinished] {
        results.map { race in
            HomeRaces.Representable.RaceFinished(
                race: race.raceName,
                raceDetails: race.raceDetails,
                winnerImgURL: race.winner,
                podium: race.podium.map { HomeRaces.Representable.RaceFinished.Winner($0) },
                isCancel: false,
                raceURL: race.raceURL
            )
        }
    }
}
