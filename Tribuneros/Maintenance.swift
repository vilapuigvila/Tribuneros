//
//  Maintenance.swift
//  Tribuneros
//

import SwiftUI

enum Maintenance {
    static func isActive(
        remoteValue: Bool,
        override: Bool?
    ) -> Bool {
        override ?? remoteValue
    }

    #if DEBUG
    /// `CT_MAINTENANCE` or the `ctMaintenance` launch argument: on/off, bypasses Remote Config.
    static var debugOverride: Bool? {
        debugOverride(
            environment: ProcessInfo.processInfo.environment,
            launchValue: UserDefaults.standard.string(forKey: "ctMaintenance")
        )
    }

    static func debugOverride(
        environment: [String: String],
        launchValue: String?
    ) -> Bool? {
        (environment["CT_MAINTENANCE"] ?? launchValue)
            .map { ["1", "on", "true", "yes"].contains($0.lowercased()) }
    }
    #else
    static let debugOverride: Bool? = nil
    #endif
}

@MainActor
final class MaintenanceMonitor: ObservableObject {
    @Published private(set) var isUnderMaintenance: Bool

    init() {
        isUnderMaintenance = Service.cachedUnderMaintenance()
    }

    func refresh() async {
        isUnderMaintenance = await Service.fetchUnderMaintenance()
    }
}

/// Owns the monitor so a flag change re-renders only this view; `content` is built once, because rebuilding `TabBarView` would recreate its view models.
struct MaintenanceHost<Content: View>: View {
    @StateObject private var monitor = MaintenanceMonitor()
    @Environment(\.scenePhase) private var scenePhase
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .maintenanceOverlay(monitor.isUnderMaintenance)
            .task(id: scenePhase) {
                if scenePhase == .active {
                    await monitor.refresh()
                }
            }
    }
}

struct MaintenanceAlertView: View {
    var body: some View {
        ZStack {
            Color.tribuneru(.vaporPageBackground)
                .opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(.tribuneru(.vaporAccent))
                    .accessibilityHidden(true)
                TribuneruText(
                    content: L10n.tr("Under maintenance"),
                    style: .vaporHeroTitle,
                    color: .tribuneru(.vaporTextPrimary)
                )
                TribuneruText(
                    content: L10n.tr("Cycling Tribune is being updated. Please try again in a few minutes."),
                    style: .vaporHeroSubtitle,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 4
                )
                .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(Color.tribuneru(.vaporCardSurface))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            UIAccessibility.post(
                notification: .screenChanged,
                argument: L10n.tr("Under maintenance. Cycling Tribune is being updated. Please try again in a few minutes.")
            )
        }
    }
}

extension View {
    func maintenanceOverlay(_ isActive: Bool) -> some View {
        self
            .blur(radius: isActive ? 12 : 0)
            .allowsHitTesting(!isActive)
            .accessibilityHidden(isActive)
            .overlay {
                if isActive {
                    MaintenanceAlertView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}
