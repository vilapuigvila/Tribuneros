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
                FoldingContent(isShown: isSpoilerModeOn) {
                    YesterdayResultsCard(
                        races: races,
                        identifierPrefix: "yesterdayResults"
                    ) { url in
                        action(.openLink(url))
                    }
                }
            }
        }
    }
}
