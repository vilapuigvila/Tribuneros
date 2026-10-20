//
//  CXRainRunUpArt.swift
//  Tribuneros
//

import SwiftUI

/// Superprestige: a rider shouldering the bike up a muddy run-up in heavy rain.
struct CXRainRunUpArt: View {
    var body: some View {
        CXPaintingCanvas { context in
            context.fillCXBox(
                Gradient(colors: [.tribuneru(.cxRainSkyTop), .tribuneru(.cxRainSkyBottom)])
            )
            context.fill(
                CXArtShapes.ellipses([(120, 60, 160, 46), (340, 40, 190, 50), (600, 70, 180, 52)]),
                with: .color(Color.tribuneru(.cxRainCloudDark).opacity(0.9))
            )
            context.fill(
                CXArtShapes.ellipses([(240, 96, 150, 30), (520, 110, 160, 28)]),
                with: .color(Color.tribuneru(.cxRainCloudLight).opacity(0.7))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 230))
                    path.addQuadCurve(
                        to: CGPoint(x: 320, y: 222),
                        control: CGPoint(x: 160, y: 200)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 210),
                        control: CGPoint(x: 480, y: 244)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.cxRainHill))
            )
            var trees = CXArtShapes.rects([
                CGRect(x: 40, y: 170, width: 6, height: 64),
                CGRect(x: 640, y: 160, width: 6, height: 64)
            ])
            trees.addPath(CXArtShapes.circles([(43, 160, 30), (643, 150, 34), (610, 170, 22)]))
            context.fill(
                trees,
                with: .color(.tribuneru(.cxArtSilhouette))
            )
            // The source's diagonal bounding-box gradient, mapped to user space.
            context.fill(
                CXArtShapes.polylines([
                    [CGPoint(x: 120, y: 440), CGPoint(x: 520, y: 170), CGPoint(x: 720, y: 190), CGPoint(x: 720, y: 440)]
                ]),
                with: .linearGradient(
                    Gradient(colors: [.tribuneru(.cxRainSlopeTop), .tribuneru(.cxRainSlopeBottom)]),
                    startPoint: CGPoint(x: 120, y: 170),
                    endPoint: CGPoint(x: 322, y: 619)
                )
            )
            context.stroke(
                CXArtShapes.lines([
                    (218, 380, 262, 384),
                    (262, 350, 306, 354),
                    (306, 320, 350, 324),
                    (350, 290, 394, 294),
                    (394, 260, 438, 264),
                    (438, 230, 482, 234)
                ]),
                with: .color(.tribuneru(.cxArtEarth)),
                style: StrokeStyle(
                    lineWidth: 5,
                    lineCap: .round
                )
            )
            context.stroke(
                CXArtShapes.lines([(150, 440, 510, 196)]),
                with: .color(.tribuneru(.mudTape)),
                lineWidth: 2.5
            )
            context.strokeCXStakes(
                [(210, 370, 400), (330, 288, 318), (450, 206, 236)],
                color: .tribuneru(.cxArtSilhouette)
            )
            context.stroke(
                CXArtShapes.lines([(150, 412, 510, 168)]),
                with: .color(.tribuneru(.mudAccent)),
                style: StrokeStyle(
                    lineWidth: 3,
                    dash: [12, 8]
                )
            )
            Self.drawRunner(
                in: context,
                at: CGPoint(x: 340, y: 300)
            )
            context.fill(
                CXArtShapes.ellipses([(80, 420, 90, 12), (640, 400, 70, 10)]),
                with: .color(.tribuneru(.mudPuddle))
            )
            context.stroke(
                CXArtShapes.ellipses([(60, 418, 10, 2), (110, 422, 14, 3), (630, 400, 12, 2)]),
                with: .color(Color.tribuneru(.cxRainDrop).opacity(0.6)),
                lineWidth: 1.2
            )
            Self.drawRain(in: context)
        }
    }

    private static func drawRunner(
        in context: GraphicsContext,
        at origin: CGPoint
    ) {
        var context = context
        context.translateBy(x: origin.x, y: origin.y)
        let ink = GraphicsContext.Shading.color(.tribuneru(.cxArtRider))
        for (points, width) in [
            ([CGPoint(x: 0, y: 0), CGPoint(x: 10, y: -36), CGPoint(x: 4, y: -72)], 8.0),
            ([CGPoint(x: 10, y: -36), CGPoint(x: -12, y: -4), CGPoint(x: -20, y: 6)], 8.0),
            ([CGPoint(x: 4, y: -72), CGPoint(x: 18, y: -100)], 10.0),
            ([CGPoint(x: 16, y: -96), CGPoint(x: 34, y: -86), CGPoint(x: 44, y: -100)], 6.0)
        ] {
            context.stroke(
                CXArtShapes.polylines([points]),
                with: ink,
                style: StrokeStyle(
                    lineWidth: width,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        context.fill(
            CXArtShapes.circles([(24, -112, 9)]),
            with: ink
        )
        var bike = CXArtShapes.circles([(-14, -112, 22), (52, -108, 22)])
        bike.addPath(
            CXArtShapes.polylines([
                [CGPoint(x: -14, y: -112), CGPoint(x: 12, y: -96), CGPoint(x: 40, y: -98), CGPoint(x: 52, y: -108)],
                [CGPoint(x: 12, y: -96), CGPoint(x: 18, y: -124)]
            ])
        )
        context.stroke(
            bike,
            with: ink,
            style: StrokeStyle(
                lineWidth: 5,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    /// The source's 40pt rain tile, turned 16° like its `patternTransform`.
    private static func drawRain(in context: GraphicsContext) {
        var context = context
        context.rotate(by: .degrees(16))
        let tile: CGFloat = 40
        for (x, top, bottom, width, opacity) in [
            (6.0, 0.0, 16.0, 1.2, 0.45),
            (26.0, 18.0, 30.0, 1.0, 0.35),
            (16.0, 28.0, 40.0, 1.0, 0.3)
        ] {
            var drops: [(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)] = []
            for column in 0..<21 {
                for row in -5..<11 {
                    let left = x + CGFloat(column) * tile
                    let shift = CGFloat(row) * tile
                    drops.append((left, top + shift, left, bottom + shift))
                }
            }
            context.stroke(
                CXArtShapes.lines(drops),
                with: .color(Color.tribuneru(.cxRainDrop).opacity(opacity)),
                lineWidth: width
            )
        }
    }
}
