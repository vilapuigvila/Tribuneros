//
//  CyclocrossStandingsSectionView.swift
//  Tribuneros
//
//  Created by albert vila on 9/1/26.
//

import SwiftUI

struct CyclocrossStandingsSectionView: View {
    let standings: DTO.CXStandings
    let action: () -> Void

    var body: some View {
        if let first = standings.items.first {
            CyclocrossStandingsCardView(item: first, onTap: action)
        } else {
            TribuneruText(
                content: "No standings found.",
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 2
            )
            .padding(12)
            .background(Color.tribuneru(.vaporCardSurface))
            .cornerRadius(8)
        }
    }
}
