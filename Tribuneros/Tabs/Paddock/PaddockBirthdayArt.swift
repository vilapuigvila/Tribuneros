//
//  PaddockBirthdayArt.swift
//  Tribuneros
//

import SwiftUI

/// The birthday card's painting: confetti over a violet sky and a cake, in a 390×120 box scaled to fill.
struct PaddockBirthdayArt: View {
    private enum Box {
        static let width: CGFloat = 390
        static let height: CGFloat = 120
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
                    Gradient(colors: [.tribuneru(.kitSkyTop), .tribuneru(.kitSkyBottom)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: Box.height)
                )
            )

            let confetti: [(x: CGFloat, y: CGFloat, angle: Double, color: Color)] = [
                (40, 20, 20, .tribuneru(.kitAccent)),
                (110, 40, -30, .tribuneru(.kitConfettiYellow)),
                (300, 18, 40, .tribuneru(.kitProgram)),
                (350, 52, -15, .tribuneru(.kitAccent)),
                (230, 30, 10, .tribuneru(.kitConfettiPink))
            ]
            for piece in confetti {
                var copy = context
                copy.translateBy(x: piece.x + 3, y: piece.y + 6)
                copy.rotate(by: .degrees(piece.angle))
                copy.fill(
                    Path(CGRect(x: -3, y: -6, width: 6, height: 12)),
                    with: .color(piece.color.opacity(0.85))
                )
            }
            for dot in [
                (CGPoint(x: 170, y: 22), Color.tribuneru(.kitConfettiYellow)),
                (CGPoint(x: 270, y: 60), Color.tribuneru(.kitProgram)),
                (CGPoint(x: 70, y: 70), Color.tribuneru(.kitConfettiPink))
            ] {
                context.fill(
                    Path(ellipseIn: CGRect(x: dot.0.x - 3, y: dot.0.y - 3, width: 6, height: 6)),
                    with: .color(dot.1.opacity(0.85))
                )
            }

            context.translateBy(x: 155, y: 52)
            context.fill(
                Path(roundedRect: CGRect(x: 0, y: 20, width: 80, height: 44), cornerRadius: 6),
                with: .color(.tribuneru(.kitAvatarText))
            )
            context.fill(
                Path(roundedRect: CGRect(x: 0, y: 20, width: 80, height: 10), cornerRadius: 5),
                with: .color(.tribuneru(.kitAccent))
            )
            for x in [18.0, 38.0, 58.0] {
                context.fill(
                    Path(CGRect(x: x, y: 4, width: 4, height: 16)),
                    with: .color(.tribuneru(.kitTextPrimary))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 1, y: -1, width: 6, height: 6)),
                    with: .color(.tribuneru(.kitConfettiYellow))
                )
            }
        }
        .accessibilityHidden(true)
    }
}
