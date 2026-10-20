//
//  CXRaces.RiderResults.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension CXRaces.RiderResults {

    struct Domain: Equatable {
        let rider: CXRaces.RiderRef
        var load: CXRaces.PageLoad<DTO.CXRiderPage> = .idle
    }

    enum UseCase: Sendable {
        /// Loads the rider page, unless it is already loaded or loading.
        case load
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = CXRaces.RiderResults.Domain
        typealias UseCase = CXRaces.RiderResults.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Injectable so previews and tests never hit the network.
        private let loadPage: (URL) async -> DTO.CXRiderPage?
        private var task: Task<Void, Never>?

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            rider: CXRaces.RiderRef,
            loadPage: @escaping (URL) async -> DTO.CXRiderPage? = {
                await Service.getCxRiderPage($0)
            }
        ) {
            subject = CurrentValueSubject(Domain(rider: rider))
            self.loadPage = loadPage
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
            guard let url = domain.rider.riderURL else {
                mutate { $0.load = .failed }
                return
            }
            mutate { $0.load = .loading }
            let loadPage = loadPage
            task = Task { @MainActor [weak self] in
                let page = await loadPage(url)
                guard !Task.isCancelled else { return }
                self?.mutate { $0.load = page.map(CXRaces.PageLoad.loaded) ?? .failed }
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
