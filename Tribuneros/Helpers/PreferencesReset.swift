//
//  PreferencesReset.swift
//  Tribuneros
//

import Foundation

/// Clears the app's own preferences once per `UserSettings.currentPreferencesResetVersion`.
enum PreferencesReset {
    struct Store {
        var loadVersion: () -> Int?
        var saveVersion: (Int) -> Void
        var forgetVersion: () -> Void
        var clearKey: (String) -> Void

        static func defaults(_ defaults: UserDefaults) -> Store {
            Store(
                loadVersion: { defaults.decode(Int.self, forKey: UserPreferencesKey.preferencesResetVersion.rawValue) },
                saveVersion: { version in
                    defaults.set(
                        try? JSONEncoder().encode(version),
                        forKey: UserPreferencesKey.preferencesResetVersion.rawValue
                    )
                },
                forgetVersion: { defaults.removeObject(forKey: UserPreferencesKey.preferencesResetVersion.rawValue) },
                clearKey: { defaults.removeObject(forKey: $0) }
            )
        }

        static let standard = defaults(.standard)
    }

    /// Returns true when it cleared the preferences.
    @discardableResult
    static func run(
        store: Store,
        currentVersion: Int = UserSettings.currentPreferencesResetVersion,
        simulatesUpdate: Bool = false
    ) -> Bool {
        if simulatesUpdate {
            store.forgetVersion()
        }
        guard (store.loadVersion() ?? 0) < currentVersion else { return false }
        for key in UserPreferencesKey.allCases where key != .preferencesResetVersion {
            store.clearKey(key.rawValue)
        }
        store.saveVersion(currentVersion)
        return true
    }

    static func runAtLaunch() {
        run(
            store: .standard,
            simulatesUpdate: simulatesUpdateAtLaunch
        )
    }

    #if DEBUG
    /// `SIMULATE_APP_UPDATE` or the `simulateAppUpdate` launch argument: forget the marker, so this launch is the first after an update.
    static var simulatesUpdateAtLaunch: Bool {
        Onboarding.debugFlag(
            environment: ProcessInfo.processInfo.environment,
            key: "SIMULATE_APP_UPDATE",
            launchValue: UserDefaults.standard.string(forKey: "simulateAppUpdate")
        ) ?? false
    }
    #else
    static let simulatesUpdateAtLaunch = false
    #endif
}
