//
//  CXRaces.Ranking.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension CXRaces.Ranking {

    struct Domain: Equatable {
        let context: CXRaces.RankingContext
        /// The page shown (or loading).
        var url: URL?
        var load: CXRaces.PageLoad<DTO.CXStandingPage> = .idle
        /// The category tabs of the last page loaded; they stay while another category loads.
        var categories: [DTO.CXStandingPage.Category] = []
        /// The chip picked; a loaded page sets it to its own category.
        var selectedIndex: Int?
        /// Pages already loaded on this screen, so switching back is instant.
        var pages: [URL: DTO.CXStandingPage] = [:]
    }

    enum UseCase: Sendable {
        /// Loads the page it was opened on, unless it is already loaded or loading.
        case load
        case selectCategory(Int)
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = CXRaces.Ranking.Domain
        typealias UseCase = CXRaces.Ranking.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Injectable so previews and tests never hit the network.
        private let loadPage: (URL) async -> DTO.CXStandingPage?
        private var task: Task<Void, Never>?
        /// Whether the opening category (`context.category`) has been looked for in a loaded page.
        private var didMatchContextCategory = false

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            context: CXRaces.RankingContext,
            loadPage: @escaping (URL) async -> DTO.CXStandingPage? = {
                await Service.getCxStandingPage($0)
            }
        ) {
            subject = CurrentValueSubject(
                Domain(
                    context: context,
                    url: context.url
                )
            )
            self.loadPage = loadPage
        }

        deinit {
            task?.cancel()
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .load:
                guard task == nil, domain.load.needsLoad else { return }
                load(domain.url)
            case .selectCategory(let index):
                select(index)
            }
        }

        private func select(_ index: Int) {
            guard domain.categories.indices.contains(index),
                  index != domain.selectedIndex || domain.load.needsLoad,
                  let url = domain.categories[index].url else { return }
            mutate { $0.selectedIndex = index }
            load(url)
        }

        private func load(_ url: URL?) {
            task?.cancel()
            task = nil
            guard let url else {
                mutate { $0.load = .failed }
                return
            }
            if let page = domain.pages[url] {
                mutate { $0.show(page, from: url) }
                return
            }
            mutate {
                $0.url = url
                $0.load = .loading
            }
            let loadPage = loadPage
            task = Task { @MainActor [weak self] in
                let page = await loadPage(url)
                guard !Task.isCancelled, let self else { return }
                self.task = nil
                guard let page else {
                    self.mutate { $0.load = .failed }
                    return
                }
                self.mutate {
                    $0.pages[url] = page
                    $0.show(page, from: url)
                }
                self.openContextCategoryIfNeeded(page)
            }
        }

        /// A rider's standing may only know the ranking's link; then the page opens on its default
        /// category, and this moves to the rider's one once.
        private func openContextCategoryIfNeeded(_ page: DTO.CXStandingPage) {
            guard !didMatchContextCategory else { return }
            didMatchContextCategory = true
            guard let category = domain.context.category,
                  let index = page.categories.firstIndex(where: {
                      $0.title.caseInsensitiveCompare(category) == .orderedSame
                  }),
                  index != page.selectedIndex else { return }
            select(index)
        }

        private func mutate(_ change: (inout Domain) -> Void) {
            var domain = subject.value
            change(&domain)
            subject.send(domain)
        }
    }
}

private extension CXRaces.Ranking.Domain {
    mutating func show(
        _ page: DTO.CXStandingPage,
        from url: URL
    ) {
        self.url = url
        load = .loaded(page)
        if !page.categories.isEmpty {
            categories = page.categories
        }
        selectedIndex = page.categories.indices.contains(page.selectedIndex)
            ? page.selectedIndex
            : selectedIndex
    }
}
