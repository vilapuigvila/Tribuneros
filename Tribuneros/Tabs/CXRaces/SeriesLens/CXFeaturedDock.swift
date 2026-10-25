//
//  CXFeaturedDock.swift
//  Tribuneros
//

import SwiftUI

/// Height of one card in the CX Zone dock: the tag strip plus the body.
let cxDockCardHeight: CGFloat = 78

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
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.tribuneru(.mudFrost))
                    .frame(width: 44, height: 44)
                    .background(Color.tribuneru(.mudPageBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 13))
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
/// places twice by themselves, then only when the front one is dragged up: the cards follow the
/// finger and trade places once it is far enough.
struct CXFeaturedDock<Result: View, Race: View>: View {
    private let peekOffset: CGFloat = 30
    private let backScale: CGFloat = 0.93
    private let autoSwapDelay: Duration = .seconds(2.5)
    private let dragDistance: CGFloat = 70

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var raceInFront = false
    @State private var raceOnTop = false
    @State private var autoSwaps = 0
    @State private var tookOver = false
    @State private var showsHint = false
    /// 0 at rest, 1 when the front card has been dragged all the way back.
    @State private var dragProgress: CGFloat = 0

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
            // A zero-height anchor on the dock's top edge; the callout grows upward from it.
            Color.clear
                .frame(height: 0)
                .overlay(alignment: .bottom) {
                    if showsHint {
                        CXDockHintCallout(dismiss: dismissHint)
                            .padding(.bottom, 12)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                }
        }
        .task {
            await autoSwap()
            await presentHint()
        }
    }

    private var motion: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.2)
            : .timingCurve(0.45, 0.05, 0.2, 1, duration: 0.8)
    }

    private func layer<Content: View>(
        _ content: Content,
        isFront: Bool,
        onTop: Bool
    ) -> some View {
        // 1 = in front, 0 = behind; a drag moves both cards toward each other's place.
        let frontness = isFront ? 1 - dragProgress : dragProgress
        let isOnTop = onTop != (dragProgress > 0.5)
        return content
            .frame(height: cxDockCardHeight)
            .allowsHitTesting(isFront)
            .accessibilityHidden(!isFront)
            .accessibilityAction(
                named: raceInFront ? L10n.tr("Show the latest result") : L10n.tr("Show the next race"),
                takeOver
            )
            .simultaneousGesture(isFront ? dragGesture : nil)
            .scaleEffect(backScale + (1 - backScale) * frontness, anchor: .bottom)
            .offset(y: -peekOffset * (1 - frontness))
            .brightness(-0.1 * (1 - frontness))
            .shadow(
                color: .black.opacity(0.3 + 0.2 * frontness),
                radius: 6 + 8 * frontness,
                y: 3 + 5 * frontness
            )
            .zIndex(isOnTop ? 1 : 0)
            .animation(motion, value: raceInFront)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { drag in
                guard abs(drag.translation.height) > abs(drag.translation.width) else { return }
                dismissHint()
                dragProgress = min(max(-drag.translation.height / dragDistance, 0), 1)
            }
            .onEnded { drag in
                let isFlick = drag.predictedEndTranslation.height < -dragDistance * 2
                if dragProgress >= 0.6 || (isFlick && dragProgress > 0.1) {
                    takeOver()
                } else {
                    withAnimation(motion) { dragProgress = 0 }
                }
            }
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
        dismissHint()
        swap()
    }

    /// Once the cards stop moving by themselves, on a fresh install, tells the user how to switch.
    private func presentHint() async {
        guard !tookOver, !Task.isCancelled else { return }
        #if DEBUG
        guard CXRaces.DockHint.isEnabledInDebug else { return }
        #endif
        let count = UserSettings.dockHintShownCount ?? 0
        guard CXRaces.DockHint.shouldShow(count: count) else { return }
        UserSettings.dockHintShownCount = count + 1
        withAnimation(motion) { showsHint = true }
        try? await Task.sleep(for: CXRaces.DockHint.visibleDuration)
        dismissHint()
    }

    private func dismissHint() {
        guard showsHint else { return }
        withAnimation(motion) { showsHint = false }
    }

    /// The layers change order halfway, so the front card passes behind the other; a drag past
    /// halfway has already shown them in that order.
    private func swap() {
        let draggedPastHalf = dragProgress > 0.5
        raceInFront.toggle()
        dragProgress = 0
        let target = raceInFront
        if draggedPastHalf {
            raceOnTop = target
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 330))
            raceOnTop = target
        }
    }
}
