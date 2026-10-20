//
//  CXSeriesArt.swift
//  Tribuneros
//

import SwiftUI

/// The next-round hero painting of a series; Exact Cross keeps the generic mud course.
struct CXSeriesArt: View {
    let series: CXRaces.RaceSeries

    var body: some View {
        switch series {
        case .worldCup:
            CXFrozenDawnArt()
        case .superprestige:
            CXRainRunUpArt()
        case .x2oTrofee:
            CXColdCoastArt()
        case .exactCross:
            CXMudArt()
        case .championships:
            CXFloodlitSnowArt()
        case .otherBelgian:
            CXForestMudArt()
        case .others:
            CXBeerTentArt()
        }
    }
}

/// A series painting, drawn in a 720×440 box and scaled to fill.
struct CXPaintingCanvas: View {
    static let box = CGSize(width: 720, height: 440)

    let draw: (GraphicsContext) -> Void

    var body: some View {
        Canvas { context, size in
            let box = Self.box
            let scale = max(size.width / box.width, size.height / box.height)
            context.translateBy(
                x: (size.width - box.width * scale) / 2,
                y: (size.height - box.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            context.clip(to: Path(CGRect(origin: .zero, size: box)))
            draw(context)
        }
        .accessibilityHidden(true)
    }
}

/// Shape groups written with the SVG sources' own numbers (centers and radii, line ends).
enum CXArtShapes {
    static func circles(_ items: [(cx: CGFloat, cy: CGFloat, r: CGFloat)]) -> Path {
        Path { path in
            for item in items {
                path.addEllipse(
                    in: CGRect(
                        x: item.cx - item.r,
                        y: item.cy - item.r,
                        width: 2 * item.r,
                        height: 2 * item.r
                    )
                )
            }
        }
    }

    static func ellipses(_ items: [(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat)]) -> Path {
        Path { path in
            for item in items {
                path.addEllipse(
                    in: CGRect(
                        x: item.cx - item.rx,
                        y: item.cy - item.ry,
                        width: 2 * item.rx,
                        height: 2 * item.ry
                    )
                )
            }
        }
    }

    static func lines(_ items: [(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)]) -> Path {
        Path { path in
            for item in items {
                path.move(to: CGPoint(x: item.x1, y: item.y1))
                path.addLine(to: CGPoint(x: item.x2, y: item.y2))
            }
        }
    }

    /// Open polylines; a closed one repeats its first point or is filled.
    static func polylines(_ items: [[CGPoint]]) -> Path {
        Path { path in
            for points in items {
                path.addLines(points)
            }
        }
    }

    static func rects(
        _ items: [CGRect],
        cornerRadius: CGFloat = 0
    ) -> Path {
        Path { path in
            for rect in items {
                path.addRoundedRect(
                    in: rect,
                    cornerSize: CGSize(
                        width: cornerRadius,
                        height: cornerRadius
                    )
                )
            }
        }
    }
}

extension GraphicsContext {
    func fillCXBox(_ gradient: Gradient) {
        fill(
            Path(CGRect(origin: .zero, size: CXPaintingCanvas.box)),
            with: .linearGradient(
                gradient,
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: CXPaintingCanvas.box.height)
            )
        )
    }

    /// Course tape: a white band under a dashed colored one.
    func strokeCXTape(
        _ path: Path,
        dash color: Color
    ) {
        stroke(
            path,
            with: .color(.tribuneru(.mudTape)),
            lineWidth: 3
        )
        stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: 3,
                dash: [10, 10]
            )
        )
    }

    func strokeCXStakes(
        _ stakes: [(x: CGFloat, top: CGFloat, bottom: CGFloat)],
        color: Color
    ) {
        stroke(
            CXArtShapes.lines(stakes.map { ($0.x, $0.top, $0.x, $0.bottom) }),
            with: .color(color),
            lineWidth: 3
        )
    }

    /// The seated rider shared by three paintings; `pushingArm` adds the arm braced on the bars.
    func drawCXRider(
        at origin: CGPoint,
        scale: CGFloat = 1,
        rotation: Angle = .zero,
        pushingArm: Bool = false
    ) {
        var context = self
        context.translateBy(x: origin.x, y: origin.y)
        context.rotate(by: rotation)
        context.scaleBy(x: scale, y: scale)
        let ink = GraphicsContext.Shading.color(.tribuneru(.cxArtRider))
        func style(_ width: CGFloat) -> StrokeStyle {
            StrokeStyle(
                lineWidth: width,
                lineCap: .round,
                lineJoin: .round
            )
        }
        context.stroke(
            CXArtShapes.circles([(0, 0, 22), (66, 0, 22)]),
            with: ink,
            style: style(5)
        )
        context.stroke(
            CXArtShapes.polylines([
                [CGPoint(x: 0, y: 0), CGPoint(x: 28, y: -30), CGPoint(x: 58, y: -32), CGPoint(x: 66, y: 0)],
                [CGPoint(x: 28, y: -30), CGPoint(x: 32, y: 0), CGPoint(x: 0, y: 0)],
                [CGPoint(x: 28, y: -30), CGPoint(x: 24, y: -40)],
                [CGPoint(x: 58, y: -32), CGPoint(x: 62, y: -44)]
            ]),
            with: ink,
            style: style(5)
        )
        context.stroke(
            CXArtShapes.polylines([
                [CGPoint(x: 22, y: -44), CGPoint(x: 52, y: -62)],
                [CGPoint(x: 52, y: -62), CGPoint(x: 62, y: -46)],
                [CGPoint(x: 22, y: -44), CGPoint(x: 38, y: -20), CGPoint(x: 32, y: 0)]
            ]),
            with: ink,
            style: style(7)
        )
        if pushingArm {
            context.stroke(
                CXArtShapes.polylines([
                    [CGPoint(x: 30, y: -50), CGPoint(x: 4, y: -28), CGPoint(x: -8, y: -2)]
                ]),
                with: ink,
                style: style(6)
            )
        }
        context.fill(
            CXArtShapes.circles([(61, -70, 8)]),
            with: ink
        )
    }

    /// A repeating snow tile, like the sources' `<pattern>`, laid from the box origin.
    func fillCXSnow(
        tile: CGFloat,
        flakes: [(cx: CGFloat, cy: CGFloat, r: CGFloat, opacity: Double)]
    ) {
        let columns = Int((CXPaintingCanvas.box.width / tile).rounded(.up))
        let rows = Int((CXPaintingCanvas.box.height / tile).rounded(.up))
        for flake in flakes {
            var items: [(cx: CGFloat, cy: CGFloat, r: CGFloat)] = []
            for column in 0..<columns {
                for row in 0..<rows {
                    items.append((
                        flake.cx + CGFloat(column) * tile,
                        flake.cy + CGFloat(row) * tile,
                        flake.r
                    ))
                }
            }
            fill(
                CXArtShapes.circles(items),
                with: .color(Color.tribuneru(.mudTape).opacity(flake.opacity))
            )
        }
    }
}
