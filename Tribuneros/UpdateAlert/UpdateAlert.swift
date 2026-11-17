//
//  UpdateAlert.swift
//  Tribuneros
//

import Foundation

/// The "new version on the App Store" alert: shown at most once per App Store version, whether the user updates or not.
enum UpdateAlert {
    typealias Release = DTO.AppStoreRelease

    /// The release to alert about, nil when the App Store has nothing newer than the running version or that version was already alerted.
    static func decide(
        appVersion: String,
        lastAlerted: String?,
        available: Release?
    ) -> Release? {
        guard let available,
              !appVersion.isEmpty,
              WhatsNew.compare(
                  available.version,
                  appVersion
              ) == .orderedDescending,
              lastAlerted != available.version
        else {
            return nil
        }
        return available
    }

    struct Store {
        var load: () -> String?
        var save: (String?) -> Void

        static let userSettings = Store(
            load: { UserSettings.updateAlertLastVersion },
            save: { UserSettings.updateAlertLastVersion = $0 }
        )
    }

    static func isEnabled(
        override: Bool?,
        hasMockScenario: Bool
    ) -> Bool {
        override ?? !hasMockScenario
    }

    #if DEBUG
    static let debugURL = URL(string: "https://apps.apple.com/")!

    /// Mocked launches (Maestro) skip it unless `UPDATE_ALERT` or the `updateAlert` launch argument turns it on.
    static var isEnabledAtLaunch: Bool {
        isEnabled(
            override: Onboarding.debugFlag(
                environment: ProcessInfo.processInfo.environment,
                key: "UPDATE_ALERT",
                launchValue: UserDefaults.standard.string(forKey: "updateAlert")
            ),
            hasMockScenario: HomeRaces.MockScenario.current != nil
        )
    }

    /// `RESET_UPDATE_ALERT` or the `resetUpdateAlert` launch argument: forget the alerted version.
    static var resetsAtLaunch: Bool {
        Onboarding.debugFlag(
            environment: ProcessInfo.processInfo.environment,
            key: "RESET_UPDATE_ALERT",
            launchValue: UserDefaults.standard.string(forKey: "resetUpdateAlert")
        ) ?? false
    }

    /// The App Store version to pretend, with no request: `UPDATE_ALERT_VERSION` (or `updateAlertVersion`), else "9.9" on a mocked launch.
    static var debugVersion: String? {
        debugVersion(
            environment: ProcessInfo.processInfo.environment,
            launchValue: UserDefaults.standard.string(forKey: "updateAlertVersion"),
            hasMockScenario: HomeRaces.MockScenario.current != nil
        )
    }

    static func debugVersion(
        environment: [String: String],
        launchValue: String?,
        hasMockScenario: Bool
    ) -> String? {
        if let version = environment["UPDATE_ALERT_VERSION"] ?? launchValue, !version.isEmpty {
            return version
        }
        return hasMockScenario ? "9.9" : nil
    }
    #else
    static let isEnabledAtLaunch = true
    static let resetsAtLaunch = false
    #endif
}

extension UpdateAlert {
    @MainActor
    final class Presenter: ObservableObject {
        @Published private(set) var showing: Release?
        private let store: Store
        private var hasStarted = false

        init(store: Store = .userSettings) {
            self.store = store
        }

        /// Once per launch: looks the App Store up, and when it lists a newer version not alerted yet, stores that version and shows the alert.
        func start(
            isEnabled: Bool,
            resets: Bool,
            appVersion: String = WhatsNew.currentVersion,
            fetch: () async -> Release?
        ) async {
            guard !hasStarted else { return }
            hasStarted = true
            guard isEnabled else { return }
            if resets {
                store.save(nil)
            }
            let available = await fetch()
            guard !Task.isCancelled else {
                hasStarted = false
                return
            }
            guard let release = UpdateAlert.decide(
                appVersion: appVersion,
                lastAlerted: store.load(),
                available: available
            ) else {
                return
            }
            store.save(release.version)
            showing = release
        }

        func dismiss() {
            showing = nil
        }
    }
}
