//
//  CXBeerTentArt.swift
//  Tribuneros
//

import SwiftUI

/// Exact Cross: fans raising beers behind the course tape next to a beer tent at dusk.
struct CXBeerTentArt: View {
    private enum Fan {
        case dark
        case brown
        case warm
    }

    var body: some View {
        CXPaintingCanvas { context in
            context.fillCXBox(
                Gradient(colors: [.tribuneru(.cxTentSkyTop), .tribuneru(.cxTentSkyBottom)])
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 200))
                    path.addQuadCurve(
                        to: CGPoint(x: 360, y: 190),
                        control: CGPoint(x: 180, y: 170)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 180),
                        control: CGPoint(x: 540, y: 210)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.cxTentHill))
            )
            var trees = CXArtShapes.rects([
                CGRect(x: 20, y: 130, width: 6, height: 80),
                CGRect(x: 690, y: 120, width: 6, height: 90)
            ])
            trees.addPath(
                CXArtShapes.polylines([
                    [CGPoint(x: 23, y: 100), CGPoint(x: 4, y: 170), CGPoint(x: 42, y: 170)],
                    [CGPoint(x: 693, y: 90), CGPoint(x: 670, y: 170), CGPoint(x: 716, y: 170)]
                ])
            )
            context.fill(
                trees,
                with: .color(.tribuneru(.cxTentTree))
            )
            let warm = Color.tribuneru(.mudAccent)
            context.fill(
                CXArtShapes.circles([(460, 190, 170)]),
                with: .radialGradient(
                    Gradient(colors: [warm.opacity(0.45), warm.opacity(0)]),
                    center: CGPoint(x: 460, y: 190),
                    startRadius: 0,
                    endRadius: 170
                )
            )
            Self.drawTent(in: context)
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 60))
                    path.addQuadCurve(
                        to: CGPoint(x: 240, y: 70),
                        control: CGPoint(x: 120, y: 110)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 480, y: 60),
                        control: CGPoint(x: 360, y: 30)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 70),
                        control: CGPoint(x: 600, y: 90)
                    )
                },
                with: .color(.tribuneru(.mudTree)),
                lineWidth: 1.5
            )
            context.fill(
                CXArtShapes.circles([
                    (30, 72, 4), (80, 88, 4), (130, 94, 4), (180, 88, 4), (230, 72, 4), (290, 62, 4),
                    (350, 66, 4), (420, 62, 4), (480, 60, 4), (540, 62, 4), (600, 66, 4), (660, 70, 4)
                ]),
                with: .color(.tribuneru(.mudSun))
            )
            context.fill(
                CXArtShapes.circles([(80, 88, 10), (230, 72, 10), (420, 62, 10), (600, 66, 10)]),
                with: .color(Color.tribuneru(.mudSun).opacity(0.25))
            )
            Self.drawFans(in: context)
            context.fill(
                CXArtShapes.rects(
                    [
                        CGRect(x: 104, y: 250, width: 22, height: 7),
                        CGRect(x: 444, y: 250, width: 22, height: 7)
                    ],
                    cornerRadius: 3
                ),
                with: .color(.tribuneru(.mudAccent))
            )
            context.fill(
                CXArtShapes.rects(
                    [
                        CGRect(x: 206, y: 256, width: 20, height: 7),
                        CGRect(x: 562, y: 258, width: 20, height: 7)
                    ],
                    cornerRadius: 3
                ),
                with: .color(.tribuneru(.mudNegative))
            )
            context.strokeCXStakes(
                [(30, 292, 330), (250, 292, 330), (470, 292, 330), (700, 292, 330)],
                color: .tribuneru(.mudTree)
            )
            context.strokeCXTape(
                CXArtShapes.lines([(0, 300, 720, 300)]),
                dash: .tribuneru(.mudNegative)
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 316))
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 318),
                        control: CGPoint(x: 360, y: 300)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.mudGround))
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: -10, y: 400))
                    path.addCurve(
                        to: CGPoint(x: 730, y: 384),
                        control1: CGPoint(x: 160, y: 370),
                        control2: CGPoint(x: 420, y: 360)
                    )
                    path.move(to: CGPoint(x: -10, y: 414))
                    path.addCurve(
                        to: CGPoint(x: 730, y: 400),
                        control1: CGPoint(x: 160, y: 386),
                        control2: CGPoint(x: 420, y: 378)
                    )
                },
                with: .color(Color.tribuneru(.cxTentRut).opacity(0.8)),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round
                )
            )
            context.fill(
                CXArtShapes.ellipses([(180, 420, 70, 9), (560, 350, 60, 7)]),
                with: .color(.tribuneru(.mudPuddle))
            )
            context.fill(
                CXArtShapes.ellipses([(170, 420, 20, 2), (560, 350, 18, 2)]),
                with: .color(Color.tribuneru(.mudAccent).opacity(0.35))
            )
        }
    }

    private static func drawTent(in context: GraphicsContext) {
        context.fill(
            CXArtShapes.polylines([
                [CGPoint(x: 330, y: 120), CGPoint(x: 460, y: 70), CGPoint(x: 600, y: 120)]
            ]),
            with: .color(.tribuneru(.mudTape))
        )
        context.fill(
            CXArtShapes.polylines([
                [CGPoint(x: 346, y: 114), CGPoint(x: 376, y: 102), CGPoint(x: 392, y: 120)],
                [CGPoint(x: 408, y: 96), CGPoint(x: 440, y: 84), CGPoint(x: 452, y: 120)],
                [CGPoint(x: 472, y: 84), CGPoint(x: 504, y: 96), CGPoint(x: 512, y: 120)],
                [CGPoint(x: 536, y: 102), CGPoint(x: 566, y: 114), CGPoint(x: 572, y: 120)]
            ]),
            with: .color(.tribuneru(.mudNegative))
        )
        let valance = Path { path in
            path.move(to: CGPoint(x: 330, y: 120))
            for scallop in 0..<9 {
                let left = 330 + CGFloat(scallop) * 30
                path.addQuadCurve(
                    to: CGPoint(x: left + 30, y: 120),
                    control: CGPoint(x: left + 15, y: 132)
                )
            }
        }
        context.fill(
            valance,
            with: .color(.tribuneru(.mudTape))
        )
        context.fill(
            Path(CGRect(x: 340, y: 124, width: 250, height: 96)),
            with: .color(.tribuneru(.mudSkyTop))
        )
        context.fill(
            Path(CGRect(x: 356, y: 150, width: 218, height: 40)),
            with: .color(Color.tribuneru(.mudAccent).opacity(0.85))
        )
        context.fill(
            CXArtShapes.rects(
                [
                    CGRect(x: 372, y: 160, width: 10, height: 20),
                    CGRect(x: 390, y: 160, width: 10, height: 20),
                    CGRect(x: 408, y: 160, width: 10, height: 20)
                ],
                cornerRadius: 2
            ),
            with: .color(.tribuneru(.cxTentTree))
        )
        context.fill(
            CXArtShapes.rects(
                [CGRect(x: 520, y: 156, width: 40, height: 28)],
                cornerRadius: 4
            ),
            with: .color(.tribuneru(.cxTentTree))
        )
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: 534, y: 150))
                path.addQuadCurve(
                    to: CGPoint(x: 536, y: 124),
                    control: CGPoint(x: 528, y: 136)
                )
                path.move(to: CGPoint(x: 546, y: 150))
                path.addQuadCurve(
                    to: CGPoint(x: 544, y: 120),
                    control: CGPoint(x: 552, y: 134)
                )
            },
            with: .color(Color.tribuneru(.mudTextMuted).opacity(0.6)),
            lineWidth: 2
        )
    }

    /// Twelve fans along the tape, each with a raised arm; every other one holds a beer.
    private static func drawFans(in context: GraphicsContext) {
        let fans: [(x: CGFloat, y: CGFloat, fan: Fan)] = [
            (60, 290, .dark), (110, 296, .brown), (160, 288, .dark), (215, 294, .warm),
            (270, 290, .dark), (330, 296, .brown), (390, 290, .dark), (450, 294, .warm),
            (510, 290, .dark), (570, 296, .brown), (630, 290, .dark), (685, 294, .warm)
        ]
        let outline = Color.tribuneru(.cxArtShadow)
        for fan in fans {
            var context = context
            context.translateBy(x: fan.x, y: fan.y)
            var body = Path { path in
                path.move(to: CGPoint(x: -13, y: 4))
                path.addLine(to: CGPoint(x: -13, y: -28))
                path.addArc(
                    center: CGPoint(x: 0, y: -28),
                    radius: 13,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
                path.addLine(to: CGPoint(x: 13, y: 4))
                path.closeSubpath()
            }
            body.addPath(CXArtShapes.circles([(0, -48, 9)]))
            context.fill(
                body,
                with: .color(color(of: fan.fan))
            )
            context.stroke(
                body,
                with: .color(outline),
                lineWidth: 1
            )
            context.stroke(
                CXArtShapes.lines([(8, -30, 18, -58)]),
                with: .color(outline),
                style: StrokeStyle(
                    lineWidth: 6,
                    lineCap: .round
                )
            )
        }
        for fan in fans where fan.fan == .dark {
            var context = context
            context.translateBy(x: fan.x, y: fan.y)
            context.fill(
                CXArtShapes.rects(
                    [CGRect(x: 12, y: -76, width: 12, height: 16)],
                    cornerRadius: 2
                ),
                with: .color(.tribuneru(.mudAccent))
            )
            context.fill(
                CXArtShapes.rects(
                    [CGRect(x: 11, y: -80, width: 14, height: 6)],
                    cornerRadius: 3
                ),
                with: .color(.tribuneru(.mudTape))
            )
        }
    }

    private static func color(of fan: Fan) -> Color {
        switch fan {
        case .dark:
            .tribuneru(.cxArtShadow)
        case .brown:
            .tribuneru(.cxTentFan)
        case .warm:
            .tribuneru(.mudHillFar)
        }
    }
}
