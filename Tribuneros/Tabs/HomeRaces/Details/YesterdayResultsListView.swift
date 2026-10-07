//
//  YesterdayResultsListView.swift
//  Tribuneros
//

import SwiftUI

struct YesterdayResultsListView: View {
    let races: [HomeRaces.Representable.RaceFinished]
    let isSpoilerModeOn: Bool
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        HomeListScreen {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    TribuneruText(
                        content: "Results yesterday",
                        style: .vaporSectionTitle,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 2)
                }
                YesterdayResultsCard(
                    races: races,
                    visibility: isSpoilerModeOn ? .shown : .hidden,
                    identifierPrefix: "yesterdayResults",
                    open: { race in action(.openRaceResult(race)) },
                    toggle: { action(.spoilerModeResultYesterday) }
                )
                .spoilerCrossfade(isSpoilerModeOn)
            }
        }
    }
}
