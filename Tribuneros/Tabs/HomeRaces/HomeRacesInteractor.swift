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
    let error: EquatableError?
    private(set) var loading: Bool
    var staleCopy: HomeRaces.StaleCopy? = nil
    var previews: [DTO.Preview] = []
    /// Start times by race URL; the homepage has none, so they come from each race's page.
    var startTimes: [String: String] = [:]
    var showSpoilerHint = false
    /// Race keys revealed this session; never persisted, so every launch starts spoiler-safe.
    private(set) var revealedRaces: Set<String> = []

    static let empty: HomeRacesDomain = .init(
        nextToFinishRaces: [],
        todayRaces: [],
        yesterdayResults: [],
        historyResults: [],
        tomorrowRaces: [],
        liveStatsRaces: [],
        error: nil,
        loading: false
    )
    
    func copy(loading: Bool? = nil) -> Self {
        var copy = self
        copy.loading = loading ?? self.loading
        return copy
    }

    func togglingReveal(_ key: String) -> Self {
        var copy = self
        if copy.revealedRaces.contains(key) {
            copy.revealedRaces.remove(key)
        } else {
            copy.revealedRaces.insert(key)
        }
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
    private var hintEvaluated = false
    private var hintVisible = false
    
    init() {
        
    }
    
    func useCase(_ useCase: UseCase) {
        switch useCase {
        case .toggleReveal(let key):
            hintVisible = false
            subject.send(applyingHint(domain.togglingReveal(key)))
        case .dismissSpoilerHint:
            hintVisible = false
            subject.send(applyingHint(domain))
        case .requestDayRaces(_):
            guard task == nil else { return }
            #if DEBUG
            if let scenario = HomeRaces.MockScenario.current {
                subject.send(scenario.domain(revealedRaces: domain.revealedRaces))
                evaluateSpoilerHint()
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
                            error: (result.nextToFinish.isEmpty && result.today.isEmpty && result.yesterdayResults.isEmpty && result.tomorrowRaces.isEmpty && result.liveStats.isEmpty) ?
                                HomeRaces.ErrorReason.emptyResponse.toEquatableError() : nil,
                            loading: false,
                            staleCopy: staleCopy,
                            previews: result.previews,
                            revealedRaces: self?.domain.revealedRaces ?? []
                        )
                    )
                    self?.evaluateSpoilerHint()
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
                            error: error.toEquatableError(),
                            loading: false,
                            revealedRaces: self?.domain.revealedRaces ?? []
                        )
                    )
                }
            }
        case .cancelRequestStation:
            task?.cancel()
            task = nil
        }
    }

    private func applyingHint(_ domain: Domain) -> Domain {
        var updated = domain
        updated.showSpoilerHint = hintVisible
        return updated
    }

    private func evaluateSpoilerHint() {
        let current = subject.value
        if !hintEvaluated,
           current.error == nil,
           !current.todayRaces.isEmpty || !current.yesterdayResults.isEmpty {
            hintEvaluated = true
            let count = UserSettings.spoilerHintShownCount ?? 0
            let now = Date()
            if HomeRaces.SpoilerHint.shouldShow(
                now: now,
                firstShown: UserSettings.spoilerHintFirstShown,
                count: count
            ) {
                UserSettings.spoilerHintFirstShown = UserSettings.spoilerHintFirstShown ?? now
                UserSettings.spoilerHintShownCount = count + 1
                hintVisible = true
            }
        }
        if current.showSpoilerHint != hintVisible {
            subject.send(applyingHint(current))
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
        case toggleReveal(key: String)
        case dismissSpoilerHint
//        case navigate(HomeRaces.Navigate)
    }
    
    enum ErrorReason: Error {
        case emptyResponse
        
        var asErrorView: HomeRaces.ErrorView {
            .emtpyData
        }
    }
}
