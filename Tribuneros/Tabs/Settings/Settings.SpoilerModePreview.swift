//
//  Settings.SpoilerModePreview.swift
//  Tribuneros
//

import SwiftUI

extension Settings {

    /// A mini result card that acts out the Hide results mode: ON is covered until a press and hold, OFF is open.
    struct SpoilerModePreview: View {
        enum Layout {
            static let card = CGSize(width: 82, height: 100)
            static let photoHeight: CGFloat = 54
            static let touch = CGPoint(x: 41, y: 27)
            static let ring: CGFloat = 34
        }

        enum Winner: CaseIterable {
            case man
            case woman
            case person
        }

        /// Shared with the tile's switch, so the switch and the preview move as one.
        static let switchDuration: TimeInterval = 0.35
        static let switchAnimation: Animation = .easeInOut(duration: switchDuration)
        static let cycle: TimeInterval = 4.8
        static let loops = Winner.allCases.count
        static let stillTime: TimeInterval = 1.8

        let isOn: Bool

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var start = Date.distantPast
        @State private var from = FrameState.covered
        @State private var isPlaying = false

        var body: some View {
            Group {
                if reduceMotion {
                    frame(isOn ? Self.loop(at: Self.stillTime) : .shown(.man))
                } else if isPlaying {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        frame(state(at: context.date))
                    }
                } else {
                    frame(state(at: Date()))
                }
            }
            .frame(
                width: Layout.card.width,
                height: Layout.card.height,
                alignment: .topLeading
            )
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(true)
            .onAppear {
                restart(from: isOn ? .covered : .shown(.man))
            }
            .onChange(of: isOn) { wasOn, _ in
                restart(
                    from: Self.state(
                        isOn: wasOn,
                        elapsed: Date().timeIntervalSince(start),
                        from: from
                    )
                )
            }
            .task(id: start) {
                guard start != .distantPast else { return }
                let duration = isOn ? Double(Self.loops) * Self.cycle : Self.switchDuration
                guard (try? await Task.sleep(for: .seconds(duration))) != nil else { return }
                isPlaying = false
            }
        }

        private func restart(from state: FrameState) {
            from = state
            start = Date()
            isPlaying = true
        }

        private func state(at date: Date) -> FrameState {
            Self.state(
                isOn: isOn,
                elapsed: max(0, date.timeIntervalSince(start)),
                from: from
            )
        }

        private func frame(_ state: FrameState) -> some View {
            ZStack(alignment: .topLeading) {
                MiniResultCard(
                    cover: state.cover,
                    winner: state.winner
                )
                .scaleEffect(1 - 0.05 * state.press)
                touchMarker(state)
                    .offset(
                        x: Layout.touch.x - Layout.ring / 2,
                        y: Layout.touch.y - Layout.ring / 2
                    )
                hand(state)
                    .offset(
                        x: Layout.touch.x - 6 + 22 * state.handAway,
                        y: Layout.touch.y - 2 + 30 * state.handAway
                    )
            }
        }

        private func touchMarker(_ state: FrameState) -> some View {
            ZStack {
                Circle()
                    .fill(Color.tribuneru(.vaporPageBackground).opacity(0.55))
                Circle()
                    .fill(Color.tribuneru(.vaporAccent).opacity(0.35))
                    .scaleEffect(0.4 + 0.3 * state.press)
                Circle()
                    .trim(
                        from: 0,
                        to: state.hold
                    )
                    .stroke(
                        Color.tribuneru(.vaporAccent),
                        style: StrokeStyle(
                            lineWidth: 3.5,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(2)
            }
            .frame(
                width: Layout.ring,
                height: Layout.ring
            )
            .opacity(state.marker)
        }

        private func hand(_ state: FrameState) -> some View {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 30))
                .foregroundColor(.tribuneru(.vaporTextPrimary))
                .shadow(
                    color: .tribuneru(.vaporPageBackground).opacity(0.6),
                    radius: 3,
                    y: 1
                )
                .scaleEffect(
                    1 - 0.08 * state.press,
                    anchor: .topLeading
                )
                .opacity(1 - state.handAway)
        }

        struct FrameState: Equatable {
            var cover: Double
            var press: Double
            var hold: Double
            var marker: Double
            var handAway: Double
            var winner: Winner

            static let covered = FrameState(
                cover: 1,
                press: 0,
                hold: 0,
                marker: 0,
                handAway: 1,
                winner: .man
            )

            static func shown(_ winner: Winner) -> FrameState {
                FrameState(
                    cover: 0,
                    press: 0,
                    hold: 0,
                    marker: 0,
                    handAway: 1,
                    winner: winner
                )
            }

            /// The winner stays the one already drawn, so a mode change never swaps the face mid-fade.
            func blended(
                to target: FrameState,
                by progress: Double
            ) -> FrameState {
                func mix(_ from: Double, _ to: Double) -> Double {
                    from + (to - from) * progress
                }
                return FrameState(
                    cover: mix(cover, target.cover),
                    press: mix(press, target.press),
                    hold: mix(hold, target.hold),
                    marker: mix(marker, target.marker),
                    handAway: mix(handAway, target.handAway),
                    winner: winner
                )
            }
        }

