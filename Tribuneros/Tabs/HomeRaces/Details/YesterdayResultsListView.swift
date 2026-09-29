//
//  YesterdayResultsListView.swift
//  Tribuneros
//
//  "See all" behind Yesterday: every finished race, behind the same spoiler chip.
//

import SwiftUI

struct YesterdayResultsListView: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let isSpoilerModeOn: Bool
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    TribuneruText(
                        content: "Yesterday",
                        style: .vaporSectionTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 2)
                    HomeSpoilerChip(
                        isSpoilerModeOn: isSpoilerModeOn,
                        action: { action(.spoilerModeResultYesterday) },
                        identifier: "yesterdayResults.spoiler"
                    )
                }
                YesterdayResultsCard(
                    races: races,
                    identifierPrefix: "yesterdayResults"
                ) { url in
                    action(.openLink(url))
                }
                .foldsAway(unless: isSpoilerModeOn)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
