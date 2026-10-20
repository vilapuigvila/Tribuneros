//
//  CXColdCoastArt.swift
//  Tribuneros
//

import SwiftUI

/// X2O Trofee: a rider pushing through cold sand dunes by a grey winter sea.
struct CXColdCoastArt: View {
    var body: some View {
        CXPaintingCanvas { context in
            context.fillCXBox(
                Gradient(colors: [.tribuneru(.cxCoastSkyTop), .tribuneru(.cxCoastSkyBottom)])
            )
            context.fill(
                CXArtShapes.circles([(150, 120, 34)]),
                with: .color(Color.tribuneru(.cxCoastFoam).opacity(0.5))
            )
            context.stroke(
                CXArtShapes.lines([(60, 70, 200, 70), (240, 96, 420, 96), (460, 60, 640, 60), (520, 130, 700, 130)]),
                with: .color(Color.tribuneru(.cxArtMist).opacity(0.5)),
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round
                )
            )
            context.fill(
                Path(CGRect(x: 0, y: 190, width: 720, height: 60)),
                with: .linearGradient(
                    Gradient(colors: [.tribuneru(.cxCoastSeaTop), .tribuneru(.cxCoastSeaBottom)]),
                    startPoint: CGPoint(x: 0, y: 190),
                    endPoint: CGPoint(x: 0, y: 250)
                )
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 30, y: 206))
                    path.addQuadCurve(
                        to: CGPoint(x: 54, y: 206),
                        control: CGPoint(x: 42, y: 200)
                    )
                    path.move(to: CGPoint(x: 160, y: 220))
                    path.addQuadCurve(
                        to: CGPoint(x: 188, y: 220),
                        control: CGPoint(x: 174, y: 214)
                    )
                    path.move(to: CGPoint(x: 300, y: 204))
                    path.addQuadCurve(
                        to: CGPoint(x: 324, y: 204),
                        control: CGPoint(x: 312, y: 198)
                    )
                    path.move(to: CGPoint(x: 440, y: 226))
                    path.addQuadCurve(
                        to: CGPoint(x: 472, y: 226),
                        control: CGPoint(x: 456, y: 220)
                    )
                    path.move(to: CGPoint(x: 600, y: 210))
                    path.addQuadCurve(
                        to: CGPoint(x: 624, y: 210),
                        control: CGPoint(x: 612, y: 204)
                    )
                },
                with: .color(Color.tribuneru(.cxArtFrost).opacity(0.55)),
                style: StrokeStyle(
                    lineWidth: 2,
                    lineCap: .round
                )
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 248))
                    path.addQuadCurve(
                        to: CGPoint(x: 240, y: 246),
                        control: CGPoint(x: 120, y: 236)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 480, y: 240),
                        control: CGPoint(x: 360, y: 256)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 248),
                        control: CGPoint(x: 600, y: 224)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 262))
                    path.addLine(to: CGPoint(x: 0, y: 262))
                    path.closeSubpath()
                },
                with: .color(Color.tribuneru(.cxCoastFoam).opacity(0.5))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 270))
                    path.addQuadCurve(
                        to: CGPoint(x: 300, y: 262),
                        control: CGPoint(x: 140, y: 220)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 560, y: 240),
                        control: CGPoint(x: 440, y: 300)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 236),
                        control: CGPoint(x: 640, y: 210)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.cxArtEarth))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 320))
                    path.addQuadCurve(
                        to: CGPoint(x: 340, y: 320),
                        control: CGPoint(x: 160, y: 270)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 300),
                        control: CGPoint(x: 520, y: 370)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .linearGradient(
                    Gradient(colors: [.tribuneru(.cxCoastDuneTop), .tribuneru(.cxCoastDuneBottom)]),
                    startPoint: CGPoint(x: 0, y: 295),
                    endPoint: CGPoint(x: 0, y: 440)
                )
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 560, y: 240))
                    path.addLine(to: CGPoint(x: 552, y: 214))
                    path.move(to: CGPoint(x: 566, y: 240))
                    path.addLine(to: CGPoint(x: 568, y: 210))
                    path.move(to: CGPoint(x: 572, y: 240))
                    path.addLine(to: CGPoint(x: 582, y: 216))
                    path.move(to: CGPoint(x: 620, y: 228))
                    path.addLine(to: CGPoint(x: 614, y: 206))
                    path.move(to: CGPoint(x: 626, y: 228))
                    path.addLine(to: CGPoint(x: 630, y: 200))
                    path.move(to: CGPoint(x: 632, y: 228))
                    path.addLine(to: CGPoint(x: 644, y: 208))
                    path.move(to: CGPoint(x: 80, y: 290))
                    path.addLine(to: CGPoint(x: 72, y: 266))
                    path.move(to: CGPoint(x: 86, y: 290))
                    path.addLine(to: CGPoint(x: 88, y: 262))
                    path.move(to: CGPoint(x: 92, y: 290))
                    path.addLine(to: CGPoint(x: 104, y: 270))
                },
                with: .color(.tribuneru(.cxCoastGrass)),
                style: StrokeStyle(
                    lineWidth: 2.5,
                    lineCap: .round
                )
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: -10, y: 440))
                    path.addCurve(
                        to: CGPoint(x: 420, y: 360),
                        control1: CGPoint(x: 140, y: 400),
                        control2: CGPoint(x: 260, y: 360)
                    )
                    path.addCurve(
                        to: CGPoint(x: 740, y: 380),
                        control1: CGPoint(x: 580, y: 360),
                        control2: CGPoint(x: 640, y: 400)
                    )
                },
                with: .color(Color.tribuneru(.cxCoastTrack).opacity(0.5)),
                style: StrokeStyle(
                    lineWidth: 40,
                    lineCap: .round
                )
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 420))
                    path.addCurve(
                        to: CGPoint(x: 420, y: 352),
                        control1: CGPoint(x: 140, y: 384),
                        control2: CGPoint(x: 260, y: 350)
                    )
                    path.addCurve(
                        to: CGPoint(x: 720, y: 372),
                        control1: CGPoint(x: 580, y: 354),
                        control2: CGPoint(x: 640, y: 392)
                    )
                    path.move(to: CGPoint(x: 0, y: 432))
                    path.addCurve(
                        to: CGPoint(x: 420, y: 368),
                        control1: CGPoint(x: 140, y: 396),
                        control2: CGPoint(x: 260, y: 366)
                    )
                    path.addCurve(
                        to: CGPoint(x: 720, y: 388),
                        control1: CGPoint(x: 580, y: 370),
                        control2: CGPoint(x: 640, y: 404)
                    )
                },
                with: .color(Color.tribuneru(.mudGround).opacity(0.6)),
                lineWidth: 2
            )
            Self.drawPusher(
                in: context,
                at: CGPoint(x: 400, y: 362)
            )
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 420, y: 80))
                    path.addQuadCurve(
                        to: CGPoint(x: 436, y: 80),
                        control: CGPoint(x: 428, y: 72)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 452, y: 80),
                        control: CGPoint(x: 444, y: 72)
                    )
                    path.move(to: CGPoint(x: 480, y: 110))
                    path.addQuadCurve(
                        to: CGPoint(x: 492, y: 110),
                        control: CGPoint(x: 486, y: 104)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 504, y: 110),
                        control: CGPoint(x: 498, y: 104)
                    )
                    path.move(to: CGPoint(x: 360, y: 120))
                    path.addQuadCurve(
                        to: CGPoint(x: 370, y: 120),
                        control: CGPoint(x: 365, y: 115)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 380, y: 120),
                        control: CGPoint(x: 375, y: 115)
                    )
                },
                with: .color(.tribuneru(.cxArtSilhouette)),
                style: StrokeStyle(
                    lineWidth: 2.5,
                    lineCap: .round
                )
            )
            context.strokeCXStakes(
                [(60, 340, 376), (230, 324, 358), (640, 330, 364)],
                color: .tribuneru(.mudTree)
            )
            context.strokeCXTape(
                Path { path in
                    path.move(to: CGPoint(x: 60, y: 344))
                    path.addQuadCurve(
                        to: CGPoint(x: 230, y: 328),
                        control: CGPoint(x: 150, y: 332)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 640, y: 334),
                        control: CGPoint(x: 450, y: 320)
                    )
                },
                dash: .tribuneru(.cxArtBlue)
            )
        }
    }

    /// The rider walking beside the bike, pushing it through the sand.
    private static func drawPusher(
        in context: GraphicsContext,
        at origin: CGPoint
    ) {
        var context = context
        context.translateBy(x: origin.x, y: origin.y)
        let ink = GraphicsContext.Shading.color(.tribuneru(.cxArtRider))
        var bike = CXArtShapes.circles([(0, 0, 22), (66, 0, 22)])
        bike.addPath(
            CXArtShapes.polylines([
                [CGPoint(x: 0, y: 0), CGPoint(x: 28, y: -30), CGPoint(x: 58, y: -32), CGPoint(x: 66, y: 0)],
                [CGPoint(x: 28, y: -30), CGPoint(x: 32, y: 0), CGPoint(x: 0, y: 0)],
                [CGPoint(x: 58, y: -32), CGPoint(x: 62, y: -44)]
            ])
        )
        for (path, width) in [
            (bike, 5.0),
            (CXArtShapes.polylines([[CGPoint(x: -6, y: 6), CGPoint(x: -20, y: -30), CGPoint(x: -24, y: -64)]]), 7.0),
            (CXArtShapes.polylines([[CGPoint(x: -24, y: -64), CGPoint(x: 4, y: -74), CGPoint(x: 56, y: -46)]]), 6.0)
        ] {
            context.stroke(
                path,
                with: ink,
                style: StrokeStyle(
                    lineWidth: width,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        context.fill(
            CXArtShapes.circles([(-18, -80, 8)]),
            with: ink
        )
    }
}
