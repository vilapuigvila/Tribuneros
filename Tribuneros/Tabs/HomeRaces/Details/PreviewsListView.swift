//
//  PreviewsListView.swift
//  Tribuneros
//

import SwiftUI

struct PreviewsListView: View {
    let previews: [HomeRaces.Representable.RacePreview]
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        HomeListScreen {
            VStack(alignment: .leading, spacing: 6) {
                TribuneruText(
                    content: L10n.tr("Previews"),
                    style: .vaporSectionTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("previews.title")
                .padding(.horizontal, 2)
                RacePreviewsCard(
                    previews: previews,
                    identifierPrefix: "previews",
                    open: { action(.openRacePreview($0)) }
                )
            }
        }
    }
}
