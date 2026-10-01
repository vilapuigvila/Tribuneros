//
//  HomeRaces.RaceResult.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension HomeRaces.RaceResult {

    enum Load: Equatable {
        case idle
        case loading
        case loaded(DTO.RaceResultPage)
        case failed
    }

    struct Domain: Equatable {
        let descriptor: Descriptor
        var selected: Classification = .stage
        var stage: Load = .idle
        var gc: Load = .idle

        func load(for classification: Classification) -> Load {
            switch classification {
            case .stage: stage
            case .gc: gc
            }
        }

        mutating func setLoad(
            _ load: Load,
            for classification: Classification
        ) {
            switch classification {
            case .stage: stage = load
            case .gc: gc = load
            }
        }
    }

    enum UseCase: Sendable {
        /// Loads the selected table, unless it is already loaded or loading.
        case load
        case select(Classification)
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = HomeRaces.RaceResult.Domain
        typealias UseCase = HomeRaces.RaceResult.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Fetches and parses a result page; injectable so previews and tests never hit the network.
        private let loadPage: (URL) async -> DTO.RaceResultPage?
        private var tasks: [Classification: Task<Void, Never>] = [:]

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            descriptor: Descriptor,
            loadPage: @escaping (URL) async -> DTO.RaceResultPage? = {
                await Service.getCachedRaceResultPage(url: $0)
            }
        ) {
            subject = CurrentValueSubject<Domain, Never>(Domain(descriptor: descriptor))
            self.loadPage = loadPage
        }

        deinit {
            tasks.values.forEach { $0.cancel() }
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .load:
                load(domain.selected)
            case .select(let classification):
                mutate { $0.selected = classification }
                load(classification)
            }
        }

        /// A failed table is tried again the next time it is selected.
        private func load(_ classification: Classification) {
            guard tasks[classification] == nil else { return }
            switch domain.load(for: classification) {
            case .loading, .loaded:
                return
            case .idle, .failed:
                break
            }
            guard let url = domain.descriptor.url(for: classification) else {
                mutate {
                    $0.setLoad(
                        .failed,
                        for: classification
                    )
                }
                return
            }
            mutate {
                $0.setLoad(
                    .loading,
                    for: classification
                )
            }
            let loadPage = loadPage
            tasks[classification] = Task { @MainActor [weak self] in
                let page = await loadPage(url)
                guard !Task.isCancelled else { return }
                let load: Load
                if let page, !page.rows.isEmpty {
                    load = .loaded(page)
                } else {
                    load = .failed
                }
                self?.mutate {
                    $0.setLoad(
                        load,
                        for: classification
                    )
                }
                self?.tasks[classification] = nil
            }
        }

        private func mutate(_ change: (inout Domain) -> Void) {
            var domain = subject.value
            change(&domain)
            subject.send(domain)
        }
    }
}
