//
//  AppLocalization.swift
//  Tribuneros
//

import SwiftUI

/// Applies the language chosen in Settings (`UserSettings.appLanguage`) to `L10n` and
/// publishes it, so `LocalizedRoot` rebuilds the tabs in the new language without a restart.
@MainActor
final class AppLocalization: ObservableObject {
    static let shared = AppLocalization()

    /// The active bundled localization (`en`, `ca`).
    @Published private(set) var languageCode: String

    private init() {
        languageCode = L10n.languageCode
    }

    /// Called once, first thing at launch, before any display string is built.
    nonisolated static func applyAtLaunch(stored: String? = UserSettings.appLanguage) {
        L10n.setLanguage(AppLanguage.resolve(stored: stored))
    }

    /// `stored` is a Settings choice: `system` or a bundled localization code.
    func apply(stored: String) {
        let code = AppLanguage.resolve(stored: stored)
        L10n.setLanguage(code)
        if code != languageCode {
            languageCode = code
        }
    }
}

/// The tabs, rebuilt whenever the app language changes: view states hold strings that were
/// already localized, so a new language needs fresh view models. The selected tab survives
/// the rebuild; each tab's navigation stack goes back to its root.
struct LocalizedRoot: View {
    @ObservedObject private var localization = AppLocalization.shared
    @State private var selectedTab: Tab = .home

    var body: some View {
        TabBarView(selectedTab: $selectedTab)
            .id(localization.languageCode)
            .environment(\.locale, L10n.locale)
    }
}
