//
//  HomeRaces.WhereToWatch.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension HomeRaces.WhereToWatch {

    enum Load: Equatable {
        case loading
        case loaded(DTO.CourseDuJourPage)
        case failed
    }

    struct Domain: Equatable {
        /// The opening load (the site's today, date not known yet) lives under this key.
        static let openingKey = "today"

        /// The race the screen was opened from; its day loads first.
        let key: RaceKey?
        /// "yyyy-MM-dd"; nil until the opening page is in.
        var selected: String?
        var days: [DTO.CourseDuJourPage.Day] = []
        var loads: [String: Load] = [:]

        var current: Load {
            loads[selected ?? Self.openingKey] ?? .loading
        }
    }

    enum UseCase: Sendable {
        case load
        case select(String)
        case retry
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = HomeRaces.WhereToWatch.Domain
        typealias UseCase = HomeRaces.WhereToWatch.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Fetches a day (nil is the site's today); injectable so tests never hit the network.
        private let loadPage: (String?) async -> DTO.CourseDuJourPage?
        private var tasks: [String: Task<Void, Never>] = [:]

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            key: RaceKey?,
            loadPage: @escaping (String?) async -> DTO.CourseDuJourPage? = {
                await Service.getCourseDuJourPage(date: $0)
            }
        ) {
            subject = CurrentValueSubject<Domain, Never>(Domain(key: key))
            self.loadPage = loadPage
        }

        deinit {
            tasks.values.forEach { $0.cancel() }
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .load:
                guard domain.selected == nil, domain.loads.isEmpty else { return }
                if let date = domain.key?.date {
                    mutate { $0.selected = date }
                    fetch(date: date)
                } else {
                    fetch(date: nil)
                }
            case .select(let date):
                guard date != domain.selected else { return }
                mutate { $0.selected = date }
                if domain.loads[date] == nil {
                    fetch(date: date)
                }
            case .retry:
                guard case .failed = domain.current else { return }
                fetch(date: domain.selected)
            }
        }

        private func fetch(date: String?) {
            let key = date ?? Domain.openingKey
            guard tasks[key] == nil else { return }
            mutate { $0.loads[key] = .loading }
            let loadPage = loadPage
            tasks[key] = Task { @MainActor [weak self] in
                let page = await loadPage(date)
                guard !Task.isCancelled else { return }
                self?.finish(
                    key: key,
                    page: page
                )
            }
        }

        private func finish(
            key: String,
            page: DTO.CourseDuJourPage?
        ) {
            tasks[key] = nil
            mutate { domain in
                guard let page else {
                    domain.loads[key] = .failed
                    return
                }
                if key == Domain.openingKey {
                    domain.loads[key] = nil
                    domain.selected = page.date
                    domain.loads[page.date] = .loaded(page)
                } else {
                    domain.loads[key] = .loaded(page)
                }
                if domain.days.isEmpty {
                    domain.days = page.days
                }
            }
        }

        private func mutate(_ change: (inout Domain) -> Void) {
            var domain = subject.value
            change(&domain)
            subject.send(domain)
        }
    }
}