        /// The first `switchDuration` blends from the frame on screen when the mode changed into the new mode.
        static func state(
            isOn: Bool,
            elapsed: TimeInterval,
            from: FrameState
        ) -> FrameState {
            let target = isOn ? loop(at: elapsed) : .shown(from.winner)
            guard elapsed < switchDuration else { return target }
            return from.blended(
                to: target,
                by: smoothstep(elapsed / switchDuration)
            )
        }

        /// Per loop: finger arrives (0.5–1), the ring fills (1.15–2.15), the painting fades (2.15–2.9), covers again at 4.4; then stays covered.
        static func loop(at elapsed: TimeInterval) -> FrameState {
            let index = Int(elapsed / cycle)
            guard index < loops else {
                return FrameState(
                    cover: 1,
                    press: 0,
                    hold: 0,
                    marker: 0,
                    handAway: 1,
                    winner: Winner.allCases[loops - 1]
                )
            }
            let time = elapsed - Double(index) * cycle
            func ramp(_ from: Double, _ to: Double) -> Double {
                smoothstep((time - from) / (to - from))
            }
            return FrameState(
                cover: 1 - ramp(2.15, 2.9) + ramp(4.4, 4.8),
                press: ramp(1.0, 1.15) - ramp(2.15, 2.35),
                hold: ramp(1.15, 2.15),
                marker: ramp(1.0, 1.15) - ramp(2.15, 2.5),
                handAway: 1 - ramp(0.5, 1.0) + ramp(2.4, 2.9),
                winner: Winner.allCases[index]
            )
        }

        private static func smoothstep(_ value: Double) -> Double {
            let t = min(1, max(0, value))
            return t * t * (3 - 2 * t)
        }
    }
}

/// A miniature Results today card: the spoiler painting over redacted rows, or the winner and the podium.
private struct MiniResultCard: View {
    private typealias Layout = Settings.SpoilerModePreview.Layout

    let cover: Double
    let winner: Settings.SpoilerModePreview.Winner

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                WinnerAvatar(winner: winner)
                RaceArtView(
                    art: .spoiler,
                    alignment: .top
                )
                .opacity(cover)
            }
            .frame(
                width: Layout.card.width,
                height: Layout.photoHeight
            )
            .clipped()
            VStack(alignment: .leading, spacing: 6) {
                podiumRow(
                    isWinner: true,
                    width: 46
                )
                podiumRow(
                    isWinner: false,
                    width: 36
                )
                podiumRow(
                    isWinner: false,
                    width: 40
                )
            }
            .padding(.horizontal, 9)
            .frame(maxHeight: .infinity)
        }
        .frame(
            width: Layout.card.width,
            height: Layout.card.height
        )
        .background(Color.tribuneru(.vaporCardSurface))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Color.tribuneru(.vaporTextPrimary).opacity(0.12),
                    lineWidth: 1
                )
        }
    }

    private func podiumRow(
        isWinner: Bool,
        width: CGFloat
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.tribuneru(.vaporTagNeutral))
                .overlay {
                    Circle()
                        .fill(Color.tribuneru(isWinner ? .vaporAccent : .vaporTextSecondary))
                        .opacity(1 - cover)
                }
                .frame(
                    width: 7,
                    height: 7
                )
            Capsule()
                .fill(Color.tribuneru(.vaporTagNeutral))
                .overlay {
                    Capsule()
                        .fill(Color.tribuneru(isWinner ? .vaporTextPrimary : .vaporTextSecondary))
                        .opacity(1 - cover)
                }
                .frame(
                    width: width,
                    height: isWinner ? 6 : 5
                )
        }
    }
}

/// The winner's portrait: short hair, long hair, or none for the gender-neutral person.
private struct WinnerAvatar: View {
    let winner: Settings.SpoilerModePreview.Winner

    private let head: CGFloat = 20

    var body: some View {
        ZStack(alignment: .top) {
            Color.tribuneru(.vaporTagNeutral)
            Circle()
                .fill(Color.tribuneru(.vaporTextPrimary).opacity(0.08))
                .frame(
                    width: 48,
                    height: 48
                )
                .offset(y: 3)
            if winner == .woman {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color.tribuneru(.vaporPageBackground))
                    .frame(
                        width: head + 6,
                        height: 30
                    )
                    .offset(y: 4)
            }
            jersey
                .offset(y: 32)
            Rectangle()
                .fill(Color.tribuneru(.vaporTextPrimary))
                .frame(
                    width: 8,
                    height: 8
                )
                .offset(y: 25)
            Circle()
                .fill(Color.tribuneru(.vaporTextPrimary))
                .frame(
                    width: head,
                    height: head
                )
                .offset(y: 8)
            if winner != .person {
                Circle()
                    .trim(
                        from: 0.5,
                        to: 1
                    )
                    .fill(Color.tribuneru(.vaporPageBackground))
                    .frame(
                        width: head + 2,
                        height: head + 2
                    )
                    .offset(y: 4)
            }
        }
    }

    private var jersey: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 16,
            topTrailingRadius: 16
        )
        .fill(Color.tribuneru(.vaporAccent))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.tribuneru(.vaporTextPrimary).opacity(0.85))
                .frame(height: 3)
                .offset(y: 9)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                topTrailingRadius: 16
            )
        )
        .frame(
            width: 46,
            height: 24
        )
    }
}
