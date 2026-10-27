//
//  Tifosi.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension Tifosi {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == Tifosi.Domain, Interactor.UseCase == Tifosi.UseCase {

        @Published private(set) var stateView: Tifosi.ViewState

        let router: Router
        let interactor: Interactor

        init(router: Router, interactor: Interactor) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(from: interactor.domain)
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { Self.mapToViewState(from: $0) }
                .assign(to: &$stateView)
        }

        func action(_ action: Tifosi.Action) {
            switch action {
            case .didAppear:
                interactor.useCase(.appear)
            case .didSelectChannel(let channel):
                interactor.useCase(.selectChannel(channel))
            case .didTapTVChannel(let url):
                router.openInSystem(url)
            case .didRetryTV:
                interactor.useCase(.retryTV)
            case .didSelectTVDay(let date):
                interactor.useCase(.selectTVDay(date))
            case .didFeatureRace(let raceID, let day):
                interactor.useCase(.feature(raceID: raceID, day: day))
            }
        }

        static func mapToViewState(
            from domain: Tifosi.Domain,
            region: String? = Locale.current.region?.identifier
        ) -> Tifosi.ViewState {
            let scope = domain.filter.title
            let date = L10n.dateFormatter(template: "EEEddMMM").string(from: domain.date)
            return Tifosi.ViewState(
                dateLine: "\(date) · \(scope)",
                chips: Tifosi.Channel.chips.map {
                    Tifosi.Representable.Chip(
                        channel: $0,
                        title: $0.title,
                        isSelected: $0 == domain.filter,
                        isEnabled: $0.isAvailable
                    )
                },
                race: domain.race,
                leader: domain.leader,
                chase: domain.chase,
                showsTVGuide: domain.filter == .tv,
                tv: mapTVScreen(
                    domain,
                    region: region
                )
            )
        }

        static func mapTVScreen(
            _ domain: Tifosi.Domain,
            region: String?
        ) -> Tifosi.TVScreen {
            var days: [Tifosi.TVDay] = []
            if case .loaded(let today) = domain.tv {
                let selected = domain.tvDay ?? today.date
                days = today.days
                    .filter { $0.offset >= 0 }
                    .sorted { $0.offset < $1.offset }
                    .prefix(7)
                    .map { mapDay($0, isSelected: $0.date == selected) }
            }
            let dayTitle = domain.tvDay
                .flatMap { dayParser.date(from: $0) }
                .map { L10n.dateFormatter(template: "EEEEdMMMM").string(from: $0) } ?? ""
            return Tifosi.TVScreen(
                days: days,
                isToday: domain.tvDay == nil,
                dayTitle: dayTitle,
                state: mapTV(
                    domain.tvSelectedLoad,
                    region: region
                ),
                featuredRaceID: domain.featuredRaceID
            )
        }

        private static var dayParser: DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter
        }

        private static func mapDay(
            _ day: DTO.CourseDuJourPage.Day,
            isSelected: Bool
        ) -> Tifosi.TVDay {
            let date = dayParser.date(from: day.date)
            let weekday = day.offset == 0
                ? L10n.tr("TODAY")
                : date.map { L10n.dateFormatter(template: "EEE").string(from: $0).uppercased(with: L10n.locale) } ?? ""
            let dayNumber = date.map { L10n.dateFormatter(template: "d").string(from: $0) } ?? ""
            let name = day.offset == 0
                ? L10n.tr("Today")
                : date.map { L10n.dateFormatter(template: "EEEEdMMMM").string(from: $0) } ?? day.date
            return Tifosi.TVDay(
                date: day.date,
                offset: day.offset,
                weekday: weekday,
                dayNumber: dayNumber,
                raceCount: day.raceCount,
                isSelected: isSelected,
                accessibilityLabel: [name, L10n.tr("%lld races on TV", day.raceCount)].joined(separator: ", ")
            )
        }

        static func mapTV(
            _ load: Tifosi.TVLoad,
            region: String?
        ) -> Tifosi.TVState {
            switch load {
            case .idle, .loading:
                return .loading
            case .failed:
                return .failed
            case .loaded(let page):
                let races = page.sections
                    .flatMap { section in
                        section.races.map { (section.discipline, $0) }
                    }
                    .map { mapRace($0.1, discipline: $0.0, region: region) }
                    .sorted { lhs, rhs in
                        switch (lhs.start, rhs.start) {
                        case let (left?, right?): left < right
                        case (_?, nil): true
                        default: false
                        }
                    }
                return races.isEmpty ? .empty : .guide(Tifosi.TVGuide(races: races))
            }
        }

        private static func mapRace(
            _ race: DTO.CourseDuJourPage.Race,
            discipline: String,
            region: String?
        ) -> Tifosi.TVRace {
            let title = race.stage.map { "\(race.name) — \($0)" } ?? race.name // l10n:ignore
            let meta = [race.category, race.location]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            let channels = race.broadcasters.map { broadcaster in
                let codes = broadcaster.regions
                    .components(separatedBy: CharacterSet(charactersIn: ", "))
                    .filter { !$0.isEmpty }
                    .map { $0.uppercased() }
                return Tifosi.TVChannel(
                    name: broadcaster.name,
                    regions: broadcaster.regions,
                    url: broadcaster.url,
                    isLocal: region.map { codes.contains($0.uppercased()) } ?? false
                )
            }
            let local = channels.filter(\.isLocal)
            let others = channels.filter { !$0.isLocal }
            let end = race.end ?? race.start.map { $0.addingTimeInterval(3 * 3600) }
            return Tifosi.TVRace(
                id: race.id,
                title: title,
                meta: meta,
                discipline: discipline,
                start: race.start,
                end: end,
                startText: race.start.map { L10n.dateFormatter(template: "HHmm").string(from: $0) } ?? "–:–", // l10n:ignore
                channels: local + others
            )
        }
    }
}
