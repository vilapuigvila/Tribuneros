//
//  CXDockHint.swift
//  Tribuneros
//

import SwiftUI

extension CXRaces {

    /// Shown once, on a fresh install, over a dock that holds two cards.
    enum DockHint {
        static let maxShowings = 1
        static let visibleDuration: Duration = .seconds(7)

        static func shouldShow(count: Int) -> Bool {
            count < maxShowings
        }

        #if DEBUG
        /// Mocked launches (Maestro) never show it unless `DOCK_HINT` (or a `dockHint` launch argument) is on.
        static var isEnabledInDebug: Bool {
            let value = ProcessInfo.processInfo.environment["DOCK_HINT"]
                ?? UserDefaults.standard.string(forKey: "dockHint")
            let isOn = ["1", "on", "true", "yes"].contains(value?.lowercased() ?? "")
            return HomeRaces.MockScenario.current == nil || isOn
        }
        #endif
    }
}

struct CXDockHintCallout: View {
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.point.up.fill")
                .font(.system(size: 22))
                .foregroundColor(.tribuneru(.mudAccent))
                .offset(y: lifted ? -8 : 8)
                .accessibilityHidden(true)
            TribuneruText(
                content: L10n.tr("Drag the card up to switch"),
                style: .vaporLink,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 2
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color.tribuneru(.mudRaised),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.tribuneru(.mudAccent).opacity(0.5), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                lifted = true
            }
        }
    }
}
