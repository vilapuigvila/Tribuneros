//
//  CXFeaturedDock.swift
//  Tribuneros
//

import SwiftUI

/// Height of one card in the CX Zone dock: the tag strip plus the body.
let cxDockCardHeight: CGFloat = 98

/// The tag strip on top of a dock card; the card behind shows only this strip.
struct CXDockStrip: View {
    let tag: String
    let trailing: String?

    var body: some View {
        HStack(spacing: 8) {
            TribuneruText(
                content: tag,
                style: .vaporTagSmall,
                color: .tribuneru(.mudPageBackground),
                lineLimit: 1
            )
            Spacer(minLength: 0)
            if let trailing {
                TribuneruText(
                    content: trailing,
                    style: .vaporTagSmall,
                    color: .tribuneru(.mudPageBackground),
                    lineLimit: 1
                )
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 26)
    }
}

/// The soonest race, in the dock's second colour.
struct CXNextRaceCard: View {
    let upcoming: CXRaces.SeriesLens.Upcoming
    let open: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            CXDockStrip(
                tag: L10n.tr("NEXT TO START"),
                trailing: dayText.uppercased(with: L10n.locale)
            )
            HStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.tribuneru(.mudFrost))
                    .frame(width: 52, height: 52)
                    .background(Color.tribuneru(.mudPageBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    TribuneruText(
                        content: upcoming.event.race,
                        style: .vaporResultTitle,
                        color: .tribuneru(.mudPageBackground),
                        lineLimit: 1
                    )
                    TribuneruText(
                        content: subtitle,
                        style: .vaporRowMeta,
                        color: .tribuneru(.mudPageBackground),
                        lineLimit: 1
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.tribuneru(.mudPageBackground))
                    .accessibilityHidden(true)
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .frame(maxHeight: .infinity)
        }
        .frame(height: cxDockCardHeight)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.tribuneru(.mudFrost))
        )
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            open()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var dayText: String {
        switch upcoming.days {
        case 0: L10n.tr("Today")
        case 1: L10n.tr("Tomorrow")
        case let days: L10n.tr("In %lld days", days)
        }
    }

    private var subtitle: String {
        [upcoming.event.raceCountry, upcoming.event.raceClass]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// Two cards stacked: the one in front is whole, the other peeks above it. The cards trade
/// places twice by themselves, then only when the peeking one is tapped.
struct CXFeaturedDock<Result: View, Race: View>: View {
    private let peekOffset: CGFloat = 32
    private let peekHeight: CGFloat = 26
    private let backScale: CGFloat = 0.93
    private let autoSwapDelay: Duration = .seconds(4)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var raceInFront = false
    @State private var raceOnTop = false
    @State private var autoSwaps = 0
    @State private var tookOver = false

    let result: Result
    let race: Race

    init(
        @ViewBuilder result: () -> Result,
        @ViewBuilder race: () -> Race
    ) {
        self.result = result()
        self.race = race()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            layer(
                result,
                isFront: !raceInFront,
                onTop: !raceOnTop
            )
            layer(
                race,
                isFront: raceInFront,
                onTop: raceOnTop
            )
        }
        .frame(
            height: cxDockCardHeight * backScale + peekOffset,
            alignment: .bottom
        )
        .overlay(alignment: .top) {
            Button(action: takeOver) {
                Color.clear
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(height: peekHeight)
            .padding(.horizontal, 12)
            .accessibilityLabel(
                raceInFront ? L10n.tr("Show the latest result") : L10n.tr("Show the next race")
            )
        }
        .task { await autoSwap() }
    }

    private var motion: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .timingCurve(0.45, 0.05, 0.2, 1, duration: 1.1)
    }

    private func layer<Content: View>(
        _ content: Content,
        isFront: Bool,
        onTop: Bool
    ) -> some View {
        content
            .frame(height: cxDockCardHeight)
            .allowsHitTesting(isFront)
            .accessibilityHidden(!isFront)
            .scaleEffect(isFront ? 1 : backScale, anchor: .bottom)
            .offset(y: isFront ? 0 : -peekOffset)
            .brightness(isFront ? 0 : -0.1)
            .shadow(
                color: .black.opacity(isFront ? 0.5 : 0.3),
                radius: isFront ? 14 : 6,
                y: isFront ? 8 : 3
            )
            .zIndex(onTop ? 1 : 0)
            .animation(motion, value: raceInFront)
    }

    private var autoSwapCount: Int {
        #if DEBUG
        // Mocked launches (Maestro) keep the cards still unless DOCK_AUTOSWAP (or a dockAutoSwap launch argument) is on.
        let value = ProcessInfo.processInfo.environment["DOCK_AUTOSWAP"]
            ?? UserDefaults.standard.string(forKey: "dockAutoSwap")
        let isOn = ["1", "on", "true", "yes"].contains(value?.lowercased() ?? "")
        if HomeRaces.MockScenario.current != nil, !isOn { return 0 }
        #endif
        return 2
    }

    private func autoSwap() async {
        while autoSwaps < autoSwapCount, !tookOver {
            try? await Task.sleep(for: autoSwapDelay)
            guard !Task.isCancelled, !tookOver else { return }
            autoSwaps += 1
            swap()
        }
    }

    private func takeOver() {
        tookOver = true
        swap()
    }

    /// The layers change order halfway, so the front card passes behind the other.
    private func swap() {
        raceInFront.toggle()
        let target = raceInFront
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
            raceOnTop = target
        }
    }
}
