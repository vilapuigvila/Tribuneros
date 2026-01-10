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
        VStack(alignment: .leading) {
            TribuneruText(
                content: "Cyclocross Standings",
                style: .size20WeightBold
            )
            .padding(.bottom, 6)

            if let first = standings.items.first {
                CyclocrossStandingsCardView(item: first, onTap: action)
            } else {
                TribuneruText(
                    content: "No standings found.",
                    style: .size14WeightRegular,
                    color: .gray,
                    lineLimit: 2
                )
            }
        }
    }
}
