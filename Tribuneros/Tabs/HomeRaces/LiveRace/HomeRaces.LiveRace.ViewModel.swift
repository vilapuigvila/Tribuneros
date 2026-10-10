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
                domain: interactor.domain
            )
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { domain in
                    Self.mapToViewState(
                        context: context,
                        domain: domain
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
            domain: Domain
        ) -> ViewState {
            ViewState(
                title: context.name,
                subtitle: context.subtitle,
                flagCode: context.flagCode,
                body: bodyState(domain),
                isPolling: domain.isPolling,
                updatedText: updatedLine(domain.updatedAt),
                showHint: domain.showHint,
                pcsURL: context.url
            )
        }

        private static func bodyState(_ domain: Domain) -> ViewState.Body {
            switch domain.load {
            case .idle, .loading:
                return .loading
            case .failed:
                return .unavailable(message: "Couldn't load the live race. Pull down to try again.")
            case .loaded(let page):
                return .loaded(content(page))
            }
        }

        private static func content(_ page: DTO.LivePage) -> ViewState.Content {
            ViewState.Content(
                stats: statStrip(page.stats),
                profile: viewProfile(page),
                groups: page.groups.enumerated().map { index, group in
                    viewGroup(
                        group,
                        isFirst: index == 0
                    )
                }
            )
        }

        /// The KPI strip in screen order; Autosync and #online are left out.
        static func statStrip(_ stats: [DTO.LivePage.Stat]) -> [ViewState.Stat] {
            let order = ["km to go", "km done", "racetime", "avg.", "elevation-", "start", "status"]
            return order.compactMap { key -> ViewState.Stat? in
                guard let stat = stats.first(where: { $0.label.lowercased() == key }) else {
                    return nil
                }
                if key == "elevation-", stat.value == "-" || stat.value.isEmpty {
                    return nil
                }
                return ViewState.Stat(
                    label: stat.label.uppercased(),
                    value: stat.value,
                    isHighlighted: stat.key == "race_status"
                )
            }
        }

        /// No profile without points; the peloton's km is estimated (`estimatedPelotonKm`).
        private static func viewProfile(_ page: DTO.LivePage) -> ViewState.Profile? {
            guard let profile = page.profile, !profile.points.isEmpty else { return nil }
            let frontKm = numberStat(page.stats, label: "km done")
            let averageKmh = numberStat(page.stats, label: "avg.")
            let peloton = page.groups.first(where: { $0.isPeloton })
            return ViewState.Profile(
                points: profile.points,
                progress: profile.progress,
                keypoints: profile.keypoints,
                kmLabels: profile.kmLabels,
                routeKm: profile.routeKm,
                frontKm: frontKm,
                pelotonKm: estimatedPelotonKm(
                    frontKm: frontKm,
                    gapSeconds: peloton?.gapSeconds,
                    averageKmh: averageKmh
                ),
                elevationLabels: profile.elevationLabels
            )
        }

        private static func numberStat(
            _ stats: [DTO.LivePage.Stat],
            label: String
        ) -> Double? {
            stats.first(where: { $0.label.lowercased() == label }).flatMap { Double($0.value) }
        }

        /// The front's km done minus the gap at the front's average speed; nil when unknown.
        static func estimatedPelotonKm(
            frontKm: Double?,
            gapSeconds: Int?,
            averageKmh: Double?
        ) -> Double? {
            guard let frontKm, let gapSeconds, let averageKmh else { return nil }
            return max(frontKm - Double(gapSeconds) * averageKmh / 3600, 0)
        }

        /// The first group is the head of the race, so it shows no gap; the others show PCS's gap.
        private static func viewGroup(
            _ group: DTO.LivePage.Group,
            isFirst: Bool
        ) -> ViewState.Group {
            ViewState.Group(
                badge: group.badge,
                name: group.name.uppercased(),
                gap: isFirst ? "" : group.gap,
                isPeloton: group.isPeloton,
                riders: group.riders.map { rider in
                    ViewState.Rider(
                        position: rider.position.map { String($0) } ?? "",
                        bib: rider.bib,
                        name: rider.name,
                        countryCode: rider.countryCode
                    )
                }
            )
        }

        /// "Updated 12:04:31", empty before the first load.
        private static func updatedLine(_ date: Date?) -> String {
            guard let date else { return "" }
            return "Updated " + liveUpdatedFormatter.string(from: date)
        }
    }
}
