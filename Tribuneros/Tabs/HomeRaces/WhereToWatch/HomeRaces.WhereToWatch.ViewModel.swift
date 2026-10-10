//
//  HomeRaces.WhereToWatch.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension HomeRaces.WhereToWatch {

    private enum Formatters {
        static let time: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_GB")
            formatter.timeZone = TimeZone(identifier: "Europe/Paris")
            formatter.dateFormat = "HH:mm"
            return formatter
        }()

        static let day: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }()
    }

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == HomeRaces.WhereToWatch.Domain, Interactor.UseCase == HomeRaces.WhereToWatch.UseCase {

        @Published private(set) var stateView: ViewState

        let router: Router
        let interactor: Interactor

        init(
            router: Router,
            interactor: Interactor
        ) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(domain: interactor.domain)
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { Self.mapToViewState(domain: $0) }
                .assign(to: &$stateView)
        }

        func action(_ action: Action) {
            switch action {
            case .onAppear:
                interactor.useCase(.load)
            case .select(let date):
                interactor.useCase(.select(date))
            case .retry:
                interactor.useCase(.retry)
            }
        }

        static func mapToViewState(
            domain: Domain,
            now: Date = Date(),
            calendar: Calendar = .current
        ) -> ViewState {
            let days = domain.days
                .filter { $0.offset >= 0 }
                .map { day in
                    ViewState.Day(
                        id: day.date,
                        weekday: weekday(
                            day.date,
                            now: now,
                            calendar: calendar
                        ),
                        number: dayNumber(
                            day.date,
                            calendar: calendar
                        ),
                        count: L10n.tr("%lld races", day.raceCount),
                        isSelected: day.date == domain.selected
                    )
                }

            switch domain.current {
            case .loading:
                return ViewState(days: days, content: .loading)
            case .failed:
                return ViewState(days: days, content: .failed)
            case .loaded(let page):
                let key = domain.key.flatMap { $0.date == page.date ? $0 : nil }
                let matchedID = key.flatMap { HomeRaces.WhereToWatch.match($0, in: page)?.id }
                return ViewState(
                    days: days,
                    content: .loaded(
                        heading: page.heading,
                        updated: page.updatedAt.map {
                            L10n.tr(
                                "Coverage updated %@",
                                L10n.relativeFormatter(unitsStyle: .full).localizedString(for: $0, relativeTo: now)
                            )
                        },
                        featured: featured(
                            key: key,
                            matchedID: matchedID,
                            page: page,
                            now: now
                        ),
                        sections: page.sections.map {
                            section(
                                $0,
                                matchedID: matchedID,
                                now: now
                            )
                        }
                    )
                )
            }
        }

        private static func featured(
            key: RaceKey?,
            matchedID: String?,
            page: DTO.CourseDuJourPage,
            now: Date
        ) -> ViewState.Featured? {
            guard let key else { return nil }
            guard let matched = page.sections.flatMap(\.races).first(where: { $0.id == matchedID }) else {
                return .notListed(L10n.tr("%@ isn't in this day's TV listings.", key.title))
            }
            return .race(
                race(
                    matched,
                    matchedID: matchedID,
                    now: now
                )
            )
        }

        private static func section(
            _ section: DTO.CourseDuJourPage.Section,
            matchedID: String?,
            now: Date
        ) -> ViewState.Section {
            ViewState.Section(
                title: section.discipline,
                caption: section.caption,
                races: section.races.filter { $0.id != matchedID }.map {
                    race(
                        $0,
                        matchedID: matchedID,
                        now: now
                    )
                }
            )
        }

        private static func race(
            _ race: DTO.CourseDuJourPage.Race,
            matchedID: String?,
            now: Date
        ) -> ViewState.Race {
            let isLive = race.start.map { $0 <= now } == true && race.end.map { now < $0 } == true
            let isFinished = race.end.map { $0 <= now } == true
            let title = race.stage.map { "\(race.name) — \($0)" } ?? race.name
            let meta = [race.category, race.location]
                .filter { !$0.isEmpty }
                .joined(separator: "  ·  ")
            let time = window(
                start: race.start,
                end: race.end
            )
            let channels = race.broadcasters.map {
                ViewState.Channel(
                    name: $0.name,
                    regions: $0.regions,
                    time: window(
                        start: $0.start,
                        end: $0.end
                    )
                )
            }
            let spoken = [
                title,
                meta,
                isLive ? L10n.tr("live now") : isFinished ? L10n.tr("finished") : nil,
                time.isEmpty ? nil : time
            ]
            return ViewState.Race(
                id: race.id,
                title: title,
                meta: meta,
                time: time,
                isLive: isLive,
                isFinished: isFinished,
                isHighlighted: race.id == matchedID,
                channels: channels,
                accessibilityLabel: spoken.compactMap { $0 }.joined(separator: ", ")
            )
        }

        private static func window(
            start: Date?,
            end: Date?
        ) -> String {
            guard let start else { return "" }
            let from = Formatters.time.string(from: start)
            guard let end else { return from }
            return "\(from) – \(Formatters.time.string(from: end))"
        }

        private static func weekday(
            _ date: String,
            now: Date,
            calendar: Calendar
        ) -> String {
            guard let day = Formatters.day.date(from: date) else { return "" }
            if calendar.isDate(day, inSameDayAs: now) {
                return L10n.tr("TODAY")
            }
            return day
                .formatted(.dateTime.weekday(.abbreviated).locale(L10n.locale))
                .uppercased(with: L10n.locale)
        }

        private static func dayNumber(
            _ date: String,
            calendar: Calendar
        ) -> String {
            guard let day = Formatters.day.date(from: date) else { return "" }
            return "\(calendar.component(.day, from: day))"
        }
    }
}
