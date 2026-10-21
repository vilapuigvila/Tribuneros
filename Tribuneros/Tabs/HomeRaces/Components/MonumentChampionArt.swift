//
//  MonumentChampionArt.swift
//  Tribuneros
//

import SwiftUI

/// The painting that covers a hidden result: the classic spoiler art, or a Monument's triple champion.
enum SpoilerCover: Hashable, Sendable {
    case classic
    case monument(Monument)

    enum Monument: CaseIterable, Sendable {
        case roubaix
        case sanremo
        case flanders
    }

    /// Shuffled once per launch, so neighbouring rows always differ and the order changes between launches.
    static let monumentOrder = Monument.allCases.shuffled()

    static func monument(forRow row: Int) -> SpoilerCover {
        .monument(monumentOrder[row % monumentOrder.count])
    }
}

struct SpoilerCoverView: View {
    let cover: SpoilerCover

    var body: some View {
        switch cover {
        case .classic:
            RaceArtView(art: .spoiler)
        case .monument(let monument):
            MonumentChampionArt(monument: monument)
        }
    }
}

/// Three identical riders with barred faces in a Monument's jersey, drawn in a 160×100 box and scaled to fill.
struct MonumentChampionArt: View {
    private enum Box {
        static let width: CGFloat = 160
        static let height: CGFloat = 100
        static let riders: [CGFloat] = [44, 116, 80]
    }

