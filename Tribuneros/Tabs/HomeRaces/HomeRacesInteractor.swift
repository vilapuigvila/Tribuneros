//
//  HomeRacesInteractor.swift
//  Tribuneros
//
//  Created by albert vila on 3/3/25.
//

import Foundation
import Combine
import Alfy

// this will be map to stateView into ViewModel
struct HomeRacesDomain: Equatable {
    let nextToFinishRaces: [DTO.NextToFinishResult]
    let todayRaces: [DTO.TodayResult]
    let yesterdayResults: [DTO.TodayResult]
    let tomorrowRaces: [DTO.TomorrowRace]
    private(set) var isOnSpoilerModeResultsToday: Bool
    private(set) var isOnSpoilerModeResultsYesterday: Bool
    let error: EquatableError?
    private(set) var loading: Bool
    
    static let empty: HomeRacesDomain = .init(
        nextToFinishRaces: [],
        todayRaces: [],
        yesterdayResults: [],
        tomorrowRaces: [],
        isOnSpoilerModeResultsToday: false,
        isOnSpoilerModeResultsYesterday: false,
        error: nil,
        loading: false
    )
    
    func copy(loading: Bool? = nil, spoilerModeResultsToday: Bool? = nil, isOnSpoilerModeResultsYesterday: Bool? = nil) -> Self {
        var copy = self
        copy.loading = loading ?? self.loading
        copy.isOnSpoilerModeResultsToday = spoilerModeResultsToday ?? self.isOnSpoilerModeResultsToday
        copy.isOnSpoilerModeResultsYesterday = isOnSpoilerModeResultsYesterday ?? self.isOnSpoilerModeResultsYesterday
        return copy
    }
}

protocol InteractorProtocol {
    associatedtype Domain: Equatable
    associatedtype UseCase: Sendable
    
    var domain: Domain { get }
    var publisher: AnyPublisher<Domain, Never> { get }
    func useCase(_ useCase: UseCase)
}

final class HomeRacesInteractorImpl: InteractorProtocol {
    typealias Domain = HomeRacesDomain
    typealias UseCase = HomeRaces.UseCase
    
    private let requestThrottle =
        RequestThrottleController(minimumInterval: 60, extraRequestsLimit: 2)
    
    private let subject = CurrentValueSubject<Domain, Never>(.empty)
    
    var publisher: AnyPublisher<Domain, Never> {
        subject.eraseToAnyPublisher()
    }
    var domain: Domain { subject.value }
    private var task: Task<Void, Never>?
    
    init() {
        
    }
    
    func useCase(_ useCase: UseCase) {
        switch useCase {
        case .spoilerModeResultToday:
            let toggle = !(UserSettings.spoilerModeResultsToday ?? false)
            UserSettings.spoilerModeResultsToday = toggle
            subject.send(domain.copy(spoilerModeResultsToday: toggle))
        case .spoilerModeResultYesterday:
            let toggle = !(UserSettings.spoilerModeResultsYesterday ?? false)
            UserSettings.spoilerModeResultsYesterday = toggle
            subject.send(domain.copy(isOnSpoilerModeResultsYesterday: toggle))
        case .requestDayRaces(_):
            guard task == nil else { return }
            let requestDate = Date()
            guard requestThrottle.startRequestIfAllowed(at: requestDate) else { return }
            
            subject.send(domain.copy(loading: true))
            
            task = Task { [weak self] in
                defer { self?.task = nil }
                do {
                    let result = try await Requester.getLatestResults()
                    try Task.checkCancellation()
                    
                    self?.requestThrottle.registerOutcome(isFailure: false)
                    
                    self?.subject.send(
                        Domain(
                            nextToFinishRaces: result.nextToFinish,
                            todayRaces: result.today,
                            yesterdayResults: result.yesterdayResults,
                            tomorrowRaces: result.tomorrowRaces,
                            isOnSpoilerModeResultsToday: UserSettings.spoilerModeResultsToday ?? false,
                            isOnSpoilerModeResultsYesterday: UserSettings.spoilerModeResultsYesterday ?? false,
                            error: (result.nextToFinish.isEmpty && result.today.isEmpty && result.yesterdayResults.isEmpty && result.tomorrowRaces.isEmpty) ?
                                HomeRaces.ErrorReason.emptyResponse.toEquatableError() : nil,
                            loading: false
                        )
                    )
                } catch {
                    self?.requestThrottle.registerOutcome(isFailure: true)
                    
                    self?.subject.send(
                        Domain(
                            nextToFinishRaces: [],
                            todayRaces: [],
                            yesterdayResults: [],
                            tomorrowRaces: [],
                            isOnSpoilerModeResultsToday: UserSettings.spoilerModeResultsToday ?? false,
                            isOnSpoilerModeResultsYesterday: UserSettings.spoilerModeResultsYesterday ?? false,
                            error: error.toEquatableError(),
                            loading: false
                        )
                    )
                }
            }
        case .cancelRequestStation:
            task?.cancel()
            task = nil
        }
    }
}

extension HomeRaces {
    enum UseCase: Sendable {
        case requestDayRaces(date: Date)
        case cancelRequestStation
        case spoilerModeResultToday
        case spoilerModeResultYesterday
//        case navigate(HomeRaces.Navigate)
    }
    
    enum ErrorReason: Error {
        case emptyResponse
        
        var asErrorView: HomeRaces.ErrorView {
            .emtpyData
        }
    }
}
