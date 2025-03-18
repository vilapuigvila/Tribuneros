//
//  HomeRacesViewModel.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import Foundation
import Combine

final class HomeRacesViewModel<Interactor: HomeRacesInteractorProtocol>: ObservableObject {
    @Published private(set) var stateView: HomeRaces.ViewState = .idle
    
    private var cancellables = Set<AnyCancellable>()
        
    let interactor: Interactor
    
    init(interactor: Interactor) {
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
        case .request(let date):
            print("avp - \(date)")
        case .selectedHomeStation(let value):
            print("avp - \(value)")
        }
    }
    
    private func mapToHomeStationState() -> HomeRaces.ViewState {
        let domain: HomeRacesDomain = interactor.domain as! HomeRacesDomain
        
        if domain.loading {
            return .loading
        } else {
            if domain.error != nil {
                return .error(.networkFailure)
            }
            if domain.nextToFinishRaces.isEmpty && domain.todayRaces.isEmpty {
                return .error(.networkFailure)
            } else {
                let nextToFinish = domain.nextToFinishRaces.map {
                    HomeRaces.Representable.RaceNext(
                        eta: $0.eta,
                        duration: $0.duration,
                        name: $0.name,
                        category: $0.category,
                        raceType: $0.raceType,
                        distance: $0.distance,
                        isSpoilerModeOn: false
                    )
                }
                let nextToFinishSorted = nextToFinish.filter { $0.raceType.contains("UWT") }
                    + nextToFinish.filter { !$0.raceType.contains("UWT") }
                
                let todayRaces = domain.todayRaces.map { race in
                    HomeRaces.Representable.RaceFinished(
                        race: race.raceDetails,
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
                let yesterdayResults = domain.yesterdayResults.map { race in
                    HomeRaces.Representable.RaceFinished(
                        race: race.raceDetails,
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
                return .loaded(
                    HomeRaces.Representable(
                        sections: .init(
                            title: "",
                            nextToFinish: nextToFinishSorted,
                            racesFinished: todayRaces,
                            yesterdayResults: yesterdayResults
                        )
                    )
                )
            }
        }
    }
}
