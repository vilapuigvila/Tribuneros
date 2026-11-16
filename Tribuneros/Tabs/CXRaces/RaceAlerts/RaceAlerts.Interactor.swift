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
            guard isMockedLaunch else { return nil }
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
    }

    struct Store {
        var loadFollowed: () -> [String]?
        var saveFollowed: ([String]) -> Void
        var authorization: @Sendable () async -> Authorization

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
                }
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
        }
    }
}
