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
    let historyResults: [DTO.TodayResult]
    let tomorrowRaces: [DTO.TomorrowRace]
    let liveStatsRaces: [DTO.LiveStatsRace]
    private(set) var isOnSpoilerModeResultsToday: Bool
    private(set) var isOnSpoilerModeResultsYesterday: Bool
    let error: EquatableError?
    private(set) var loading: Bool
    var staleCopy: HomeRaces.StaleCopy? = nil
    var previews: [DTO.Preview] = []
    /// Start times by race URL; the homepage has none, so they come from each race's page.
    var startTimes: [String: String] = [:]

    static let empty: HomeRacesDomain = .init(
        nextToFinishRaces: [],
        todayRaces: [],
        yesterdayResults: [],
        historyResults: [],
        tomorrowRaces: [],
        liveStatsRaces: [],
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
    
    private let subject = CurrentValueSubject<Domain, Never>(.empty.copy(loading: true))
    
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
            #if DEBUG
            if let scenario = HomeRaces.MockScenario.current {
                subject.send(
                    scenario.domain(
                        isOnSpoilerModeResultsToday: UserSettings.spoilerModeResultsToday ?? false,
                        isOnSpoilerModeResultsYesterday: UserSettings.spoilerModeResultsYesterday ?? false
                    )
                )
                loadHeroStartTime()
                return
            }
            #endif
            subject.send(domain.copy(loading: true))
            
            task = Task { [weak self] in
                defer { self?.task = nil }
                do {
                    async let history = Service.getHistoryRaces()
                    let result = try await Service.getLatestResults()
                    try Task.checkCancellation()
                    let staleCopy = result.staleCopySavedAt.map {
                        HomeRaces.StaleCopy(
                            savedAt: $0,
                            isOffline: !NetworkStatusMonitor.shared.hasConnection
                        )
                    }
                    
                    let historyResults = await history

                    self?.subject.send(
                        Domain(
                            nextToFinishRaces: result.nextToFinish,
                            todayRaces: result.today,
                            yesterdayResults: result.yesterdayResults,
                            historyResults: historyResults,
                            tomorrowRaces: result.tomorrowRaces,
                            liveStatsRaces: result.liveStats,
                            isOnSpoilerModeResultsToday: UserSettings.spoilerModeResultsToday ?? false,
                            isOnSpoilerModeResultsYesterday: UserSettings.spoilerModeResultsYesterday ?? false,
                            error: (result.nextToFinish.isEmpty && result.today.isEmpty && result.yesterdayResults.isEmpty && result.tomorrowRaces.isEmpty && result.liveStats.isEmpty) ?
                                HomeRaces.ErrorReason.emptyResponse.toEquatableError() : nil,
                            loading: false,
                            staleCopy: staleCopy,
                            previews: result.previews
                        )
                    )
                    self?.loadHeroStartTime()
                } catch {
                    self?.subject.send(
                        Domain(
                            nextToFinishRaces: [],
                            todayRaces: [],
                            yesterdayResults: [],
                            historyResults: [],
                            tomorrowRaces: [],
                            liveStatsRaces: [],
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

    /// Only the hero card shows a start time, so only its race page is fetched (30 min cache).
    private func loadHeroStartTime() {
        let domain = subject.value
        guard let urlPath = HomeRaces.TodayRaces.build(
            nextToFinish: domain.nextToFinishRaces,
            liveStats: domain.liveStatsRaces
        ).first?.urlPath,
              domain.startTimes[urlPath] == nil
        else {
            return
        }
        Task { @MainActor [weak self] in
            guard let detail = try? await Service.getNextToFinishRaceDetail(urlPath),
                  let startTime = HomeRaces.TodayRaces.siteStartTime(detail.startTime),
                  let self,
                  self.subject.value.nextToFinishRaces == domain.nextToFinishRaces
            else {
                return
            }
            var updated = self.subject.value
            updated.startTimes[urlPath] = startTime
            self.subject.send(updated)
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
