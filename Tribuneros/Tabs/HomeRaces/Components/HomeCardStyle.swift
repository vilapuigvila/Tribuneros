//
//  HomeCardStyle.swift
//  Tribuneros
//

import SwiftUI

extension View {
    /// The Today Races card surface: a rounded `vaporCardSurface` box with a hairline border.
    func homeCard(cornerRadius: CGFloat = 20) -> some View {
        background(Color.tribuneru(.vaporCardSurface))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        Color.tribuneru(.vaporTextPrimary).opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}
