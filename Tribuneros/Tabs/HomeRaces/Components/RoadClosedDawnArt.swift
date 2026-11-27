//
//  RoadClosedDawnArt.swift
//  Tribuneros
//

import SwiftUI

/// The no-data screen's painting: an empty mountain road at dawn, one small bike far down it.
struct RoadClosedDawnArt: View {
    private static let box = CGSize(width: 390, height: 560)

    var body: some View {
        Canvas { context, size in
            let box = Self.box
            let scale = max(size.width / box.width, size.height / box.height)
            context.translateBy(
                x: (size.width - box.width * scale) / 2,
                y: 0
            )
            context.scaleBy(x: scale, y: scale)
            context.clip(to: Path(CGRect(origin: .zero, size: box)))
            Self.draw(in: &context)
        }
        .accessibilityHidden(true)
    }

    private static func draw(in context: inout GraphicsContext) {
        let full = Path(CGRect(origin: .zero, size: box))
        context.fill(
            full,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .tribuneru(.roadDawnSkyTop), location: 0),
                    .init(color: .tribuneru(.roadDawnSkyMid), location: 0.45),
                    .init(color: .tribuneru(.roadDawnSkyLow), location: 0.75),
                    .init(color: .tribuneru(.roadDawnHorizon), location: 1)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: box.height)
            )
        )
        let star = Color.tribuneru(.vaporTextPrimary)
        for (x, y, r, opacity) in [(46.0, 60.0, 1.2, 0.7), (120, 104, 1, 0.5), (318, 70, 1.3, 0.7), (260, 130, 1, 0.4), (190, 40, 1.1, 0.6)] {
            context.fill(
                circle(x: x, y: y, r: r),
                with: .color(star.opacity(opacity))
            )
        }
        let glow = Color.tribuneru(.roadDawnGlow)
        context.fill(
            circle(x: 195, y: 330, r: 150),
            with: .radialGradient(
                Gradient(stops: [
                    .init(color: .tribuneru(.roadDawnSun), location: 0),
                    .init(color: glow.opacity(0.6), location: 0.35),
                    .init(color: glow.opacity(0), location: 1)
                ]),
                center: CGPoint(x: 195, y: 330),
                startRadius: 0,
                endRadius: 150
            )
        )
        context.fill(
            circle(x: 195, y: 338, r: 34),
            with: .color(.tribuneru(.roadDawnSun))
        )
        context.fill(
            polygon([(0, 360), (70, 300), (120, 340), (190, 280), (250, 335), (310, 295), (390, 350), (390, 560), (0, 560)]),
            with: .color(.tribuneru(.roadDawnSkyMid))
        )
        context.fill(
            polygon([(0, 400), (60, 360), (130, 395), (200, 350), (280, 400), (350, 365), (390, 385), (390, 560), (0, 560)]),
            with: .color(.tribuneru(.roadDawnRidgeNear))
        )
        context.fill(
            Path { path in
                path.move(to: CGPoint(x: 0, y: 560))
                path.addLine(to: CGPoint(x: 0, y: 440))
                path.addCurve(
                    to: CGPoint(x: 390, y: 436),
                    control1: CGPoint(x: 100, y: 430),
                    control2: CGPoint(x: 160, y: 425)
                )
                path.addLine(to: CGPoint(x: 390, y: 560))
                path.closeSubpath()
            },
            with: .color(.tribuneru(.roadDawnGround))
        )
        context.fill(
            Path { path in
                path.move(to: CGPoint(x: 150, y: 560))
                path.addCurve(
                    to: CGPoint(x: 192, y: 432),
                    control1: CGPoint(x: 170, y: 500),
                    control2: CGPoint(x: 186, y: 460)
                )
                path.addLine(to: CGPoint(x: 200, y: 432))
                path.addCurve(
                    to: CGPoint(x: 280, y: 560),
                    control1: CGPoint(x: 206, y: 462),
                    control2: CGPoint(x: 230, y: 505)
                )
                path.closeSubpath()
            },
            with: .color(.tribuneru(.roadDawnRoad))
        )
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: 196, y: 436))
                path.addCurve(
                    to: CGPoint(x: 238, y: 560),
                    control1: CGPoint(x: 198, y: 480),
                    control2: CGPoint(x: 214, y: 520)
                )
            },
            with: .color(glow.opacity(0.7)),
            style: StrokeStyle(
                lineWidth: 2,
                dash: [9, 10]
            )
        )
        drawBike(in: &context)
    }

    /// A bike with no rider, 25 pt wide, standing where the road meets the ridge.
    private static func drawBike(in context: inout GraphicsContext) {
        var bike = context
        bike.translateBy(x: 176, y: 438)
        bike.scaleBy(x: 0.5, y: 0.5)
        let frame = Path { path in
            path.addEllipse(in: CGRect(x: -1, y: 31, width: 18, height: 18))
            path.addEllipse(in: CGRect(x: 33, y: 31, width: 18, height: 18))
            path.move(to: CGPoint(x: 8, y: 40))
            path.addLine(to: CGPoint(x: 18, y: 22))
            path.addLine(to: CGPoint(x: 32, y: 22))
            path.addLine(to: CGPoint(x: 42, y: 40))
            path.move(to: CGPoint(x: 18, y: 22))
            path.addLine(to: CGPoint(x: 25, y: 40))
            path.addLine(to: CGPoint(x: 8, y: 40))
        }
        bike.stroke(
            frame,
            with: .color(.tribuneru(.vaporTextPrimary).opacity(0.9)),
            style: StrokeStyle(
                lineWidth: 3,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private static func circle(
        x: CGFloat,
        y: CGFloat,
        r: CGFloat
    ) -> Path {
        Path(ellipseIn: CGRect(
            x: x - r,
            y: y - r,
            width: 2 * r,
            height: 2 * r
        ))
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        Path { path in
            path.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
            path.closeSubpath()
        }
    }
}

#if DEBUG
#Preview {
    RoadClosedDawnArt()
        .frame(height: 560)
        .ignoresSafeArea()
}
#endif
