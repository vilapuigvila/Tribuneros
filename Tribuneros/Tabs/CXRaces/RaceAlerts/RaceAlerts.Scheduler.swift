//
//  RaceAlerts.Scheduler.swift
//  Tribuneros
//

import Foundation
import UserNotifications

extension RaceAlerts {
    struct UserNotificationScheduler: NotificationScheduling {
        private var center: UNUserNotificationCenter { .current() }

        /// Notification sounds can't be AAC: `Music/start.m4a` and `end.m4a` shipped as 16-bit PCM `.caf`.
        static func soundFileName(for kind: PlannedAlert.Kind) -> String {
            switch kind {
            case .start: "race_start.caf"
            case .finish: "race_end.caf"
            }
        }

        func pendingIdentifiers() async -> [String] {
            await center.pendingNotificationRequests().map(\.identifier)
        }

        func remove(identifiers: [String]) {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        #if DEBUG
        /// `RACE_ALERTS_LIVE` mock finish alerts fire 30 s, 60 s… after the first one is scheduled (the planner's own times are minutes to an hour away).
        private static let mockAnchor = Date()

        private func mockFireInterval(for alert: PlannedAlert, in alerts: [PlannedAlert]) -> TimeInterval? {
            guard RaceAlerts.isLiveInMock, alert.kind == .finish, alert.id.contains("mock") else { return nil }
            let mocks = alerts.filter { $0.kind == .finish && $0.id.contains("mock") }
                .sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
            guard let rank = mocks.firstIndex(where: { $0.id == alert.id }) else { return nil }
            return Self.mockAnchor.addingTimeInterval(TimeInterval(30 * (rank + 1))).timeIntervalSinceNow
        }
        #endif

        func add(_ alerts: [PlannedAlert]) async {
            for alert in alerts {
                let content = UNMutableNotificationContent()
                content.title = alert.title
                content.body = alert.body
                content.sound = UNNotificationSound(
                    named: UNNotificationSoundName(Self.soundFileName(for: alert.kind))
                )
                content.userInfo = alert.userInfo
                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: alert.fireDate
                )
                var trigger: UNNotificationTrigger = UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: false
                )
                #if DEBUG
                if let interval = mockFireInterval(for: alert, in: alerts) {
                    guard interval > 1 else { continue }
                    trigger = UNTimeIntervalNotificationTrigger(
                        timeInterval: interval,
                        repeats: false
                    )
                }
                #endif
                let request = UNNotificationRequest(
                    identifier: alert.id,
                    content: content,
                    trigger: trigger
                )
                do {
                    try await center.add(request)
                } catch {
                    AppLogger.preferences.error("Race alert not scheduled: \(error.localizedDescription)")
                }
            }
        }

        func requestAuthorization() async -> Bool {
            (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    #if DEBUG
    /// `RACE_ALERTS_LIVE=1` (or `raceAlertsLive`): a mocked launch schedules real alerts and adds tonight's mock races.
    static var isLiveInMock: Bool {
        Onboarding.debugFlag(
            environment: ProcessInfo.processInfo.environment,
            key: "RACE_ALERTS_LIVE",
            launchValue: UserDefaults.standard.string(forKey: "raceAlertsLive")
        ) ?? false
    }
    #endif

    /// Mocked launches never touch `UNUserNotificationCenter`.
    struct NoOpScheduler: NotificationScheduling {
        func pendingIdentifiers() async -> [String] { [] }
        func remove(identifiers: [String]) {}
        func add(_ alerts: [PlannedAlert]) async {}
        func requestAuthorization() async -> Bool { true }
    }
}
