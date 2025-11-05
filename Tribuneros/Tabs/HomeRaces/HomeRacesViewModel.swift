//
//  HomeRacesViewModel.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import Foundation
import Combine
import SwiftUI

final class HomeRacesViewModel<Interactor: HomeRacesInteractorProtocol>: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var stateView: HomeRaces.ViewState = .idle
    @ObservedObject var router: Router
    
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
            .map { _ in
                return self.mapToHomeStationState()
            }
            .weakAssign(to: \.stateView, on: self)
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
        case .navigate(let destiantion):
            switch destiantion {
            case .nextToFinishRace(let index):
                router.routeTo(.nextToFinishRace(index: index))
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
    
    private func mapToHomeStationState() -> HomeRaces.ViewState {
        let domain: HomeRacesDomain = interactor.domain as! HomeRacesDomain
        
        if domain.loading {
            return .loading
        } else {
            if let error = domain.error {
                guard let errorType = error.asError(type: HomeRacesInteractorImpl.ErrorReason.self) else {
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
                            racesFinished: todayRaces(domain),
                            yesterdayResults: yesterdayResults(domain),
                            tomorrowRaces: tomorrowRaces(domain)
                        )
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
    
    private func tomorrowRaces(_ domain: HomeRacesDomain) -> [HomeRaces.Representable.RaceTomorrow] {
        domain.tomorrowRaces.map {
            HomeRaces.Representable.RaceTomorrow(start: $0.startTime, eta: $0.eta, name: $0.raceName, url: $0.relativeUrl)
        }
    }
    
    private func todayRaces(_ domain: HomeRacesDomain) -> [HomeRaces.Representable.RaceFinished] {
        domain.todayRaces.map { race in
            HomeRaces.Representable.RaceFinished(
                race: race.raceName,
                raceDetails: race.raceDetails,
                winnerImgURL: race.winner,
                podium: race.podium.map {
                    HomeRaces.Representable.RaceFinished.Winner(
                        position: $0.position,
                        flag: $0.flag,
                        countryCode: $0.countryCode ?? "ad",
                        name: $0.name,
                        team: $0.team,
                        time: $0.time
                    )
                },
                isCancel: false
            )
        }
    }
    
    private func nextToFinish(_ domain: HomeRacesDomain) -> [HomeRaces.Representable.RaceNext] {
        guard !domain.nextToFinishRaces.isEmpty else {
            return isMockingEnabled ? HomeRaces.Representable.RaceNext.mockList : []
        }
        let nextToFinish = domain.nextToFinishRaces.map {
            HomeRaces.Representable.RaceNext(
                eta: $0.eta,
                duration: $0.duration,
                name: $0.name,
                category: $0.category,
                raceType: $0.raceType,
                distance: $0.distance,
                urlPath: $0.urlPath.isEmpty ? nil : $0.urlPath,
                flagCode: $0.flagCode
            )
        }
        return nextToFinish.filter { $0.raceType.contains("UWT") } +
               nextToFinish.filter { !$0.raceType.contains("UWT") }
    }
    
    private func yesterdayResults(_ domain: HomeRacesDomain) -> [HomeRaces.Representable.RaceFinished] {
        typealias Winners = HomeRaces.Representable.RaceFinished.Winner
        
        let ensurePodiumCount: ([DTO.TodayResult.Winner]) -> [Winners] = { podium in
            let winners = podium.map {
                HomeRaces.Representable.RaceFinished.Winner(
                    position: $0.position,
                    flag: $0.flag,
                    countryCode: $0.countryCode ?? "ad",
                    name: $0.name,
                    team: $0.team,
                    time: $0.time
                )
            }
            let missing = 3 - min(podium.count, 3)
            let empties: [Winners] = (0..<missing).map { _ in
                .init(position: "-", flag: nil, countryCode: "", name: "", team: "", time: "")
            }
            return winners + empties
        }
        return domain.yesterdayResults.map { race in
            HomeRaces.Representable.RaceFinished(
                race: race.raceName,
                raceDetails: race.raceDetails.isEmpty ? "No info.." : race.raceDetails,
                winnerImgURL: race.winner,
                podium: ensurePodiumCount(race.podium),
                isCancel: false
            )
        }
    }
}
