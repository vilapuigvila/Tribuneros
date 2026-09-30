//
//  VaporRaceCards.swift
//  Tribuneros
//

import SwiftUI

/// The common Vapor card shape: a rounded `cardSurface` box with 12pt padding.
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
