//
//  CXMudComponents.swift
//  Tribuneros
//

import SwiftUI

/// The Mud tag: a ring dot and a mono-spaced title on a neutral chip.
struct MudTag: View {
    let title: String
    var color: Color = .tribuneru(.mudTagNeutralText)

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(color, lineWidth: 1.5)
                .frame(width: 7, height: 7)
            TribuneruText(
                content: title,
                style: .vaporTag,
                color: color,
                lineLimit: 1
            )
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            Color.tribuneru(.mudTagNeutral).opacity(0.92),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.tribuneru(.mudTextPrimary).opacity(0.14), lineWidth: 1)
        )
    }
}

struct MudDivider: View {
    var body: some View {
        TribunerosDivider(
            height: 0.5,
            color: Color.tribuneru(.mudTextPrimary).opacity(0.08)
        )
    }
}

/// A section of a Mud detail screen: its title, then its content 14pt under it.
struct MudPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TribuneruText(
                content: title,
                style: .vaporHeading,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 1
            )
            .frame(minHeight: 32, alignment: .leading)
            content()
        }
    }
}

/// A rounded Mud card holding stacked rows (or any content) with 14pt side padding.
struct MudCardBox<Content: View>: View {
    var spacing: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mudCard()
    }
}

/// The "full results" style link at the foot of a card.
struct MudMoreLink: View {
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            TribuneruText(
                content: title,
                style: .vaporSeeAll,
                color: .tribuneru(.mudAccent),
                lineLimit: 1
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.tribuneru(.mudAccent))
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
