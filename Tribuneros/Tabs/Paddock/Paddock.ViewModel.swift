//
//  Paddock.ViewModel.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import Foundation
import Combine

extension Paddock {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == Paddock.Domain, Interactor.UseCase == Paddock.UseCase {

        @Published private(set) var stateView: Paddock.ViewState = .idle

        let router: Router
        let interactor: Interactor

        init(router: Router, interactor: Interactor) {
            self.router = router
            self.interactor = interactor
            registerPublisher()
        }

        private func registerPublisher() {
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { domain in
                    Self.mapToViewState(
                        from: domain,
                        now: Date()
                    )
                }
                .assign(to: &$stateView)
        }

        func action(_ action: Paddock.Action) {
            switch action {
            case .didAppear:
                guard interactor.domain.lastUpdated == nil else { return }
                interactor.useCase(.request)
            case .didRequestRefresh:
                interactor.useCase(.request)
            case .didSelectFilter(let filter):
                interactor.useCase(.selectFilter(filter))
            case .didTapOnLink(let url):
                guard let url else { return }
                router.routeTo(.web(url))
            case .didTapOnRider(let context):
                router.routeTo(.paddockRider(context))
            }
        }

        static func mapToViewState(
            from domain: Paddock.Domain,
            now: Date,
            calendar: Calendar = .current
        ) -> Paddock.ViewState {
            Paddock.ViewState(
                press: domain.press.map { links in
                    Paddock.Press.loaded(links.map(Paddock.PressItem.init(link:)))
                } ?? .loading,
                filter: domain.filter,
                feed: mapFeed(
                    from: domain,
                    now: now,
                    calendar: calendar
                )
            )
        }

        private static func mapFeed(
            from domain: Paddock.Domain,
            now: Date,
            calendar: Calendar
        ) -> Paddock.Feed {
            guard !domain.events.isEmpty else {
                if domain.error != nil {
                    return .error
                }
                return domain.lastUpdated == nil || domain.loading ? .loading : .empty
            }
            let visible = domain.events
                .enumerated()
                .filter { domain.filter.includes($0.element.kind) }
                .sorted { lhs, rhs in
                    lhs.element.date == rhs.element.date
                        ? lhs.offset < rhs.offset
                        : lhs.element.date > rhs.element.date
                }
            let grouped = Dictionary(grouping: visible) { entry in
                sectionTitle(
                    for: entry.element.date,
                    now: now,
                    calendar: calendar
                )
            }
            let sections = ["Today", "Yesterday", "Earlier"].compactMap { title -> Paddock.Section? in
                guard let entries = grouped[title] else { return nil }
                return Paddock.Section(
                    title: title,
                    cards: entries.map { card(for: $0.element, index: $0.offset) }
                )
            }
            return .loaded(sections)
        }

        private static func sectionTitle(
            for date: Date,
            now: Date,
            calendar: Calendar
        ) -> String {
            if calendar.isDate(date, inSameDayAs: now) {
                return "Today"
            }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
               calendar.isDate(date, inSameDayAs: yesterday) {
                return "Yesterday"
            }
            return "Earlier"
        }

        private static func card(for event: Paddock.Domain.Event, index: Int) -> Paddock.Card {
            switch event.kind {
            case .transfer(let transfer):
                .transfer(
                    .init(
                        id: "transfer-\(index)",
                        date: transfer.date,
                        rider: .init(transfer.rider),
                        teamName: transfer.teamName
                    )
                )
            case .programUpdate(let update):
                .program(
                    .init(
                        id: "program-\(index)",
                        timeAgo: update.timeAgo,
                        rider: .init(update.rider),
                        changes: update.changes.map {
                            .init(
                                isAdded: $0.isAdded,
                                raceName: $0.raceName
                            )
                        }
                    )
                )
            case .birthdays(let birthdays):
                .birthdays(
                    .init(
                        id: "birthdays-\(index)",
                        entries: birthdays.map {
                            .init(
                                rider: .init($0.rider),
                                age: $0.age
                            )
                        }
                    )
                )
            }
        }
    }
}

extension Paddock.Filter {
    func includes(_ kind: Paddock.Domain.Event.Kind) -> Bool {
        switch (self, kind) {
        case (.all, _), (.transfers, .transfer), (.programs, .programUpdate), (.birthdays, .birthdays):
            true
        default:
            false
        }
    }
}

extension Paddock.Rider {
    init(_ link: DTO.RiderLink) {
        self.init(
            name: link.name,
            countryCode: link.countryCode,
            url: link.url
        )
    }
}

extension Paddock.PressItem {
    init(link: DTO.PressLink) {
        let host = link.url.host ?? link.url.absoluteString
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        self.init(
            url: link.url,
            name: link.name ?? domain,
            domain: link.name == nil ? nil : domain
        )
    }
}
