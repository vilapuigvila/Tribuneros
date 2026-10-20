//
//  CXMudPageComponents.swift
//  Tribuneros
//
//  Shared by the Mud list screens (full results, a rider's results, a ranking).
//

import SwiftUI

/// The title card at the top of a Mud list screen.
struct MudPageHeader: View {
    let title: String
    let subtitle: String
    var logoURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            if let logoURL {
                CachedImageView(
                    imageUrl: logoURL,
                    cornerRadius: 1
                )
                .frame(width: 36, height: 36)
                .background(Color.tribuneru(.mudRaised))
                .cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 4) {
                TribuneruText(
                    content: title,
                    style: .vaporSectionTitle,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 2
                )
                if !subtitle.isEmpty {
                    TribuneruText(
                        content: subtitle,
                        style: .vaporGroupLabel,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mudCard()
    }
}

/// A Mud card of rows drawn lazily, for tables of a few hundred rows.
struct MudRowsCard<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                row(item)
                if item.id != items.last?.id {
                    MudDivider()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mudCard()
    }
}

/// What a Mud list screen shows when its page couldn't be loaded or is empty.
struct MudMessageCard: View {
    let message: String

    var body: some View {
        TribuneruText(
            content: message,
            style: .vaporMeta,
            color: .tribuneru(.mudTextSecondary),
            lineLimit: 3
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .mudCard()
    }
}

/// The finishing place or rank at the start of a Mud row; a win in the accent colour.
struct MudPositionBadge: View {
    let position: String

    var body: some View {
        let isWin = position == "1"
        TribuneruText(
            content: position,
            style: .vaporFinishTime,
            color: .tribuneru(isWin ? .mudPageBackground : .mudTextPrimary),
            lineLimit: 1
        )
        .frame(width: 34, height: 30)
        .background(Color.tribuneru(isWin ? .mudAccent : .mudRaised))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct MudChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.tribuneru(.mudTextSecondary))
    }
}
