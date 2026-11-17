//
//  UpdateAlertView.swift
//  Tribuneros
//

import SwiftUI

/// Owns the alert state so showing it re-renders only this view; `content` is built once, like `WhatsNewHost`.
/// Waits for the splash, the onboarding and the what's-new screen, so it never stacks on them.
struct UpdateAlertHost<Content: View>: View {
    @StateObject private var presenter = UpdateAlert.Presenter()
    @Environment(\.isLaunchSplashFinished) private var isLaunchSplashFinished
    @Environment(\.onboardingLaunch) private var onboarding
    @Environment(\.whatsNewLaunch) private var whatsNew
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var isReady: Bool {
        isLaunchSplashFinished
            && onboarding.hasStarted && !onboarding.isShowing
            && whatsNew.hasStarted && !whatsNew.isShowing
    }

    var body: some View {
        ZStack {
            content
                .accessibilityHidden(presenter.showing != nil)
            if let release = presenter.showing {
                UpdateAlertView(
                    release: release,
                    appVersion: WhatsNew.currentVersion,
                    update: { update(release) },
                    dismiss: presenter.dismiss
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(
            .easeOut(duration: 0.3),
            value: presenter.showing
        )
        .task(id: isReady) {
            guard isReady else { return }
            await presenter.start(
                isEnabled: UpdateAlert.isEnabledAtLaunch,
                resets: UpdateAlert.resetsAtLaunch,
                fetch: Service.getAppStoreRelease
            )
        }
    }

    private func update(_ release: UpdateAlert.Release) {
        UIApplication.shared.open(release.url)
        presenter.dismiss()
    }
}

/// The centered alert: a card over a dimmed app, "Update now" opens the App Store page, "Not now" closes it.
struct UpdateAlertView: View {
    let release: UpdateAlert.Release
    let appVersion: String
    let update: () -> Void
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.tribuneru(.vaporPageBackground)
                .opacity(0.74)
                .ignoresSafeArea()
            card
                .padding(.horizontal, 36)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("updatealert")
    }

    private var card: some View {
        VStack(spacing: 0) {
            Image(systemName: "arrow.up.circle")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(.tribuneru(.vaporAccent))
                .frame(width: 76, height: 76)
                .background(
                    Color.tribuneru(.vaporPanelRacing),
                    in: RoundedRectangle(cornerRadius: 24)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            Color.tribuneru(.vaporAccent).opacity(0.3),
                            lineWidth: 1
                        )
                )
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                TribuneruText(
                    content: L10n.tr("NEW VERSION"),
                    style: .vaporGroupLabel,
                    color: .tribuneru(.vaporAccent)
                )
                TribuneruText(
                    content: L10n.tr("Update available"),
                    style: .vaporSectionTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
                .multilineTextAlignment(.center)
                TribuneruText(
                    content: L10n.tr(
                        "Tribuneros %@ is on the App Store. Update to get the latest races, results and improvements.",
                        release.version
                    ),
                    style: .vaporBody,
                    color: .tribuneru(.vaporTextMuted),
                    lineLimit: 5
                )
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            TribuneruText(
                content: "\(appVersion) → \(release.version)",
                style: .vaporMonoMeta,
                color: .tribuneru(.vaporTagNeutralText)
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Color.tribuneru(.vaporTagNeutral),
                in: Capsule()
            )
            .padding(.top, 16)
            .accessibilityHidden(true)
            updateButton
                .padding(.top, 22)
            laterButton
                .padding(.top, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: 318)
        .background(
            Color.tribuneru(.vaporCardSurface),
            in: RoundedRectangle(cornerRadius: 28)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    Color.tribuneru(.vaporTagNeutral),
                    lineWidth: 1
                )
        )
    }

    private var updateButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            update()
        } label: {
            TribuneruText(
                content: L10n.tr("Update now"),
                style: .vaporBannerTitle,
                color: .tribuneru(.vaporPageBackground)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Color.tribuneru(.vaporAccent),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("Update now"))
        .accessibilityIdentifier("updatealert.update")
    }

    private var laterButton: some View {
        Button {
            dismiss()
        } label: {
            TribuneruText(
                content: L10n.tr("Not now"),
                style: .vaporRowTitle,
                color: .tribuneru(.vaporTextMuted)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("Not now"))
        .accessibilityIdentifier("updatealert.later")
    }
}

#if DEBUG
#Preview {
    UpdateAlertView(
        release: UpdateAlert.Release(
            version: "1.4",
            url: UpdateAlert.debugURL
        ),
        appVersion: "1.3",
        update: {},
        dismiss: {}
    )
    .background(Color.tribuneru(.vaporPageBackground))
}
#endif
