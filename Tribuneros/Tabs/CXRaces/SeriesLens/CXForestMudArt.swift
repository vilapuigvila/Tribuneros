//
//  CXForestMudArt.swift
//  Tribuneros
//

import SwiftUI

/// Other Belgian: a rider sliding through deep forest mud in fog, fans under umbrellas on the bank.
struct CXForestMudArt: View {
    var body: some View {
        CXPaintingCanvas { context in
            context.fillCXBox(
                Gradient(colors: [.tribuneru(.cxForestSkyTop), .tribuneru(.cxForestSkyBottom)])
            )
            for (x, y) in [(80.0, 230.0), (230, 226), (420, 228), (600, 230)] {
                Self.drawTree(
                    in: context,
                    at: CGPoint(x: x, y: y),
                    color: .tribuneru(.cxForestTreeFar)
                )
            }
            let fog = Color.tribuneru(.mudTextMuted)
            context.fill(
                Path(CGRect(x: 0, y: 120, width: 720, height: 140)),
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: fog.opacity(0), location: 0),
                        .init(color: fog.opacity(0.35), location: 0.5),
                        .init(color: fog.opacity(0), location: 1)
                    ]),
                    startPoint: CGPoint(x: 0, y: 120),
                    endPoint: CGPoint(x: 0, y: 260)
                )
            )
            for (x, y, scale) in [(20.0, 300.0, 1.3), (320, 290, 1), (680, 300, 1.25)] {
                Self.drawTree(
                    in: context,
                    at: CGPoint(x: x, y: y),
                    scale: scale,
                    color: .tribuneru(.mudTree)
                )
            }
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 270))
                    path.addQuadCurve(
                        to: CGPoint(x: 360, y: 266),
                        control: CGPoint(x: 180, y: 250)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 258),
                        control: CGPoint(x: 540, y: 282)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 300))
                    path.addLine(to: CGPoint(x: 0, y: 300))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.cxForestBank))
            )
            for (x, y, canopy) in [
                (420.0, 268.0, Color.Palette.mudAccent),
                (470, 264, .cxArtBlue),
                (520, 268, .mudNegative),
                (570, 264, .mudTape),
                (130, 268, .mudHillNear),
                (180, 264, .mudAccent)
            ] {
                Self.drawUmbrellaFan(
                    in: context,
                    at: CGPoint(x: x, y: y),
                    canopy: .tribuneru(canopy)
                )
            }
            context.strokeCXStakes(
                [(100, 282, 312), (380, 280, 310), (620, 282, 312)],
                color: .tribuneru(.mudTree)
            )
            context.strokeCXTape(
                Path { path in
                    path.move(to: CGPoint(x: 100, y: 286))
                    path.addQuadCurve(
                        to: CGPoint(x: 380, y: 284),
                        control: CGPoint(x: 240, y: 278)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 620, y: 286),
                        control: CGPoint(x: 520, y: 290)
                    )
                },
                dash: .tribuneru(.mudNegative)
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 296))
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 298),
                        control: CGPoint(x: 360, y: 280)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .linearGradient(
                    Gradient(colors: [.tribuneru(.mudGround), .tribuneru(.cxForestMudBottom)]),
                    startPoint: CGPoint(x: 0, y: 288),
                    endPoint: CGPoint(x: 0, y: 440)
                )
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: -10, y: 440))
                    path.addCurve(
                        to: CGPoint(x: 420, y: 332),
                        control1: CGPoint(x: 120, y: 380),
                        control2: CGPoint(x: 280, y: 340)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 320),
                        control1: CGPoint(x: 560, y: 324),
                        control2: CGPoint(x: 640, y: 330)
                    )
                    path.move(to: CGPoint(x: 20, y: 440))
                    path.addCurve(
                        to: CGPoint(x: 430, y: 348),
                        control1: CGPoint(x: 150, y: 392),
                        control2: CGPoint(x: 300, y: 356)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 340),
                        control1: CGPoint(x: 560, y: 340),
                        control2: CGPoint(x: 640, y: 348)
                    )
                },
                with: .color(.tribuneru(.mudPuddle)),
                style: StrokeStyle(
                    lineWidth: 5,
                    lineCap: .round
                )
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: -10, y: 432))
                    path.addCurve(
                        to: CGPoint(x: 420, y: 324),
                        control1: CGPoint(x: 120, y: 372),
                        control2: CGPoint(x: 280, y: 332)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 312),
                        control1: CGPoint(x: 560, y: 316),
                        control2: CGPoint(x: 640, y: 322)
                    )
                    path.move(to: CGPoint(x: 20, y: 432))
                    path.addCurve(
                        to: CGPoint(x: 430, y: 340),
                        control1: CGPoint(x: 150, y: 384),
                        control2: CGPoint(x: 300, y: 348)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 332),
                        control1: CGPoint(x: 560, y: 332),
                        control2: CGPoint(x: 640, y: 340)
                    )
                },
                with: .color(Color.tribuneru(.mudHillNear).opacity(0.7)),
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round
                )
            )
            context.fill(
                CXArtShapes.ellipses([(560, 390, 110, 14), (120, 330, 60, 8)]),
                with: .color(.tribuneru(.mudPuddle))
            )
            context.stroke(
                CXArtShapes.lines([(500, 390, 560, 390), (580, 394, 620, 394), (100, 330, 140, 330)]),
                with: .color(fog.opacity(0.5)),
                lineWidth: 1.2
            )
            context.drawCXRider(
                at: CGPoint(x: 300, y: 360),
                rotation: .degrees(-8),
                pushingArm: true
            )
            context.fill(
                CXArtShapes.circles([(270, 372, 4), (258, 360, 3), (248, 376, 5), (236, 364, 2.5), (226, 380, 3.5)]),
                with: .color(.tribuneru(.mudGround))
            )
        }
    }

    /// A bare tree: trunk and forked branches, from its foot.
    private static func drawTree(
        in context: GraphicsContext,
        at origin: CGPoint,
        scale: CGFloat = 1,
        color: Color
    ) {
        var context = context
        context.translateBy(x: origin.x, y: origin.y)
        context.scaleBy(x: scale, y: scale)
        context.stroke(
            CXArtShapes.lines([(0, 0, 0, -200)]),
            with: .color(color),
            style: StrokeStyle(
                lineWidth: 10,
                lineCap: .round
            )
        )
        context.stroke(
            CXArtShapes.lines([
                (0, -80, -34, -130),
                (0, -110, 30, -160),
                (0, -150, -24, -190),
                (-34, -130, -50, -150),
                (30, -160, 44, -186)
            ]),
            with: .color(color),
            style: StrokeStyle(
                lineWidth: 4,
                lineCap: .round
            )
        )
    }

    /// A fan sheltering under an umbrella on the bank.
    private static func drawUmbrellaFan(
        in context: GraphicsContext,
        at origin: CGPoint,
        canopy: Color
    ) {
        var context = context
        context.translateBy(x: origin.x, y: origin.y)
        let ink = Color.tribuneru(.cxForestFan)
        let dome = Path { path in
            path.addArc(
                center: .zero,
                radius: 22,
                startAngle: .degrees(180),
                endAngle: .degrees(0),
                clockwise: false,
                transform: CGAffineTransform(translationX: 0, y: -40).scaledBy(x: 1, y: 16.0 / 22)
            )
            path.closeSubpath()
        }
        context.fill(
            dome,
            with: .color(canopy)
        )
        context.stroke(
            CXArtShapes.lines([(0, -40, 0, -20)]),
            with: .color(ink),
            lineWidth: 2
        )
        var fan = CXArtShapes.circles([(0, -22, 6)])
        fan.addPath(
            Path { path in
                path.move(to: CGPoint(x: -9, y: 4))
                path.addLine(to: CGPoint(x: -9, y: -8))
                path.addArc(
                    center: CGPoint(x: 0, y: -8),
                    radius: 9,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                path.addLine(to: CGPoint(x: 9, y: 4))
                path.closeSubpath()
            }
        )
        context.fill(
            fan,
            with: .color(ink)
        )
    }
}
