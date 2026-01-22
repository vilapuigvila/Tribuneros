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
    private(set) var error: EquatableError?
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
    
    func copy(
              loading: Bool? = nil,
              spoilerModeResultsToday: Bool? = nil,
              isOnSpoilerModeResultsYesterday: Bool? = nil,
              error: EquatableError? = nil
    ) -> Self {
        HomeRacesDomain.init(nextToFinishRaces: self.nextToFinishRaces, todayRaces: self.todayRaces, yesterdayResults: self.yesterdayResults, tomorrowRaces: self.tomorrowRaces, isOnSpoilerModeResultsToday: spoilerModeResultsToday ?? self.isOnSpoilerModeResultsToday, isOnSpoilerModeResultsYesterday: isOnSpoilerModeResultsYesterday ?? self.isOnSpoilerModeResultsYesterday, error: error ?? self.error, loading: loading ?? self.loading)
/*        var copy = self
        copy.loading = loading ?? self.loading
        copy.isOnSpoilerModeResultsToday = spoilerModeResultsToday ?? self.isOnSpoilerModeResultsToday
        copy.isOnSpoilerModeResultsYesterday = isOnSpoilerModeResultsYesterday ?? self.isOnSpoilerModeResultsYesterday
        copy.error = error ?? self.error
        return copy*/
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
    static let url = URL(string: "https://www.procyclingstats.com/index.php")!
    static let request = URLRequest(url: url, timeoutInterval: 60*60)
    
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
            
            subject.send(domain.copy(loading: true))
            
            task = Task { [weak self] in
                defer { self?.task = nil }
                guard await CachedURLSession.shared.isCacheExpired(for: Self.url) || self?.domain == .empty else {
                    self?.subject.send(self?.domain.copy(loading: false) ?? .empty)
                    return
                }
                do {
                    let result = try await Requester.getLatestResults(for: Self.request)
                    try Task.checkCancellation()
                    
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
                    if Task.isCancelled {
                        self?.publishSuccessWithCurrentDomain()
                    } else {
                        self?.publishFailure(error)
                    }
                }
            }
        case .cancelRequestStation:
            task?.cancel()
            task = nil
        }
    }
    
    private func publishSuccessWithCurrentDomain() {
        subject.send(
            domain.copy(loading: false)
        )
    }
    
    private func publishFailure(_ error: Error) {
        subject.send(
            domain.copy(loading: false, error: error.toEquatableError())
        )
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
