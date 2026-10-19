//
//  CXMudArt.swift
//  Tribuneros
//

import SwiftUI

/// The CX hero painting: a muddy dusk course, drawn in a 390×196 box and scaled to fill.
struct CXMudArt: View {
    private enum Box {
        static let width: CGFloat = 390
        static let height: CGFloat = 196
    }

    var body: some View {
        Canvas { context, size in
            let scale = max(size.width / Box.width, size.height / Box.height)
            context.translateBy(
                x: (size.width - Box.width * scale) / 2,
                y: (size.height - Box.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)

            context.fill(
                Path(CGRect(x: 0, y: 0, width: Box.width, height: Box.height)),
                with: .linearGradient(
                    Gradient(colors: [.tribuneru(.mudSkyTop), .tribuneru(.mudSkyBottom)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: Box.height)
                )
            )
            context.fill(
                Path(ellipseIn: CGRect(x: 197, y: 46, width: 36, height: 36)),
                with: .color(.tribuneru(.mudSun).opacity(0.4))
            )
            context.fill(
                hill(
                    start: 110,
                    control: CGPoint(x: 90, y: 80),
                    mid: CGPoint(x: 190, y: 104),
                    end: CGPoint(x: 390, y: 92),
                    endControl: CGPoint(x: 290, y: 128)
                ),
                with: .color(.tribuneru(.mudHillFar))
            )
            context.fill(
                hill(
                    start: 146,
                    control: CGPoint(x: 110, y: 120),
                    mid: CGPoint(x: 220, y: 140),
                    end: CGPoint(x: 390, y: 132),
                    endControl: CGPoint(x: 330, y: 160)
                ),
                with: .color(.tribuneru(.mudHillNear))
            )
            context.stroke(
                tape,
                with: .color(.tribuneru(.mudTape).opacity(0.75)),
                style: StrokeStyle(lineWidth: 2, dash: [8, 6])
            )
            context.fill(
                trees,
                with: .color(.tribuneru(.mudTree))
            )
            for puddle in [
                CGRect(x: 76, y: 172, width: 88, height: 12),
                CGRect(x: 270, y: 182, width: 60, height: 8)
            ] {
                context.fill(
                    Path(ellipseIn: puddle),
                    with: .color(.tribuneru(.mudPuddle).opacity(0.8))
                )
            }
            context.fill(
                churnedGround,
                with: .color(.tribuneru(.mudGround))
            )
        }
        .accessibilityHidden(true)
    }

    private func hill(
        start: CGFloat,
        control: CGPoint,
        mid: CGPoint,
        end: CGPoint,
        endControl: CGPoint
    ) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: start))
            path.addQuadCurve(to: mid, control: control)
            path.addQuadCurve(to: end, control: endControl)
            path.addLine(to: CGPoint(x: end.x, y: Box.height))
            path.addLine(to: CGPoint(x: 0, y: Box.height))
            path.closeSubpath()
        }
    }

    private var tape: Path {
        Path { path in
            path.move(to: CGPoint(x: -10, y: 176))
            path.addCurve(
                to: CGPoint(x: 220, y: 160),
                control1: CGPoint(x: 70, y: 140),
                control2: CGPoint(x: 140, y: 190)
            )
            path.addCurve(
                to: CGPoint(x: 400, y: 162),
                control1: CGPoint(x: 300, y: 130),
                control2: CGPoint(x: 330, y: 136)
            )
        }
    }

    private var trees: Path {
        Path { path in
            for (x, top, half, height) in [
                (250.0, 78.0, 11.0, 34.0),
                (274.0, 90.0, 9.0, 26.0),
                (24.0, 100.0, 9.0, 28.0)
            ] {
                path.move(to: CGPoint(x: x + half, y: top))
                path.addLine(to: CGPoint(x: x + 2 * half, y: top + height))
                path.addLine(to: CGPoint(x: x, y: top + height))
                path.closeSubpath()
            }
        }
    }

    private var churnedGround: Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: Box.height))
            path.addQuadCurve(
                to: CGPoint(x: 130, y: 186),
                control: CGPoint(x: 60, y: 168)
            )
            path.addQuadCurve(
                to: CGPoint(x: 260, y: 180),
                control: CGPoint(x: 200, y: 204)
            )
            path.addQuadCurve(
                to: CGPoint(x: 390, y: 188),
                control: CGPoint(x: 320, y: 156)
            )
            path.addLine(to: CGPoint(x: 390, y: Box.height))
            path.closeSubpath()
        }
    }
}
