//
//  RaceStatusTag.swift
//  Tribuneros
//
//  The pill in the corner of a race image: red LIVE, or a grey one when nothing is live.
//

import SwiftUI

struct RaceStatusTag: View {
    enum Kind {
        case live
        case today
        case noRaces

        var title: String {
            switch self {
            case .live: "LIVE"
            case .today: "TODAY"
            case .noRaces: "NO RACES"
            }
        }
    }

    enum Size {
        case regular
        case small
    }

    let kind: Kind
    var size: Size = .regular

    private var isRegular: Bool { size == .regular }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: isRegular ? 10 : 7)
    }

    var body: some View {
        HStack(spacing: isRegular ? 6 : 4) {
            dot
            TribuneruText(
                content: kind.title,
                style: isRegular ? .vaporTag : .vaporTagSmall,
                color: textColor,
                lineLimit: 1
            )
        }
        .padding(.horizontal, isRegular ? 11 : 7)
        .padding(.vertical, isRegular ? 6 : 3)
        .background(fill, in: shape)
        .overlay(border)
        .shadow(
            color: kind == .live && isRegular ? Color.tribuneru(.vaporLiveRed).opacity(0.5) : .clear,
            radius: 6,
            x: 0,
            y: 2
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title.capitalized)
    }

    @ViewBuilder
    private var dot: some View {
        if kind == .live {
            Circle()
                .fill(Color.tribuneru(.white(level: 1)))
                .frame(width: isRegular ? 6 : 5, height: isRegular ? 6 : 5)
        } else {
            Circle()
                .strokeBorder(Color.tribuneru(.vaporTagNeutralDot), lineWidth: isRegular ? 1.5 : 1.2)
                .frame(width: isRegular ? 7 : 5, height: isRegular ? 7 : 5)
        }
    }

    private var fill: Color {
        kind == .live
            ? Color.tribuneru(.vaporLiveRed)
            : Color.tribuneru(.vaporTagNeutral).opacity(0.92)
    }

    private var textColor: Color {
        kind == .live
            ? Color.tribuneru(.white(level: 1))
            : Color.tribuneru(.vaporTagNeutralText)
    }

    @ViewBuilder
    private var border: some View {
        if kind != .live {
            shape.strokeBorder(
                Color.tribuneru(.vaporTextPrimary).opacity(0.14),
                lineWidth: 1
            )
        }
    }
}

extension HomeRaces.Representable.RaceNext {
    var statusKind: RaceStatusTag.Kind {
        isLive ? .live : .today
    }
}
