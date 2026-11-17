//
//  RaceAlerts.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine
import UserNotifications

extension RaceAlerts {
    enum Authorization: Equatable, Sendable {
        case notDetermined
        case allowed
        case blocked

        init(_ status: UNAuthorizationStatus) {
            switch status {
            case .denied: self = .blocked
            case .notDetermined: self = .notDetermined
            default: self = .allowed
            }
        }

        /// The iOS permission, read through `UNUserNotificationCenter`; mocked launches never ask iOS.
        static func current() async -> Authorization {
            #if DEBUG
            if let mocked = mocked(
                isMockedLaunch: HomeRaces.MockScenario.current != nil,
                environment: ProcessInfo.processInfo.environment,
                launchValue: UserDefaults.standard.string(forKey: "notificationsStatus")
            ) {
                return mocked
            }
            #endif
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return Authorization(settings.authorizationStatus)
        }

        #if DEBUG
        /// Mocked launches report allowed unless `NOTIFICATIONS_STATUS` (or a `notificationsStatus` launch argument) says `blocked` or `undetermined`.
        static func mocked(
            isMockedLaunch: Bool,
            environment: [String: String],
            launchValue: String?
        ) -> Authorization? {
            guard isMockedLaunch, !RaceAlerts.isLiveInMock else { return nil }
            switch (environment["NOTIFICATIONS_STATUS"] ?? launchValue)?.lowercased() {
            case "blocked", "denied": return .blocked
            case "undetermined", "notdetermined": return .notDetermined
            default: return .allowed
            }
        }
        #endif
    }

    struct Domain: Equatable {
        var followed: Set<CXRaces.RaceSeries> = []
        var authorization: Authorization = .notDetermined
        var calendar: [DTO.CXCalendarEvent] = []
    }

    enum UseCase: Sendable {
        case setFollowing(CXRaces.RaceSeries, Bool)
        case refreshAuthorization
        case updateCalendar([DTO.CXCalendarEvent])
        case replan
    }

    struct Store {
        var loadFollowed: () -> [String]?
        var saveFollowed: ([String]) -> Void
        var authorization: @Sendable () async -> Authorization
        var loadCalendar: @Sendable () async -> [DTO.CXCalendarEvent]? = {
            try? await Service.getCxAllCalendarEvents()
        }
        var loadSchedules: @Sendable () async -> [DTO.CXSchedules.Entry] = {
            await Service.getCxSchedules()
        }
        var scheduler: NotificationScheduling = Store.defaultScheduler
        var now: @Sendable () -> Date = { Date() }

        static var defaultScheduler: NotificationScheduling {
            #if DEBUG
            if HomeRaces.MockScenario.current != nil, !RaceAlerts.isLiveInMock { return NoOpScheduler() }
            #endif
            return UserNotificationScheduler()
        }

        static let userSettings = Store(
            loadFollowed: { UserSettings.raceAlertSeries },
            saveFollowed: { UserSettings.raceAlertSeries = $0 },
            authorization: { await Authorization.current() }
        )
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = RaceAlerts.Domain
        typealias UseCase = RaceAlerts.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        private let store: Store
        private var authorizationTask: Task<Void, Never>?
        private var replanTask: Task<Void, Never>?

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(store: Store = .userSettings) {
            self.store = store
            let stored = Set((store.loadFollowed() ?? []).compactMap(CXRaces.RaceSeries.init(rawValue:)))
            subject = CurrentValueSubject(
                Domain(followed: stored.intersection(RaceAlerts.series))
            )
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .setFollowing(let series, let isOn):
                setFollowing(series, isOn: isOn)
            case .refreshAuthorization:
                authorizationTask?.cancel()
                authorizationTask = Task { @MainActor [weak self] in
                    await self?.refreshAuthorization()
                    self?.enqueueReplan(requestPermission: false)
                }
            case .replan:
                enqueueReplan(requestPermission: false)
            case .updateCalendar(let calendar):
                guard calendar != subject.value.calendar else { return }
                var updated = subject.value
                updated.calendar = calendar
                subject.send(updated)
            }
        }

        @MainActor
        func refreshAuthorization() async {
            let authorization = await store.authorization()
            guard !Task.isCancelled, authorization != subject.value.authorization else { return }
            var updated = subject.value
            updated.authorization = authorization
            subject.send(updated)
        }

        private func setFollowing(
            _ series: CXRaces.RaceSeries,
            isOn: Bool
        ) {
            guard RaceAlerts.series.contains(series),
                  subject.value.followed.contains(series) != isOn
            else { return }
            var updated = subject.value
            if isOn {
                updated.followed.insert(series)
            } else {
                updated.followed.remove(series)
            }
            store.saveFollowed(
                RaceAlerts.series
                    .filter { updated.followed.contains($0) }
                    .map(\.rawValue)
            )
            subject.send(updated)
            enqueueReplan(requestPermission: isOn)
        }

        /// Replans run one after another, so overlapping triggers never leave a half set.
        @discardableResult
        private func enqueueReplan(requestPermission: Bool) -> Task<Void, Never> {
            let previous = replanTask
            let task = Task { @MainActor [weak self] in
                await previous?.value
                await self?.replan(requestPermission: requestPermission)
            }
            replanTask = task
            return task
        }

        func waitForReplan() async {
            await replanTask?.value
        }

        @MainActor
        private func replan(requestPermission: Bool) async {
            var authorization = await store.authorization()
            if requestPermission, authorization == .notDetermined, !subject.value.followed.isEmpty {
                _ = await store.scheduler.requestAuthorization()
                authorization = await store.authorization()
            }
            if authorization != subject.value.authorization {
                var updated = subject.value
                updated.authorization = authorization
                subject.send(updated)
            }
            let scheduler = store.scheduler
            let followed = subject.value.followed
            guard authorization == .allowed, !followed.isEmpty else {
                await removeRaceAlerts(from: scheduler)
                return
            }
            guard let calendar = await store.loadCalendar() else {
                await removeRaceAlerts(from: scheduler) { id in
                    Planner.series(ofID: id).map { !followed.contains($0) } ?? true
                }
                return
            }
            let schedules = await store.loadSchedules()
            let alerts = Planner.alerts(
                followed: followed,
                calendar: calendar,
                schedules: schedules,
                now: store.now(),
                pending: Set(await scheduler.pendingIdentifiers())
            )
            await removeRaceAlerts(from: scheduler)
            await scheduler.add(alerts)
        }

        private func removeRaceAlerts(
            from scheduler: NotificationScheduling,
            where shouldRemove: (String) -> Bool = { _ in true }
        ) async {
            let ids = await scheduler.pendingIdentifiers().filter { $0.hasPrefix(Planner.idPrefix) && shouldRemove($0) }
            guard !ids.isEmpty else { return }
            scheduler.remove(identifiers: ids)
        }
    }
}
