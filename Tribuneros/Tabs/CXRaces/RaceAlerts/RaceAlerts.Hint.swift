//
//  RaceAlerts.Hint.swift
//  Tribuneros
//

import SwiftUI

extension RaceAlerts {

    /// Where the "Tap the bell" hint stands; decided at launch and stored under its own key.
    enum HintState: String, Codable, Equatable {
        /// A fresh install: due from the next cold launch.
        case waiting
        case due
        case shown
    }

    /// Shown once, ever, on CX Zone near the bell: from the second cold launch of a fresh install, at once on an update.
    enum Hint {
        static let visibleDuration: Duration = .seconds(7)

        struct Store {
            var load: () -> HintState?
            var save: (HintState) -> Void

            static let userSettings = Store(
                load: { UserSettings.raceAlertsHint },
                save: { UserSettings.raceAlertsHint = $0 }
            )
        }

        /// True when the hint was due at launch: the dock hint then waits for a later launch.
        private(set) static var isDueThisLaunch = false

        static func state(
            atLaunch stored: HintState?,
            isFreshInstall: Bool
        ) -> HintState {
            switch stored {
            case nil: isFreshInstall ? .waiting : .due
            case .waiting: .due
            case .due: .due
            case .shown: .shown
            }
        }

        static func shouldShow(
            state: HintState?,
            isEnabled: Bool
        ) -> Bool {
            state == .due && isEnabled
        }

        /// Runs once per cold launch, before the onboarding records anything.
        @discardableResult
        static func recordLaunch(
            store: Store = .userSettings,
            isFreshInstall: Bool = LaunchSplash.isFreshInstall,
            isEnabled: Bool = isEnabledAtLaunch
        ) -> HintState {
            let state = state(
                atLaunch: store.load(),
                isFreshInstall: isFreshInstall
            )
            if state != store.load() {
                store.save(state)
            }
            isDueThisLaunch = shouldShow(
                state: state,
                isEnabled: isEnabled
            )
            return state
        }

        /// Counts it as shown the moment it appears; false when it isn't due.
        static func present(
            store: Store = .userSettings,
            isEnabled: Bool = isEnabledAtLaunch
        ) -> Bool {
            guard shouldShow(
                state: store.load(),
                isEnabled: isEnabled
            ) else { return false }
            store.save(.shown)
            return true
        }

        static func isEnabled(
            isMockedLaunch: Bool,
            isFlagOn: Bool
        ) -> Bool {
            !isMockedLaunch || isFlagOn
        }

        #if DEBUG
        /// Mocked launches (Maestro) hide it unless `ALERTS_HINT` (or an `alertsHint` launch argument) is on.
        static var isEnabledAtLaunch: Bool {
            isEnabled(
                isMockedLaunch: HomeRaces.MockScenario.current != nil,
                isFlagOn: Onboarding.debugFlag(
                    environment: ProcessInfo.processInfo.environment,
                    key: "ALERTS_HINT",
                    launchValue: UserDefaults.standard.string(forKey: "alertsHint")
                ) ?? false
            )
        }
        #else
        static let isEnabledAtLaunch = true
        #endif
    }
}

struct RaceAlertsHintCallout: View {
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 20))
                .foregroundColor(.tribuneru(.mudAccent))
                .offset(y: lifted ? -5 : 5)
                .accessibilityHidden(true)
            TribuneruText(
                content: L10n.tr("New: race alerts. Tap the bell to follow a series."),
                style: .vaporLink,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 3
            )
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 260)
        .background(
            Color.tribuneru(.mudRaised),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.tribuneru(.mudAccent).opacity(0.5), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(0.35),
            radius: 10,
            y: 4
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("cx.alerts.hint")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                lifted = true
            }
        }
    }
}
