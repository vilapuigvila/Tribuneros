//
//  HomeRaces.RacePreview.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension HomeRaces.RacePreview {

    enum Load: Equatable {
        case idle
        case loading
        case loaded(DTO.PreviewPage)
        case failed
    }

    struct Domain: Equatable {
        let url: URL?
        var load: Load = .idle
    }

    enum UseCase: Sendable {
        /// Loads the page, unless it is already loaded or loading.
        case load
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = HomeRaces.RacePreview.Domain
        typealias UseCase = HomeRaces.RacePreview.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Fetches and parses the page; injectable so previews and tests never hit the network.
        private let loadPage: (URL) async -> DTO.PreviewPage?
        private var task: Task<Void, Never>?

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            url: URL?,
            loadPage: @escaping (URL) async -> DTO.PreviewPage? = {
                await Service.getPreviewPage(url: $0)
            }
        ) {
            subject = CurrentValueSubject<Domain, Never>(Domain(url: url))
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

        /// A failed page is tried again the next time the screen appears.
        private func load() {
            guard task == nil else { return }
            switch domain.load {
            case .loading, .loaded:
                return
            case .idle, .failed:
                break
            }
            guard let url = domain.url else {
                mutate { $0.load = .failed }
                return
            }
            mutate { $0.load = .loading }
            let loadPage = loadPage
            task = Task { @MainActor [weak self] in
                let page = await loadPage(url)
                guard !Task.isCancelled else { return }
                self?.mutate { $0.load = page.map(Load.loaded) ?? .failed }
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