    let monument: SpoilerCover.Monument

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
                with: .color(.tribuneru(background))
            )
            for x in Box.riders {
                var rider = context
                rider.translateBy(x: x, y: 0)
                drawRider(in: &rider)
            }
        }
        .accessibilityHidden(true)
    }

    private var background: Color.Palette {
        switch monument {
        case .roubaix: .monumentOrange
        case .sanremo: .monumentYellow
        case .flanders: .monumentRed
        }
    }

    private var jersey: Color.Palette {
        switch monument {
        case .roubaix: .monumentSlate
        case .sanremo: .monumentBlue
        case .flanders: .monumentYellow
        }
    }

    private var headRadius: CGFloat {
        monument == .roubaix ? 9.5 : 10
    }

    private func drawRider(in context: inout GraphicsContext) {
        let skin = GraphicsContext.Shading.color(.tribuneru(.monumentSkin))
        let ink = GraphicsContext.Shading.color(.tribuneru(.monumentInk))
        let outline = StrokeStyle(lineWidth: 1.4)
        // Roubaix lifts the cobblestone overhead; the others raise both arms.
        let hands = monument == .roubaix
            ? [CGPoint(x: -10, y: 14), CGPoint(x: 10, y: 14)]
            : [CGPoint(x: -21, y: 15), CGPoint(x: 21, y: 15)]
        let elbows = monument == .roubaix
            ? [CGPoint(x: -10, y: 14), CGPoint(x: 10, y: 14)]
            : [CGPoint(x: -21, y: 18), CGPoint(x: 21, y: 18)]
        let shoulders = monument == .roubaix
            ? [CGPoint(x: -13, y: 56), CGPoint(x: 13, y: 56)]
            : [CGPoint(x: -11, y: 56), CGPoint(x: 11, y: 56)]

        for (shoulder, elbow) in zip(shoulders, elbows) {
            context.stroke(
                Path { $0.move(to: shoulder); $0.addLine(to: elbow) },
                with: skin,
                style: StrokeStyle(lineWidth: 7, lineCap: .round)
            )
        }
        if monument == .roubaix {
            let stone = Path(roundedRect: CGRect(x: -13, y: 2, width: 26, height: 11), cornerRadius: 3)
            context.fill(stone, with: .color(.tribuneru(.monumentTrophy)))
            context.stroke(stone.offsetBy(dx: 1.6, dy: -1.2), with: ink, style: outline)
        }
        for hand in hands {
            context.fill(circle(hand, radius: 5), with: skin)
        }
        context.fill(Path(CGRect(x: -4, y: 42, width: 8, height: 12)), with: skin)

        let body = torso(closed: true)
        context.fill(body, with: .color(.tribuneru(jersey)))
        drawJerseyMotif(clippedTo: body, in: context)

        let head = CGPoint(x: 0, y: 34)
        context.fill(circle(head, radius: headRadius), with: skin)
        context.fill(
            Path(CGRect(x: -(headRadius + 4), y: 30, width: (headRadius + 4) * 2, height: 7)),
            with: .color(.tribuneru(.monumentFaceBar))
        )
        context.stroke(circle(head, radius: headRadius).offsetBy(dx: 1.6, dy: -1.2), with: ink, style: outline)
        context.stroke(torso(closed: false).offsetBy(dx: 1.6, dy: -1.2), with: ink, style: outline)
    }

    private func drawJerseyMotif(clippedTo body: Path, in context: GraphicsContext) {
        var context = context
        context.clip(to: body)
        switch monument {
        case .roubaix:
            let cobbles: [(CGFloat, CGFloat, Color.Palette)] = [
                (0.6, 0.6, .monumentPaveLight),
                (8.6, 0.6, .monumentPaveDark),
                (-3.4, 6.6, .monumentPaveDark),
                (4.6, 6.6, .monumentPaveLight),
                (12.6, 6.6, .monumentPaveDark)
            ]
            for tileX in stride(from: CGFloat(-32), through: 16, by: 16) {
                for tileY in stride(from: CGFloat(48), through: 96, by: 12) {
                    for (x, y, color) in cobbles {
                        context.fill(
                            Path(roundedRect: CGRect(x: tileX + x, y: tileY + y, width: 6.8, height: 4.8), cornerRadius: 1.6),
                            with: .color(.tribuneru(color))
                        )
                    }
                }
            }
        case .sanremo:
            var wave = Path()
            wave.move(to: CGPoint(x: -16.2, y: 66))
            for (index, endX) in [-8.2, -0.2, 7.8, 15.8].enumerated() {
                wave.addQuadCurve(
                    to: CGPoint(x: endX, y: 66),
                    control: CGPoint(x: endX - 4, y: index.isMultiple(of: 2) ? 62.5 : 69.5)
                )
            }
            context.stroke(
                wave,
                with: .color(.tribuneru(.monumentWhite)),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
            drawFlower(at: CGPoint(x: -7, y: 79), petals: .monumentRed, in: context)
            drawFlower(at: CGPoint(x: 7, y: 87), petals: .monumentOrange, in: context)
        case .flanders:
            var hills = Path()
            hills.addLines([
                CGPoint(x: -16.6, y: 80), CGPoint(x: -11, y: 80), CGPoint(x: -7.5, y: 68), CGPoint(x: -4, y: 80),
                CGPoint(x: 1, y: 80), CGPoint(x: 5.5, y: 63), CGPoint(x: 10, y: 80), CGPoint(x: 16.8, y: 80),
                CGPoint(x: 17.1, y: 87), CGPoint(x: -17, y: 87)
            ])
            hills.closeSubpath()
            context.fill(hills, with: .color(.tribuneru(.monumentInk)))
            for x in stride(from: CGFloat(-12), through: 12, by: 4) {
                context.fill(circle(CGPoint(x: x, y: 84), radius: 0.9), with: .color(.tribuneru(.monumentYellow)))
            }
        }
    }

    private func drawFlower(at center: CGPoint, petals: Color.Palette, in context: GraphicsContext) {
        for (dx, dy) in [(0, -2.5), (0, 2.5), (-2.5, 0), (2.5, 0)] as [(CGFloat, CGFloat)] {
            context.fill(
                circle(CGPoint(x: center.x + dx, y: center.y + dy), radius: 2.6),
                with: .color(.tribuneru(petals))
            )
        }
        context.fill(circle(center, radius: 1.4), with: .color(.tribuneru(.monumentInk)))
    }

    private func torso(closed: Bool) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: -18, y: 100))
        path.addLine(to: CGPoint(x: -16, y: 56))
        path.addQuadCurve(to: CGPoint(x: 16, y: 56), control: CGPoint(x: 0, y: 49))
        path.addLine(to: CGPoint(x: 18, y: 100))
        if closed {
            path.closeSubpath()
        }
        return path
    }

    private func circle(_ center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(SpoilerCover.Monument.allCases, id: \.self) { monument in
            HStack(spacing: 12) {
                MonumentChampionArt(monument: monument)
                    .frame(width: 180, height: 112)
                MonumentChampionArt(monument: monument)
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    .padding()
    .background(Color.tribuneru(.vaporPageBackground))
}
