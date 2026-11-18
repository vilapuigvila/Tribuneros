//
//  WhatsNewView.swift
//  Tribuneros
//

import SwiftUI

private struct WhatsNewLaunchKey: EnvironmentKey {
    static let defaultValue = WhatsNew.LaunchState(
        hasStarted: true,
        isShowing: false
    )
}

extension EnvironmentValues {
    var whatsNewLaunch: WhatsNew.LaunchState {
        get { self[WhatsNewLaunchKey.self] }
        set { self[WhatsNewLaunchKey.self] = newValue }
    }
}

/// Owns the what's-new state so showing it re-renders only this view; `content` is built once, like `OnboardingHost`.
struct WhatsNewHost<Content: View>: View {
    @StateObject private var presenter = WhatsNew.Presenter()
    @Environment(\.isLaunchSplashFinished) private var isLaunchSplashFinished
    @Environment(\.onboardingLaunch) private var onboarding
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private var isReady: Bool {
        isLaunchSplashFinished && onboarding.hasStarted && !onboarding.isShowing
    }

    var body: some View {
        ZStack {
            content
                .environment(
                    \.whatsNewLaunch,
                    WhatsNew.LaunchState(
                        hasStarted: presenter.hasStarted,
                        isShowing: presenter.showing != nil
                    )
                )
                .accessibilityHidden(presenter.showing != nil)
            if let release = presenter.showing {
                WhatsNewView(
                    release: release,
                    dismiss: dismiss
                )
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(1)
            }
        }
        .task(id: isReady) {
            guard isReady else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                presenter.start(
                    isEnabled: WhatsNew.isEnabledAtLaunch,
                    onboardingShownAtLaunch: onboarding.shownAtLaunch
                )
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.35)) {
            presenter.dismiss()
        }
    }
}

/// The one screen shown on the first launch of a new version.
struct WhatsNewView: View {
    let release: WhatsNew.Release
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            background
            VStack(
                alignment: .leading,
                spacing: 0
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {
                    TribuneruText(
                        content: L10n.tr("WHAT'S NEW"),
                        style: .vaporGroupLabel,
                        color: .tribuneru(.vaporAccent)
                    )
                    TribuneruText(
                        content: L10n.tr("Fresh off the road"),
                        style: .vaporSectionTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )
                    TribuneruText(
                        content: L10n.tr("Here is what we added since your last ride."),
                        style: .vaporRowTitle,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 3
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 56)
                ScrollView {
                    WhatsNew.ItemList(items: release.items)
                        .padding(.vertical, 28)
                }
                .scrollBounceBehavior(.basedOnSize)
                primaryButton
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("whatsnew")
    }

    private var background: some View {
        ZStack {
            Color.tribuneru(.vaporPageBackground)
            RadialGradient(
                colors: [
                    Color.tribuneru(.vaporAccent).opacity(0.14),
                    Color.tribuneru(.vaporPageBackground).opacity(0)
                ],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var primaryButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } label: {
            TribuneruText(
                content: L10n.tr("Let's ride"),
                style: .vaporBannerTitle,
                color: .tribuneru(.vaporPageBackground)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Color.tribuneru(.vaporAccent),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("Let's ride"))
        .accessibilityIdentifier("whatsnew.done")
    }
}

extension WhatsNew {
    struct ItemList: View {
        let items: [Item]

        var body: some View {
            VStack(spacing: 12) {
                ForEach(items) { item in
                    ItemRow(item: item)
                }
            }
        }
    }

    struct ItemRow: View {
        let item: Item

        private var tint: Color {
            switch item.tint {
            case .amber: .tribuneru(.mudAccent)
            case .blue: .tribuneru(.vaporGroupBadge)
            case .green: .tribuneru(.vaporLive)
            }
        }

        @ViewBuilder
        private var icon: some View {
            if let assetImage = item.assetImage {
                Image(assetImage)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else {
                Image(systemName: item.systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(tint)
            }
        }

        var body: some View {
            HStack(
                alignment: .top,
                spacing: 16
            ) {
                icon
                    .frame(width: 44, height: 44)
                    .background(
                        tint.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .accessibilityHidden(true)
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    TribuneruText(
                        content: item.title,
                        style: .vaporBannerTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )
                    TribuneruText(
                        content: item.body,
                        style: .vaporBody,
                        color: .tribuneru(.vaporTextMuted),
                        lineLimit: 5
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color.tribuneru(.vaporCardSurface),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("whatsnew.item.\(item.id)")
        }
    }

    /// Settings → What's new: every release up to the running version, newest first.
    struct HistoryView: View {
        let releases = WhatsNew.history()

        var body: some View {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: 28
                ) {
                    ForEach(releases) { release in
                        VStack(
                            alignment: .leading,
                            spacing: 12
                        ) {
                            TribuneruText(
                                content: "v\(release.version)",
                                style: .vaporGroupLabel,
                                color: .tribuneru(.vaporAccent)
                            )
                            .accessibilityAddTraits(.isHeader)
                            ItemList(items: release.items)
                        }
                        .accessibilityIdentifier("whatsnew.release.\(release.version)")
                    }
                }
                .padding(16)
            }
            .background(Color.tribuneru(.vaporPageBackground))
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(L10n.tr("What's new"))
        }
    }
}
