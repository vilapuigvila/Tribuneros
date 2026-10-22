//
//  ShimmerTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class ShimmerTests: XCTestCase {
    private let midSweep = Date(timeIntervalSinceReferenceDate: Shimmer.period * 1000 + Shimmer.sweepDuration / 2)

    private func pointOnBandCentre(at date: Date) -> CGPoint {
        let center = Shimmer.bandCenter(at: date)
        return CGPoint(
            x: cos(Shimmer.angle.radians) * center,
            y: sin(Shimmer.angle.radians) * center
        )
    }

    func testBandRepeatsEveryPeriod() {
        XCTAssertEqual(
            Shimmer.bandCenter(at: midSweep),
            Shimmer.bandCenter(at: midSweep.addingTimeInterval(Shimmer.period)),
            accuracy: 0.001
        )
    }

    func testOpacityIsFullAtBandCentre() {
        XCTAssertEqual(
            Shimmer.opacity(
                at: pointOnBandCentre(at: midSweep),
                date: midSweep
            ),
            1,
            accuracy: 0.001
        )
    }

    func testOpacityRestsAwayFromTheBand() {
        let centre = pointOnBandCentre(at: midSweep)
        let far = CGPoint(
            x: centre.x + Shimmer.bandWidth * 2,
            y: centre.y
        )
        XCTAssertEqual(
            Shimmer.opacity(
                at: far,
                date: midSweep
            ),
            Shimmer.restingOpacity,
            accuracy: 0.001
        )
    }

    func testSamePointSameInstantSameOpacity() {
        let point = CGPoint(x: 120, y: 300)
        let first = Shimmer.opacity(
            at: point,
            date: midSweep
        )
        let second = Shimmer.opacity(
            at: point,
            date: Date(timeIntervalSinceReferenceDate: midSweep.timeIntervalSinceReferenceDate)
        )
        XCTAssertEqual(first, second)
    }

    func testGradientPointsFollowTheViewOrigin() {
        let origin = CGPoint(x: 40, y: 200)
        let points = Shimmer.gradientPoints(
            origin: origin,
            date: midSweep
        )
        let middle = CGPoint(
            x: (points.start.x + points.end.x) / 2 + origin.x,
            y: (points.start.y + points.end.y) / 2 + origin.y
        )
        XCTAssertEqual(
            Shimmer.opacity(
                at: middle,
                date: midSweep
            ),
            1,
            accuracy: 0.001
        )
    }

    func testNoAnimationUnderReduceMotion() {
        XCTAssertFalse(Shimmer.isAnimating(isActive: true, reduceMotion: true, isInsideShimmer: false))
        XCTAssertTrue(Shimmer.isAnimating(isActive: true, reduceMotion: false, isInsideShimmer: false))
    }

    func testNoAnimationWhenNestedOrInactive() {
        XCTAssertFalse(Shimmer.isAnimating(isActive: true, reduceMotion: false, isInsideShimmer: true))
        XCTAssertFalse(Shimmer.isAnimating(isActive: false, reduceMotion: false, isInsideShimmer: false))
    }
}
