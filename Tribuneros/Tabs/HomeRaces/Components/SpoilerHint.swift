//
//  SpoilerHint.swift
//  Tribuneros
//

import Lottie
import SwiftUI

extension HomeRaces {
    enum SpoilerHint {
        static var text: String {
            L10n.tr("Press and hold a result to show or hide spoilers")
        }
        static let repeatInterval: TimeInterval = 48 * 3600
        static let maxShowings = 2

        static func shouldShow(
            now: Date,
            firstShown: Date?,
            count: Int
        ) -> Bool {
            guard count < maxShowings else { return false }
            guard count > 0, let firstShown else { return true }
            return now.timeIntervalSince(firstShown) >= repeatInterval
        }
    }
}

struct SpoilerHintAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>?

    static func reduce(
        value: inout Anchor<CGRect>?,
        nextValue: () -> Anchor<CGRect>?
    ) {
        value = value ?? nextValue()
    }
}

extension View {
    @ViewBuilder
    func spoilerHintAnchor(_ isAnchor: Bool) -> some View {
        if isAnchor {
            anchorPreference(
                key: SpoilerHintAnchorKey.self,
                value: .bounds
            ) { $0 }
        } else {
            self
        }
    }
}

private struct HintPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct SpoilerHintCallout: View {
    var pointsUp = true
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animation: some View {
        LottieView(animation: .named("spoiler_long_press"))
            .playbackMode(
                reduceMotion
                    ? .paused(at: .progress(0.65))
                    : .playing(.fromProgress(
                        0,
                        toProgress: 1,
                        loopMode: .loop
                    ))
            )
            .frame(
                width: 200,
                height: 120
            )
            .accessibilityHidden(true)
    }

    private var pointer: some View {
        HintPointer()
            .fill(Color.tribuneru(.vaporAccent))
            .frame(
                width: 16,
                height: 8
            )
    }

    var body: some View {
        VStack(spacing: 0) {
            if pointsUp {
                pointer
            }
            VStack(spacing: 6) {
                animation
                TribuneruText(
                    content: HomeRaces.SpoilerHint.text,
                    style: .vaporLink,
                    color: .tribuneru(.vaporPageBackground),
                    lineLimit: 2
                )
                .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Color.tribuneru(.vaporAccent),
                in: RoundedRectangle(cornerRadius: 12)
            )
            if !pointsUp {
                pointer
                    .rotationEffect(.degrees(180))
            }
        }
        .frame(maxWidth: 260)
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HomeRaces.SpoilerHint.text)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.spoilerHint")
    }
}
