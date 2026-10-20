//
//  CXRaces.FullResults.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension CXRaces.FullResults {

    struct Domain: Equatable {
        let event: DTO.CXCalendarEvent
        var load: CXRaces.PageLoad<[DTO.CX24Homepage.CategoryResult]>
    }

    enum UseCase: Sendable {
        /// Loads the results, unless they are already loaded or loading.
        case load
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = CXRaces.FullResults.Domain
        typealias UseCase = CXRaces.FullResults.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Injectable so previews and tests never hit the network.
        private let loadResults: (DTO.CXCalendarEvent) async -> [DTO.CX24Homepage.CategoryResult]
        private var task: Task<Void, Never>?

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            event: DTO.CXCalendarEvent,
            results: [DTO.CX24Homepage.CategoryResult],
            loadResults: @escaping (DTO.CXCalendarEvent) async -> [DTO.CX24Homepage.CategoryResult] = {
                await Service.getCxEventDetail(
                    $0,
                    hasStarted: true
                ).results
            }
        ) {
            subject = CurrentValueSubject(
                Domain(
                    event: event,
                    load: results.isEmpty ? .idle : .loaded(results)
                )
            )
            self.loadResults = loadResults
        }

        deinit {
            task?.cancel()
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .load:
                load()
            }
        }

        private func load() {
            guard task == nil, domain.load.needsLoad else { return }
            mutate { $0.load = .loading }
            let loadResults = loadResults
            let event = domain.event
            task = Task { @MainActor [weak self] in
                let results = await loadResults(event)
                guard !Task.isCancelled else { return }
                self?.mutate { $0.load = results.isEmpty ? .failed : .loaded(results) }
                self?.task = nil
            }
        }

        private func mutate(_ change: (inout Domain) -> Void) {
            var domain = subject.value
            change(&domain)
            subject.send(domain)
        }
    }
}
