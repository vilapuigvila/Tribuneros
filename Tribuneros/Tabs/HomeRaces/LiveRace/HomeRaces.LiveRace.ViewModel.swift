//
//  HomeRaces.LiveRace.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

/// "HH:mm:ss" in the device's time zone, for the "Updated" line.
private let liveUpdatedFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
}()

extension HomeRaces.LiveRace {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == HomeRaces.LiveRace.Domain, Interactor.UseCase == HomeRaces.LiveRace.UseCase {

        @Published private(set) var stateView: ViewState

        let router: Router
        let interactor: Interactor

        init(
            context: Context,
            router: Router,
            interactor: Interactor
        ) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(
                context: context,
                domain: interactor.domain,
                now: Date()
            )
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { domain in
                    Self.mapToViewState(
                        context: context,
                        domain: domain,
                        now: Date()
                    )
                }
                .assign(to: &$stateView)
        }

        func action(_ action: Action) {
            switch action {
            case .onAppear:
                interactor.useCase(.start)
            case .onDisappear:
                interactor.useCase(.stop)
            case .refresh:
                interactor.useCase(.refresh)
            case .dismissHint:
                interactor.useCase(.dismissHint)
            case .openOnPCS:
                guard let url = stateView.pcsURL else { return }
                router.routeTo(.web(url))
            }
        }

        /// Pull to refresh, awaited by `.refreshable`: returns once the restarted window's first
        /// page has landed.
        func refresh() async {
            guard let refreshing = interactor as? LiveRefreshing else {
                interactor.useCase(.refresh)
                return
            }
            await refreshing.refresh()
        }

        static func mapToViewState(
            context: Context,
            domain: Domain,
            now: Date
        ) -> ViewState {
            ViewState(
                title: context.name,
                subtitle: context.subtitle,
                flagCode: context.flagCode,
                body: bodyState(
                    domain,
                    now: now
                ),
                isPolling: domain.isPolling,
                updatedText: updatedLine(domain.updatedAt),
                showHint: domain.showHint,
                pcsURL: context.url
            )
        }

        private static func bodyState(
            _ domain: Domain,
            now: Date
        ) -> ViewState.Body {
            switch domain.load {
            case .idle, .loading:
                return .loading
            case .failed:
                return .unavailable(message: "Couldn't load the live race. Pull down to try again.")
            case .loaded(let page):
                return .loaded(
                    content(
                        page,
                        updatedAt: domain.updatedAt ?? now
                    )
                )
            }
        }

        private static func content(
            _ page: DTO.LivePage,
            updatedAt: Date
        ) -> ViewState.Content {
            ViewState.Content(
                stats: page.stats.map { viewStat($0) },
                profile: viewProfile(page),
                groups: page.groups.map { viewGroup($0) },
                events: page.events.map {
                    viewEvent(
                        $0,
                        updatedAt: updatedAt
                    )
                }
            )
        }

        private static func viewStat(_ stat: DTO.LivePage.Stat) -> ViewState.Stat {
            ViewState.Stat(
                label: stat.label.uppercased(),
                value: stat.value,
                isHighlighted: isHighlighted(stat)
            )
        }

        /// The race status and Autosync "on" get the accent colour.
        private static func isHighlighted(_ stat: DTO.LivePage.Stat) -> Bool {
            switch stat.key {
            case "race_status":
                return true
            case "autosync":
                return stat.value.lowercased() == "on"
            default:
                return false
            }
        }

        /// No profile when PCS draws no points.
        private static func viewProfile(_ page: DTO.LivePage) -> ViewState.Profile? {
            guard let profile = page.profile, !profile.points.isEmpty else { return nil }
            return ViewState.Profile(
                points: profile.points,
                progress: profile.progress,
                elevationLabels: profile.elevationLabels,
                keypoints: profile.keypoints
            )
        }

        private static func viewGroup(_ group: DTO.LivePage.Group) -> ViewState.Group {
            ViewState.Group(
                badge: group.badge,
                name: group.name,
                gap: group.gap,
                riders: group.riders
            )
        }

        private static func viewEvent(
            _ event: DTO.LivePage.Event,
            updatedAt: Date
        ) -> ViewState.Event {
            ViewState.Event(
                id: event.id,
                badge: event.badge,
                text: event.text,
                ago: ago(
                    event.timestamp,
                    since: updatedAt
                ),
                header: event.header,
                rows: event.rows
            )
        }

        /// "now" under a minute, then "4m", then "2h", measured from the last update; empty when
        /// PCS gives no time for the event.
        static func ago(
            _ timestamp: Date?,
            since reference: Date
        ) -> String {
            guard let timestamp else { return "" }
            let minutes = Int(reference.timeIntervalSince(timestamp) / 60)
            if minutes < 1 {
                return "now"
            }
            if minutes < 60 {
                return "\(minutes)m"
            }
            return "\(minutes / 60)h"
        }

        /// "Updated 12:04:31", empty before the first load.
        private static func updatedLine(_ date: Date?) -> String {
            guard let date else { return "" }
            return "Updated " + liveUpdatedFormatter.string(from: date)
        }
    }
}
