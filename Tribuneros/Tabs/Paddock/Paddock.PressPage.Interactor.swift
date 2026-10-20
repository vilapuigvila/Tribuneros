//
//  Paddock.PressPage.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension Paddock.PressPage {

    struct Domain: Equatable {
        let item: Paddock.PressItem
        var load: CXRaces.PageLoad<DTO.PressFeed> = .idle
    }

    enum UseCase: Sendable {
        /// Loads the feed, unless it is already loaded or loading.
        case load
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = Paddock.PressPage.Domain
        typealias UseCase = Paddock.PressPage.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Injectable so previews and tests never hit the network.
        private let loadFeed: (URL) async -> DTO.PressFeed?
        private var task: Task<Void, Never>?

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            item: Paddock.PressItem,
            loadFeed: @escaping (URL) async -> DTO.PressFeed? = {
                await Service.getPressFeed(for: $0)
            }
        ) {
            subject = CurrentValueSubject(Domain(item: item))
            self.loadFeed = loadFeed
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
            let url = domain.item.url
            let loadFeed = loadFeed
            task = Task { @MainActor [weak self] in
                let feed = await loadFeed(url)
                guard !Task.isCancelled else { return }
                self?.mutate { $0.load = feed.map(CXRaces.PageLoad.loaded) ?? .failed }
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
