//
//  OnboardingView.swift
//  Tribuneros
//

import Lottie
import SwiftUI

/// Owns the onboarding state so showing it re-renders only this view; `content` is built once, like `MaintenanceHost`.
struct OnboardingHost<Content: View>: View {
    @StateObject private var presenter = Onboarding.Presenter()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .accessibilityHidden(presenter.showing != nil)
            if let showing = presenter.showing {
                OnboardingView(
                    showing: showing,
                    dismiss: dismiss
                )
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: Onboarding.splashDelay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                presenter.start(
                    isEnabled: Onboarding.isEnabledAtLaunch,
                    seedsSecondShowing: Onboarding.seedsSecondShowing,
                    resets: Onboarding.resetsAtLaunch
                )
            }
        }
    }

    private func dismiss(_ dismissal: Onboarding.Dismissal) {
        withAnimation(.easeInOut(duration: 0.35)) {
            presenter.dismiss(dismissal)
        }
    }
}

struct OnboardingView: View {
    let showing: Int
    let dismiss: (Onboarding.Dismissal) -> Void

    @State private var selection = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: [Onboarding.Page] {
        Onboarding.pages(showing: showing)
    }

    private var isLastPage: Bool {
        selection == pages.count - 1
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                TabView(selection: $selection) {
                    ForEach(pages) { page in
                        OnboardingPageView(
                            page: page,
                            pageCount: pages.count,
                            isCurrent: page.id == selection,
                            reduceMotion: reduceMotion
                        )
                        .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                OnboardingPageDots(
                    count: pages.count,
                    current: selection
                )
                .padding(.vertical, 20)
                primaryButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .onChange(of: selection) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("onboarding")
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

    private var topBar: some View {
        HStack {
            Image(systemName: "bicycle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporAccent))
                .accessibilityHidden(true)
            TribuneruText(
                content: "CYCLING TRIBUNE",
                style: .vaporGroupLabel,
                color: .tribuneru(.vaporTextSecondary)
            )
            .accessibilityHidden(true)
            Spacer()
            if !isLastPage {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss(.skip)
                } label: {
                    TribuneruText(
                        content: "Skip",
                        style: .vaporLink,
                        color: .tribuneru(.vaporTextSecondary)
                    )
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Skip the introduction")
                .accessibilityIdentifier("onboarding.skip")
                .transition(.opacity)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .animation(
            .easeInOut(duration: 0.2),
            value: isLastPage
        )
    }

    private var primaryButton: some View {
        Button {
            if isLastPage {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss(.finish)
            } else {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    selection += 1
                }
            }
        } label: {
            HStack(spacing: 8) {
                TribuneruText(
                    content: isLastPage ? "Let's ride" : "Next",
                    style: .vaporBannerTitle,
                    color: .tribuneru(.vaporPageBackground)
                )
                Image(systemName: isLastPage ? "bicycle" : "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.tribuneru(.vaporPageBackground))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Color.tribuneru(.vaporAccent),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLastPage ? "Let's ride" : "Next")
        .accessibilityIdentifier(isLastPage ? "onboarding.done" : "onboarding.next")
    }
}

private struct OnboardingPageView: View {
    let page: Onboarding.Page
    let pageCount: Int
    let isCurrent: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)
            LottieView(animation: .named(page.animation))
                .playbackMode(
                    reduceMotion || !isCurrent
                        ? .paused(at: .progress(page.stillProgress))
                        : .playing(.fromProgress(
                            0,
                            toProgress: 1,
                            loopMode: .loop
                        ))
                )
                .resizable()
                .aspectRatio(
                    4 / 3,
                    contentMode: .fit
                )
                .frame(maxWidth: 420)
                .mask { edgeFade }
                .accessibilityHidden(true)
            Spacer(minLength: 16)
            VStack(spacing: 12) {
                TribuneruText(
                    content: String(format: "%02ld / %02ld", page.id + 1, pageCount),
                    style: .vaporGroupLabel,
                    color: .tribuneru(.vaporAccent)
                )
                TribuneruText(
                    content: page.title,
                    style: .vaporSectionTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
                .minimumScaleFactor(0.8)
                TribuneruText(
                    content: page.body,
                    style: .vaporRowTitle,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 3
                )
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(page.accessibilityLabel)
        .accessibilityIdentifier("onboarding.page.\(page.id)")
    }

    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .tribuneru(.black).opacity(0), location: 0),
                .init(color: .tribuneru(.black), location: 0.08),
                .init(color: .tribuneru(.black), location: 0.92),
                .init(color: .tribuneru(.black).opacity(0), location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .tribuneru(.black), location: 0.82),
                    .init(color: .tribuneru(.black).opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct OnboardingPageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(
                        index == current
                            ? Color.tribuneru(.vaporAccent)
                            : Color.tribuneru(.vaporTagNeutral)
                    )
                    .frame(
                        width: index == current ? 22 : 8,
                        height: 8
                    )
            }
        }
        .animation(
            .easeInOut(duration: 0.25),
            value: current
        )
        .accessibilityHidden(true)
    }
}
