//
//  CXFrozenDawnArt.swift
//  Tribuneros
//

import SwiftUI

/// World Cup: a frosty dawn, a rider crossing a frozen field under falling snow.
struct CXFrozenDawnArt: View {
    var body: some View {
        CXPaintingCanvas { context in
            context.fillCXBox(
                Gradient(stops: [
                    .init(color: .tribuneru(.cxDawnSkyTop), location: 0),
                    .init(color: .tribuneru(.cxDawnSkyMid), location: 0.6),
                    .init(color: .tribuneru(.cxDawnSkyBottom), location: 1)
                ])
            )
            let sun = Color.tribuneru(.mudSun)
            context.fill(
                CXArtShapes.circles([(500, 250, 150)]),
                with: .radialGradient(
                    Gradient(colors: [sun.opacity(0.55), sun.opacity(0)]),
                    center: CGPoint(x: 500, y: 250),
                    startRadius: 0,
                    endRadius: 150
                )
            )
            context.fill(
                CXArtShapes.circles([(500, 250, 40)]),
                with: .color(sun)
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 250))
                    path.addQuadCurve(
                        to: CGPoint(x: 240, y: 230),
                        control: CGPoint(x: 120, y: 190)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 480, y: 210),
                        control: CGPoint(x: 360, y: 270)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 225),
                        control: CGPoint(x: 600, y: 150)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.cxDawnHillFar))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 250))
                    path.addQuadCurve(
                        to: CGPoint(x: 240, y: 230),
                        control: CGPoint(x: 120, y: 190)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 480, y: 210),
                        control: CGPoint(x: 360, y: 270)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 225),
                        control: CGPoint(x: 600, y: 150)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 236))
                    path.addQuadCurve(
                        to: CGPoint(x: 480, y: 222),
                        control: CGPoint(x: 600, y: 226)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 240, y: 242),
                        control: CGPoint(x: 360, y: 218)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 0, y: 262),
                        control: CGPoint(x: 120, y: 206)
                    )
                    path.closeSubpath()
                },
                with: .color(Color.tribuneru(.cxArtMist).opacity(0.7))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 285))
                    path.addQuadCurve(
                        to: CGPoint(x: 360, y: 275),
                        control: CGPoint(x: 180, y: 245)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 265),
                        control: CGPoint(x: 540, y: 305)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .color(.tribuneru(.cxDawnHillNear))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 285))
                    path.addQuadCurve(
                        to: CGPoint(x: 360, y: 275),
                        control: CGPoint(x: 180, y: 245)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 265),
                        control: CGPoint(x: 540, y: 305)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 276))
                    path.addQuadCurve(
                        to: CGPoint(x: 360, y: 286),
                        control: CGPoint(x: 540, y: 270)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 0, y: 296),
                        control: CGPoint(x: 180, y: 302)
                    )
                    path.closeSubpath()
                },
                with: .color(Color.tribuneru(.cxArtFrost).opacity(0.75))
            )
            var trees = CXArtShapes.rects([
                CGRect(x: 96, y: 214, width: 5, height: 60),
                CGRect(x: 134, y: 224, width: 4, height: 48),
                CGRect(x: 628, y: 214, width: 5, height: 62)
            ])
            trees.addPath(
                CXArtShapes.polylines([
                    [CGPoint(x: 98, y: 180), CGPoint(x: 80, y: 238), CGPoint(x: 118, y: 238)],
                    [CGPoint(x: 98, y: 160), CGPoint(x: 84, y: 206), CGPoint(x: 112, y: 206)],
                    [CGPoint(x: 136, y: 196), CGPoint(x: 122, y: 244), CGPoint(x: 150, y: 244)],
                    [CGPoint(x: 630, y: 172), CGPoint(x: 610, y: 238), CGPoint(x: 650, y: 238)],
                    [CGPoint(x: 630, y: 152), CGPoint(x: 614, y: 204), CGPoint(x: 646, y: 204)]
                ])
            )
            context.fill(
                trees,
                with: .color(.tribuneru(.mudTree))
            )
            context.fill(
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 320))
                    path.addQuadCurve(
                        to: CGPoint(x: 400, y: 316),
                        control: CGPoint(x: 200, y: 296)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 720, y: 310),
                        control: CGPoint(x: 600, y: 336)
                    )
                    path.addLine(to: CGPoint(x: 720, y: 440))
                    path.addLine(to: CGPoint(x: 0, y: 440))
                    path.closeSubpath()
                },
                with: .linearGradient(
                    Gradient(colors: [.tribuneru(.cxDawnGroundTop), .tribuneru(.cxDawnGroundBottom)]),
                    startPoint: CGPoint(x: 0, y: 307),
                    endPoint: CGPoint(x: 0, y: 440)
                )
            )
            let track = Path { path in
                path.move(to: CGPoint(x: -20, y: 440))
                path.addCurve(
                    to: CGPoint(x: 400, y: 352),
                    control1: CGPoint(x: 120, y: 380),
                    control2: CGPoint(x: 260, y: 350)
                )
                path.addCurve(
                    to: CGPoint(x: 740, y: 340),
                    control1: CGPoint(x: 540, y: 354),
                    control2: CGPoint(x: 640, y: 372)
                )
            }
            context.stroke(
                track,
                with: .color(Color.tribuneru(.cxArtShadow).opacity(0.55)),
                style: StrokeStyle(
                    lineWidth: 46,
                    lineCap: .round
                )
            )
            context.stroke(
                track,
                with: .color(Color.tribuneru(.cxArtFrost).opacity(0.6)),
                style: StrokeStyle(
                    lineWidth: 3,
                    dash: [2, 14]
                )
            )
            context.fill(
                CXArtShapes.ellipses([(80, 400, 60, 6), (560, 410, 90, 7), (300, 420, 40, 4), (660, 372, 40, 4)]),
                with: .color(Color.tribuneru(.cxArtFrost).opacity(0.65))
            )
            context.strokeCXStakes(
                [(40, 330, 370), (200, 318, 356), (360, 318, 354), (520, 318, 356), (680, 314, 352)],
                color: .tribuneru(.mudTree)
            )
            context.strokeCXTape(
                Path { path in
                    path.move(to: CGPoint(x: 40, y: 334))
                    path.addQuadCurve(
                        to: CGPoint(x: 200, y: 322),
                        control: CGPoint(x: 120, y: 326)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 360, y: 322),
                        control: CGPoint(x: 280, y: 318)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 520, y: 322),
                        control: CGPoint(x: 440, y: 326)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 680, y: 318),
                        control: CGPoint(x: 600, y: 318)
                    )
                },
                dash: .tribuneru(.mudNegative)
            )
            context.drawCXRider(at: CGPoint(x: 330, y: 352))
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: 300, y: 368))
                    path.addQuadCurve(
                        to: CGPoint(x: 340, y: 366),
                        control: CGPoint(x: 320, y: 360)
                    )
                },
                with: .color(Color.tribuneru(.cxArtFrost).opacity(0.6)),
                lineWidth: 2
            )
            context.fillCXSnow(
                tile: 60,
                flakes: [(8, 12, 1.6, 0.8), (38, 6, 1.1, 0.6), (24, 34, 2, 0.7), (52, 44, 1.3, 0.55), (14, 52, 1, 0.5)]
            )
        }
    }
}
