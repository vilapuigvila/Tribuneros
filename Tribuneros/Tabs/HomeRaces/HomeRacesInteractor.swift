//
//  HomeRacesInteractor.swift
//  Tribuneros
//
//  Created by albert vila on 3/3/25.
//

import Foundation
import Combine

// this will be map to stateView into ViewModel
struct HomeRacesDomain: Equatable {
    let nextToFinishRaces: [DTO.NextToFinishResult]
    let todayRaces: [DTO.TodayResult]
    let yesterdayResults: [DTO.TodayResult]
    let error: EquatableError?
    private(set) var loading: Bool
    
    static let empty: HomeRacesDomain = .init(
        nextToFinishRaces: [],
        todayRaces: [],
        yesterdayResults: [],
        error: nil,
        loading: false
    )
    
    func copy(loading: Bool) -> Self {
        var copy = self
        copy.loading = loading
        return copy
    }
}

protocol HomeRacesInteractorProtocol {
    associatedtype Domain: Equatable
    var domain: Domain { get }
    var publisher: AnyPublisher<Domain, Never> { get }
    func useCase(_ useCase: HomeRacesInteractorImpl.UseCase)
}

final class HomeRacesInteractorImpl: HomeRacesInteractorProtocol {
    typealias Domain = HomeRacesDomain
    
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
        case .requestDayRaces(let date):
            guard task == nil else { return }
            subject.send(domain.copy(loading: true))
            
            task = Task { [weak self] in
                defer { self?.task = nil }
                do {
                    let result = try await Requester.getLatestResults()
                    try Task.checkCancellation()
                    self?.subject.send(
                        Domain(
                            nextToFinishRaces: result.nextToFinish,
                            todayRaces: result.today,
                            yesterdayResults: result.yesterdayResults,
                            error: (result.nextToFinish.isEmpty && result.today.isEmpty && result.yesterdayResults.isEmpty) ?
                                ErrorReason.emptyResponse.toEquatableError() : nil,
                            loading: false
                        )
                    )
                } catch {
                    self?.subject.send(
                        Domain(
                            nextToFinishRaces: [],
                            todayRaces: [],
                            yesterdayResults: [],
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

extension HomeRacesInteractorImpl {
    enum UseCase {
        case requestDayRaces(date: Date)
        case cancelRequestStation
    }
    
    enum ErrorReason: Error {
        case emptyResponse
    }
}
