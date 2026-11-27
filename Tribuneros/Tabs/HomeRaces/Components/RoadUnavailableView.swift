//
//  RoadUnavailableView.swift
//  Tribuneros
//

import SwiftUI

/// Today Races with no data at all: the dawn painting, when data last loaded and up to 3 retries.
struct RoadUnavailableView: View {
    @Environment(\.tabBarHeight) private var tabBarHeight

    let state: HomeRaces.Unavailable
    let retry: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    HomeScreenHeader(date: Date())
                        .padding(.top, 16)
                    Spacer(minLength: proxy.size.width * 0.55)
                    message
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, tabBarHeight + 24)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(alignment: .top) {
                RoadClosedDawnArt()
                    .frame(height: proxy.size.width * 560 / 390)
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: .tribuneru(.vaporPageBackground).opacity(0), location: 0.7),
                                .init(color: .tribuneru(.vaporPageBackground), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .offset(y: -70)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .accessibilityIdentifier("home.unavailable")
    }

    private var message: some View {
        VStack(spacing: 10) {
            TribuneruText(
                content: L10n.tr("ROAD CLOSED · NO DATA"),
                style: .vaporTagSmall,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Color.tribuneru(.vaporPageBackground).opacity(0.55),
                in: Capsule()
            )
            .accessibilityIdentifier("home.unavailable.tag")
            TribuneruText(
                content: L10n.tr("No info available"),
                style: .vaporSectionTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            .multilineTextAlignment(.center)
            .padding(.top, 6)
            .accessibilityIdentifier("home.unavailable.title")
            TribuneruText(
                content: L10n.tr("The peloton hasn’t shown up on our side yet. We’ll keep looking."),
                style: .vaporBody,
                color: .tribuneru(.vaporTextMuted),
                lineLimit: 3
            )
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
            lastLoadedRow
                .padding(.top, 8)
            retryButton
                .padding(.top, 6)
            hint
        }
    }

    private var lastLoadedRow: some View {
        TimelineView(.everyMinute) { context in
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                if let lastLoaded = state.lastLoaded {
                    TribuneruText(
                        content: L10n.tr("Last updated"),
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    Spacer(minLength: 8)
                    TribuneruText(
                        content: L10n.relativeFormatter().localizedString(
                            for: min(lastLoaded, context.date),
                            relativeTo: context.date
                        ),
                        style: .vaporMonoMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                } else {
                    TribuneruText(
                        content: L10n.tr("Never loaded on this device"),
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Color.tribuneru(.vaporCardSurface),
                in: RoundedRectangle(
                    cornerRadius: 16,
                    style: .continuous
                )
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.unavailable.lastLoaded")
    }

    private var retryButton: some View {
        Button(action: retry) {
            TribuneruText(
                content: state.isLocked ? L10n.tr("Try again later") : L10n.tr("Try again"),
                style: .vaporRowTitle,
                color: .tribuneru(state.isLocked ? .vaporTextMuted : .vaporPageBackground),
                lineLimit: 1
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                Color.tribuneru(state.isLocked ? .vaporTagNeutral : .vaporAccent),
                in: Capsule()
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(state.isLocked)
        .accessibilityIdentifier("home.unavailable.retry")
    }

    private var hint: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<HomeRaces.RetryBudget.maxTries, id: \.self) { index in
                    Circle()
                        .fill(Color.tribuneru(index < state.triesLeft ? .vaporAccent : .vaporTagNeutral))
                        .frame(
                            width: 8,
                            height: 8
                        )
                }
            }
            .accessibilityHidden(true)
            TribuneruText(
                content: state.isLocked
                    ? L10n.tr("No tries left · reopen the app")
                    : L10n.tr("%lld tries left", state.triesLeft),
                style: .vaporMonoMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            .padding(.leading, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.unavailable.hint")
    }
}

#if DEBUG
#Preview("Tries left") {
    RoadUnavailableView(
        state: HomeRaces.Unavailable(
            triesLeft: 2,
            lastLoaded: Date().addingTimeInterval(-3 * 3600)
        )
    ) {}
}

#Preview("Locked, never loaded") {
    RoadUnavailableView(
        state: HomeRaces.Unavailable(
            triesLeft: 0,
            lastLoaded: nil
        )
    ) {}
}
#endif
