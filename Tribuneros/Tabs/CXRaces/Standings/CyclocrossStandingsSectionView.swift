//
//  CyclocrossStandingsSectionView.swift
//  Tribuneros
//
//  Created by albert vila on 9/1/26.
//

import SwiftUI

struct CyclocrossStandingsSectionView: View {
    let standings: DTO.CXStandings
    /// A leader row opens the rider screen; the rest of the card opens the full list (`action`).
    var openRider: (CXRaces.RiderStanding) -> Void = { _ in }
    let action: () -> Void

    var body: some View {
        if let first = standings.items.first {
            CyclocrossStandingsCardView(
                item: first,
                openRider: openRider,
                onTap: action
            )
        } else {
            TribuneruText(
                content: L10n.tr("No standings found."),
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
