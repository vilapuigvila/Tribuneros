//
//  CXFloodlitSnowArt.swift
//  Tribuneros
//

import SwiftUI

/// Championships: snow falling under floodlights on a night course with a finish arch.
struct CXFloodlitSnowArt: View {
    var body: some View {
        CXPaintingCanvas { context in
            context.fillCXBox(
                Gradient(colors: [.tribuneru(.cxFloodSkyTop), .tribuneru(.cxFloodSkyBottom)])
            )
            let light = Color.tribuneru(.cxFloodLight)
            context.fill(
                CXArtShapes.polylines([
                    [CGPoint(x: 110, y: 40), CGPoint(x: -40, y: 330), CGPoint(x: 300, y: 330)],
                    [CGPoint(x: 610, y: 40), CGPoint(x: 420, y: 330), CGPoint(x: 760, y: 330)]
                ]),
                with: .linearGradient(
                    Gradient(colors: [light.opacity(0.35), light.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: 40),
                    endPoint: CGPoint(x: 0, y: 330)
                )
            )
            context.fill(
                CXArtShapes.rects([
                    CGRect(x: 106, y: 40, width: 8, height: 250),
                    CGRect(x: 606, y: 40, width: 8, height: 250)
                ]),
                with: .color(.tribuneru(.cxFloodMast))
            )
            context.fill(
                CXArtShapes.rects(
                    [
                        CGRect(x: 88, y: 26, width: 44, height: 16),
                        CGRect(x: 588, y: 26, width: 44, height: 16)
                    ],
                    cornerRadius: 3
                ),
                with: .color(light)
            )
            context.fill(
                CXArtShapes.ellipses([(110, 34, 40, 20), (610, 34, 40, 20)]),
                with: .color(light.opacity(0.3))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 250))
                    path.addQuadCurve(
                        to: CGPoint(x: 360, y: 244),
                        control: CGPoint(x: 180, y: 228)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 236),
                        control: CGPoint(x: 540, y: 260)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.cxFloodHill))
            )
            context.fill(
                CXArtShapes.polylines([
                    [CGPoint(x: 200, y: 248), CGPoint(x: 190, y: 214), CGPoint(x: 210, y: 214)],
                    [CGPoint(x: 240, y: 246), CGPoint(x: 228, y: 204), CGPoint(x: 252, y: 204)],
                    [CGPoint(x: 480, y: 244), CGPoint(x: 468, y: 206), CGPoint(x: 492, y: 206)],
                    [CGPoint(x: 520, y: 246), CGPoint(x: 510, y: 216), CGPoint(x: 530, y: 216)]
                ]),
                with: .color(.tribuneru(.cxFloodMast))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 280))
                    path.addQuadCurve(
                        to: CGPoint(x: 400, y: 276),
                        control: CGPoint(x: 200, y: 262)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 270),
                        control: CGPoint(x: 600, y: 290)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .linearGradient(
                    Gradient(colors: [.tribuneru(.cxFloodSnowTop), .tribuneru(.cxFloodSnowBottom)]),
                    startPoint: CGPoint(x: 0, y: 270),
                    endPoint: CGPoint(x: 0, y: 440)
                )
            )
            Self.drawArch(in: context)
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: -10, y: 440))
                    path.addCurve(
                        to: CGPoint(x: 360, y: 300),
                        control1: CGPoint(x: 180, y: 360),
                        control2: CGPoint(x: 300, y: 320)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 360),
                        control1: CGPoint(x: 420, y: 280),
                        control2: CGPoint(x: 560, y: 320)
                    )
                    path.move(to: CGPoint(x: 10, y: 440))
                    path.addCurve(
                        to: CGPoint(x: 366, y: 312),
                        control1: CGPoint(x: 190, y: 368),
                        control2: CGPoint(x: 310, y: 330)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 380),
                        control1: CGPoint(x: 422, y: 294),
                        control2: CGPoint(x: 560, y: 334)
                    )
                },
                with: .color(Color.tribuneru(.cxFloodSnowBottom).opacity(0.7)),
                lineWidth: 3
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: -10, y: 440))
                    path.addCurve(
                        to: CGPoint(x: 362, y: 304),
                        control1: CGPoint(x: 180, y: 364),
                        control2: CGPoint(x: 300, y: 322)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 368),
                        control1: CGPoint(x: 424, y: 286),
                        control2: CGPoint(x: 560, y: 326)
                    )
                },
                with: .color(Color.tribuneru(.cxFloodSkyBottom).opacity(0.45)),
                style: StrokeStyle(
                    lineWidth: 22,
                    lineCap: .round
                )
            )
            context.drawCXRider(
                at: CGPoint(x: 150, y: 382),
                scale: 0.95
            )
            context.strokeCXStakes(
                [(40, 300, 336), (200, 292, 326), (520, 292, 326), (680, 296, 332)],
                color: .tribuneru(.cxFloodArch)
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 40, y: 304))
                    path.addQuadCurve(
                        to: CGPoint(x: 200, y: 296),
                        control: CGPoint(x: 120, y: 296)
                    )
                    path.move(to: CGPoint(x: 520, y: 296))
                    path.addQuadCurve(
                        to: CGPoint(x: 680, y: 300),
                        control: CGPoint(x: 600, y: 298)
                    )
                },
                with: .color(.tribuneru(.cxArtBlue)),
                lineWidth: 3
            )
            context.fillCXSnow(
                tile: 70,
                flakes: [(10, 14, 2, 0.9), (44, 8, 1.3, 0.7), (28, 40, 2.4, 0.8), (60, 52, 1.5, 0.6), (16, 62, 1.1, 0.6)]
            )
        }
    }

    /// The finish arch with its banner in the championship colors.
    private static func drawArch(in context: GraphicsContext) {
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: 260, y: 300))
                path.addLine(to: CGPoint(x: 260, y: 196))
                path.addQuadCurve(
                    to: CGPoint(x: 284, y: 172),
                    control: CGPoint(x: 260, y: 172)
                )
                path.addLine(to: CGPoint(x: 436, y: 172))
                path.addQuadCurve(
                    to: CGPoint(x: 460, y: 196),
                    control: CGPoint(x: 460, y: 172)
                )
                path.addLine(to: CGPoint(x: 460, y: 300))
            },
            with: .color(.tribuneru(.cxFloodArch)),
            style: StrokeStyle(
                lineWidth: 12,
                lineCap: .round
            )
        )
        context.fill(
            CXArtShapes.rects(
                [CGRect(x: 276, y: 180, width: 168, height: 26)],
                cornerRadius: 4
            ),
            with: .color(.tribuneru(.mudTape))
        )
        context.fill(
            Path(CGRect(x: 296, y: 186, width: 40, height: 14)),
            with: .color(.tribuneru(.cxArtBlue))
        )
        let white = Path(CGRect(x: 340, y: 186, width: 40, height: 14))
        context.fill(
            white,
            with: .color(.tribuneru(.mudTape))
        )
        context.stroke(
            white,
            with: .color(.tribuneru(.mudTextMuted)),
            lineWidth: 1
        )
        context.fill(
            Path(CGRect(x: 384, y: 186, width: 40, height: 14)),
            with: .color(.tribuneru(.mudNegative))
        )
    }
}
