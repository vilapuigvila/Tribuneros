//
//  RaceAlerts.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension RaceAlerts {

    /// One instance for the whole tab bar, so CX Zone and Settings show the same choices at once.
    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == RaceAlerts.Domain, Interactor.UseCase == RaceAlerts.UseCase {

        @Published private(set) var stateView: RaceAlerts.ViewState

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

        func action(_ action: RaceAlerts.Action) {
            switch action {
            case .didRequestAuthorizationRefresh:
                interactor.useCase(.refreshAuthorization)
            case .didToggle(let series, let isOn):
                interactor.useCase(.setFollowing(series, isOn))
            case .didTapOpenSystemSettings:
                guard let url = RaceAlerts.systemSettingsURL else { return }
                router.openInSystem(url)
            case .didLoadCalendar(let calendar):
                interactor.useCase(.updateCalendar(calendar))
            }
        }

        static func mapToViewState(
            from domain: RaceAlerts.Domain,
            now: Date = Date()
        ) -> RaceAlerts.ViewState {
            let isBlocked = domain.authorization == .blocked
            let followedCount = RaceAlerts.series.filter { domain.followed.contains($0) }.count
            let bell: RaceAlerts.Bell = isBlocked
                ? .blocked
                : followedCount == 0 ? .none : .following(followedCount)
            return RaceAlerts.ViewState(
                bell: bell,
                alertOnSeries: isBlocked ? [] : domain.followed,
                cxSheet: sheet(
                    from: domain,
                    calendar: domain.calendar,
                    now: now
                ),
                settingsSheet: sheet(
                    from: domain,
                    calendar: [],
                    now: now
                ),
                notificationsSubtitle: domain.authorization == .allowed
                    ? L10n.tr("On in iOS")
                    : L10n.tr("Off in iOS"),
                raceAlertsSubtitle: followedCount == 0
                    ? L10n.tr("Off")
                    : L10n.tr("%lld series", followedCount)
            )
        }

        private static func sheet(
            from domain: RaceAlerts.Domain,
            calendar: [DTO.CXCalendarEvent],
            now: Date
        ) -> RaceAlerts.Sheet {
            let isBlocked = domain.authorization == .blocked
            let rows = RaceAlerts.series.map { series in
                let isOn = domain.followed.contains(series)
                let subtitle: String
                if isBlocked {
                    subtitle = L10n.tr("Needs notifications in iOS")
                } else if !isOn {
                    subtitle = L10n.tr("Off")
                } else if let next = nextRound(
                    of: series,
                    in: calendar,
                    now: now
                ) {
                    subtitle = L10n.tr(
                        "On · next: %1$@, %2$@",
                        RaceAlerts.venue(of: next.event.race),
                        L10n.dateFormatter(template: "dMMM").string(from: next.date)
                    )
                } else {
                    subtitle = L10n.tr("On")
                }
                return RaceAlerts.Row(
                    series: series,
                    title: series.title,
                    subtitle: subtitle,
                    isOn: isOn && !isBlocked,
                    isEnabled: !isBlocked
                )
            }
            return RaceAlerts.Sheet(
                isBlocked: isBlocked,
                rows: rows
            )
        }

        private static func nextRound(
            of series: CXRaces.RaceSeries,
            in calendar: [DTO.CXCalendarEvent],
            now: Date
        ) -> CXRaces.SeriesLens.Round? {
            guard !calendar.isEmpty else { return nil }
            return CXRaces.SeriesLens(
                series: series,
                representable: CXRaces.Representable(
                    calendarEvents: calendar,
                    races: .init(sections: []),
                    standings: .init(items: [])
                ),
                now: now
            ).nextRound
        }
    }
}

extension RaceAlerts {
    /// Series words in front of the venue ("World Cup Namur" → "Namur"); a name with nothing left stays whole.
    private static let seriesPrefixes = [
        "uci cyclocross world cup",
        "uci world cup",
        "world cup",
        "superprestige",
        "x2o badkamers trofee",
        "x2o trofee",
        "exact cross"
    ]

    static func venue(of race: String) -> String {
        let trimmed = race.trimmingCharacters(in: .whitespaces)
        let lowered = trimmed.lowercased()
        guard let prefix = seriesPrefixes.first(where: { lowered.hasPrefix($0) }) else { return trimmed }
        let venue = trimmed
            .dropFirst(prefix.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: " -–:"))
        return venue.isEmpty ? trimmed : venue
    }
}
