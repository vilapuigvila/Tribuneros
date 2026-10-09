//
//  Onboarding.swift
//  Tribuneros
//

import Foundation

enum Onboarding {
    struct Record: Equatable {
        var firstShown: Date?
        var count: Int
    }

    enum Schedule {
        static let repeatInterval: TimeInterval = 7 * 24 * 3600
        static let maxShowings = 2

        static func shouldShow(
            now: Date,
            firstShown: Date?,
            count: Int
        ) -> Bool {
            guard count < maxShowings else { return false }
            guard count > 0, let firstShown else { return true }
            return now.timeIntervalSince(firstShown) >= repeatInterval
        }

        static func showing(
            now: Date,
            record: Record
        ) -> Record? {
            guard shouldShow(
                now: now,
                firstShown: record.firstShown,
                count: record.count
            ) else { return nil }
            return Record(
                firstShown: record.firstShown ?? now,
                count: record.count + 1
            )
        }

        /// Debug: a fresh install looks like one showing a week ago, so the next launch is the second.
        static func seededForSecondShowing(
            _ record: Record,
            now: Date
        ) -> Record {
            guard record.count == 0 else { return record }
            return Record(
                firstShown: now.addingTimeInterval(-repeatInterval),
                count: 1
            )
        }
    }

    struct Store {
        var load: () -> Record
        var save: (Record) -> Void

        static let userSettings = Store(
            load: {
                Record(
                    firstShown: UserSettings.onboardingFirstShown,
                    count: UserSettings.onboardingShownCount ?? 0
                )
            },
            save: { record in
                UserSettings.onboardingFirstShown = record.firstShown
                UserSettings.onboardingShownCount = record.count
            }
        )
    }

    enum Dismissal {
        case skip
        case finish
    }

    static func isEnabled(
        override: Bool?,
        hasMockScenario: Bool
    ) -> Bool {
        override ?? !hasMockScenario
    }

    #if DEBUG
    /// Mocked launches (Maestro) skip it unless `ONBOARDING` or the `onboarding` launch argument turns it on.
    static var isEnabledAtLaunch: Bool {
        isEnabled(
            override: debugFlag(
                environment: ProcessInfo.processInfo.environment,
                key: "ONBOARDING",
                launchValue: UserDefaults.standard.string(forKey: "onboarding")
            ),
            hasMockScenario: HomeRaces.MockScenario.current != nil
        )
    }

    /// `ONBOARDING_SECOND_SHOWING` or the `onboardingSecondShowing` launch argument.
    static var seedsSecondShowing: Bool {
        debugFlag(
            environment: ProcessInfo.processInfo.environment,
            key: "ONBOARDING_SECOND_SHOWING",
            launchValue: UserDefaults.standard.string(forKey: "onboardingSecondShowing")
        ) ?? false
    }

    /// `RESET_ONBOARDING` or the `resetOnboarding` launch argument: forget the showings, so this launch is a first run.
    static var resetsAtLaunch: Bool {
        debugFlag(
            environment: ProcessInfo.processInfo.environment,
            key: "RESET_ONBOARDING",
            launchValue: UserDefaults.standard.string(forKey: "resetOnboarding")
        ) ?? false
    }

    static func debugFlag(
        environment: [String: String],
        key: String,
        launchValue: String?
    ) -> Bool? {
        (environment[key] ?? launchValue)
            .map { ["1", "on", "true", "yes"].contains($0.lowercased()) }
    }
    #else
    static let isEnabledAtLaunch = true
    static let seedsSecondShowing = false
    static let resetsAtLaunch = false
    #endif

    /// The launch splash covers the app for this long, so the onboarding waits for it to fade.
    static var splashDelay: Duration {
        LaunchSplash.isEnabledAtLaunch
            ? LaunchSplash.minimumDuration + .seconds(LaunchSplash.fadeDuration)
            : .zero
    }
}

extension Onboarding {
    @MainActor
    final class Presenter: ObservableObject {
        @Published private(set) var showing: Int?
        private let store: Store
        private let now: () -> Date
        private var hasStarted = false

        init(
            store: Store = .userSettings,
            now: @escaping () -> Date = Date.init
        ) {
            self.store = store
            self.now = now
        }

        func start(
            isEnabled: Bool,
            seedsSecondShowing: Bool = false,
            resets: Bool = false
        ) {
            guard !hasStarted else { return }
            hasStarted = true
            if resets {
                store.save(Record(firstShown: nil, count: 0))
            }
            guard isEnabled else { return }
            let date = now()
            var record = store.load()
            if seedsSecondShowing {
                record = Schedule.seededForSecondShowing(
                    record,
                    now: date
                )
            }
            guard let next = Schedule.showing(
                now: date,
                record: record
            ) else { return }
            store.save(next)
            showing = next.count
        }

        func dismiss(_ dismissal: Dismissal) {
            showing = nil
        }
    }
}

extension Onboarding {
    struct Page: Identifiable, Equatable {
        let id: Int
        let animation: String
        /// The frame shown instead of the loop with Reduce Motion.
        let stillProgress: Double
        let title: String
        let body: String

        var accessibilityLabel: String {
            "\(title). \(body)"
        }
    }

    static func pages(showing: Int) -> [Page] {
        [
            Page(
                id: 0,
                animation: "onboarding_welcome",
                stillProgress: 0.3,
                title: showing > 1 ? "Welcome back to Cycling Tribune" : "Welcome to Cycling Tribune",
                body: "Road and cyclocross results, calendars and cycling news, all in one place."
            ),
            Page(
                id: 1,
                animation: "onboarding_spoilers",
                stillProgress: 0.6,
                title: "Results without spoilers",
                body: "Results start hidden behind a painting. Press and hold one to reveal or hide it, then tap to open it."
            ),
            Page(
                id: 2,
                animation: "onboarding_cx",
                stillProgress: 0.5,
                title: "CX Zone",
                body: "Cyclocross races, results, standings and the whole season calendar."
            ),
            Page(
                id: 3,
                animation: "onboarding_paddock",
                stillProgress: 0.5,
                title: "The Paddock",
                body: "Transfers, race program changes, birthdays and the best cycling press."
            ),
        ]
    }
}
