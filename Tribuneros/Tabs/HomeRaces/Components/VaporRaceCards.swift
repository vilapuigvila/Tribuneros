//
//  VaporRaceCards.swift
//  Tribuneros
//
//  The card shape shared across the Vapor screens. Today Races draws its own cards now
//  (see `TodayHeroCard`, `ResultHighlightCard`, `YesterdayResultRow`).
//

import SwiftUI

/// A rounded `cardSurface` box with 12pt padding and 10pt internal spacing. Used by CX Zone
/// and Paddock as the common Vapor card shape — see `VaporPanel` in `VaporSectionPanel.swift`.
struct VaporCard<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tribuneru(.vaporCardSurface))
        .cornerRadius(8)
    }
}
