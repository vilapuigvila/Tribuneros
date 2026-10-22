//
//  Shimmer.swift
//  Tribuneros
//

import SwiftUI

/// A soft light band sweeping across loading placeholders: `.shimmering()` next to `.redacted(reason: .placeholder)`.
enum Shimmer {
    static let sweepDuration: TimeInterval = 1.3
    static let pauseDuration: TimeInterval = 0.4
    static var period: TimeInterval { sweepDuration + pauseDuration }
    static let bandWidth: CGFloat = 180
    static let restingOpacity: Double = 0.6
    static let angle: Angle = .degrees(20)
    /// Longest distance along the sweep axis on any iPhone screen.
    static let sweepSpan: CGFloat = 1000

    private static var axis: CGVector {
        CGVector(
            dx: cos(angle.radians),
            dy: sin(angle.radians)
        )
    }

    private static func position(of point: CGPoint) -> CGFloat {
        point.x * axis.dx + point.y * axis.dy
    }

    /// Band centre along the sweep axis, in screen points; the same for every caller at one instant.
    static func bandCenter(at date: Date) -> CGFloat {
        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        let progress = min(elapsed / sweepDuration, 1)
        let start = -bandWidth
        let end = sweepSpan + bandWidth
        return start + (end - start) * CGFloat(progress)
    }

    /// Mask opacity at a screen point: 1 at the band centre, `restingOpacity` away from it.
    static func opacity(
        at point: CGPoint,
        date: Date
    ) -> Double {
        let distance = abs(position(of: point) - bandCenter(at: date))
        let closeness = max(0, 1 - Double(distance / (bandWidth / 2)))
        return restingOpacity + (1 - restingOpacity) * closeness
    }

    /// Gradient end points in the local space of a view whose top-left sits at `origin` on screen.
    static func gradientPoints(
        origin: CGPoint,
        date: Date
    ) -> (start: CGPoint, end: CGPoint) {
        let center = bandCenter(at: date) - position(of: origin)
        let from = center - bandWidth / 2
        let to = center + bandWidth / 2
        return (
            CGPoint(x: axis.dx * from, y: axis.dy * from),
            CGPoint(x: axis.dx * to, y: axis.dy * to)
        )
    }

    static func isAnimating(
        isActive: Bool,
        reduceMotion: Bool,
        isInsideShimmer: Bool
    ) -> Bool {
        isActive && !reduceMotion && !isInsideShimmer
    }

    fileprivate static var gradient: Gradient {
        Gradient(stops: [
            .init(color: .tribuneru(.black).opacity(restingOpacity), location: 0),
            .init(color: .tribuneru(.black), location: 0.5),
            .init(color: .tribuneru(.black).opacity(restingOpacity), location: 1)
        ])
    }
}

extension EnvironmentValues {
    /// True inside a shimmering placeholder, so nested `.shimmering()` calls don't mask it twice.
    @Entry var isShimmering: Bool = false
}

private struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isShimmering) private var isShimmering

    func body(content: Content) -> some View {
        if Shimmer.isAnimating(
            isActive: isActive,
            reduceMotion: reduceMotion,
            isInsideShimmer: isShimmering
        ) {
            content
                .environment(\.isShimmering, true)
                .mask { ShimmerMask() }
        } else {
            content
        }
    }
}

private struct ShimmerMask: View {
    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            TimelineView(.animation) { context in
                Canvas { graphics, size in
                    let points = Shimmer.gradientPoints(
                        origin: origin,
                        date: context.date
                    )
                    graphics.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Shimmer.gradient,
                            startPoint: points.start,
                            endPoint: points.end
                        )
                    )
                }
            }
        }
    }
}

extension View {
    /// Sweeps a soft light band across a loading placeholder; still under Reduce Motion.
    func shimmering(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}
