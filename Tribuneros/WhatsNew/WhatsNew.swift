//
//  WhatsNew.swift
//  Tribuneros
//

import Foundation

enum WhatsNew {
    enum Tint: Equatable {
        case amber
        case blue
        case green
    }

    struct Item: Identifiable, Equatable {
        let id: String
        let systemImage: String
        let tint: Tint
        let title: String
        let body: String
    }

    struct Release: Identifiable, Equatable {
        let version: String
        let items: [Item]

        var id: String { version }
    }

    /// One entry per app version that has news; add the next release at the top. Built on each read so the strings follow the app language.
    static func releases() -> [Release] {
        [
            Release(
                version: "1.4",
                items: [
                    Item(
                        id: "raceAlerts",
                        systemImage: "bell",
                        tint: .amber,
                        title: L10n.tr("Race alerts"),
                        body: L10n.tr("Follow World Cup, Superprestige, X2O Trofee and Other Belgian races. The bell in CX Zone sets it up.")
                    ),
                    Item(
                        id: "racesAndTeams",
                        systemImage: "calendar",
                        tint: .blue,
                        title: L10n.tr("Races and teams"),
                        body: L10n.tr("Paddock now lists the whole calendar, men and women, plus every WorldTeam and ProTeam.")
                    ),
                    Item(
                        id: "euskara",
                        systemImage: "globe",
                        tint: .green,
                        title: L10n.tr("Now in Euskara"),
                        body: L10n.tr("Basque joins English, Castellano and Català. Pick it in Settings, Language.")
                    ),
                ]
            ),
        ]
    }

    static var currentVersion: String {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["WHATS_NEW_APP_VERSION"]
            ?? UserDefaults.standard.string(forKey: "whatsNewAppVersion") {
            return override
        }
        #endif
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// Releases up to the running version, newest first: what the Settings history lists.
    static func history(
        appVersion: String = currentVersion,
        releases: [Release] = releases()
    ) -> [Release] {
        releases
            .filter { compare($0.version, appVersion) != .orderedDescending }
            .sorted { compare($0.version, $1.version) == .orderedDescending }
    }

    static func compare(
        _ lhs: String,
        _ rhs: String
    ) -> ComparisonResult {
        lhs.compare(
            rhs,
            options: .numeric
        )
    }

    enum Schedule {
        struct Outcome: Equatable {
            /// The one screen to show, nil when this version has no news.
            var release: Release?
            /// The version to store as seen, nil to store nothing.
            var marker: String?
        }

        /// Once per app version: the first launch on a new version shows that version's release (if it has one) and stores the version.
        /// A launch where the onboarding was shown never shows it: the version is stored as seen.
        static func decide(
            appVersion: String,
            lastSeen: String?,
            onboardingShownAtLaunch: Bool,
            releases: [Release]
        ) -> Outcome {
            guard !appVersion.isEmpty, lastSeen != appVersion else {
                return Outcome(
                    release: nil,
                    marker: nil
                )
            }
            return Outcome(
                release: onboardingShownAtLaunch ? nil : releases.first { $0.version == appVersion },
                marker: appVersion
            )
        }
    }

    struct Store {
        var load: () -> String?
        var save: (String?) -> Void

        static let userSettings = Store(
            load: { UserSettings.whatsNewLastVersion },
            save: { UserSettings.whatsNewLastVersion = $0 }
        )
    }

    /// First line after `PreferencesReset` in `TribunerosApp.init()`: a fresh install has seen nothing to catch up on, so it stores the running version at once.
    static func recordLaunch(
        isFreshInstall: Bool = LaunchSplash.isFreshInstall,
        resets: Bool = resetsAtLaunch,
        appVersion: String = currentVersion,
        store: Store = .userSettings
    ) {
        if resets {
            store.save(nil)
            return
        }
        guard isFreshInstall, store.load() == nil, !appVersion.isEmpty else { return }
        store.save(appVersion)
    }

    static func isEnabled(
        override: Bool?,
        hasMockScenario: Bool
    ) -> Bool {
        override ?? !hasMockScenario
    }

    #if DEBUG
    /// Mocked launches (Maestro) skip it unless `WHATS_NEW` or the `whatsNew` launch argument turns it on.
    static var isEnabledAtLaunch: Bool {
        isEnabled(
            override: Onboarding.debugFlag(
                environment: ProcessInfo.processInfo.environment,
                key: "WHATS_NEW",
                launchValue: UserDefaults.standard.string(forKey: "whatsNew")
            ),
            hasMockScenario: HomeRaces.MockScenario.current != nil
        )
    }

    /// `RESET_WHATS_NEW` or the `resetWhatsNew` launch argument: forget the stored version, so this launch is the first on it.
    static var resetsAtLaunch: Bool {
        Onboarding.debugFlag(
            environment: ProcessInfo.processInfo.environment,
            key: "RESET_WHATS_NEW",
            launchValue: UserDefaults.standard.string(forKey: "resetWhatsNew")
        ) ?? false
    }
    #else
    static let isEnabledAtLaunch = true
    static let resetsAtLaunch = false
    #endif
}

extension WhatsNew {
    @MainActor
    final class Presenter: ObservableObject {
        @Published private(set) var showing: Release?
        private let store: Store
        private var hasStarted = false

        init(store: Store = .userSettings) {
            self.store = store
        }

        func start(
            isEnabled: Bool,
            onboardingShownAtLaunch: Bool,
            appVersion: String = WhatsNew.currentVersion,
            releases: [Release] = WhatsNew.releases()
        ) {
            guard !hasStarted else { return }
            hasStarted = true
            guard isEnabled else { return }
            let outcome = Schedule.decide(
                appVersion: appVersion,
                lastSeen: store.load(),
                onboardingShownAtLaunch: onboardingShownAtLaunch,
                releases: releases
            )
            if let marker = outcome.marker {
                store.save(marker)
            }
            showing = outcome.release
        }

        func dismiss() {
            showing = nil
        }
    }
}
