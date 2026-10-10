//
//  PreviewsSection.swift
//  Tribuneros
//

import SwiftUI

struct PreviewsSection: View {
    let previews: [HomeRaces.Representable.RacePreview]
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        HomeSection(title: L10n.tr("Previews")) {
            RacePreviewsCard(
                previews: previews,
                open: { action(.openRacePreview($0)) }
            )
        }
    }
}

struct RacePreviewsCard: View {
    let previews: [HomeRaces.Representable.RacePreview]
    let open: (HomeRaces.Representable.RacePreview) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(previews.enumerated()), id: \.offset) { index, preview in
                if index > 0 {
                    TribunerosDivider(
                        height: 0.5,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.08)
                    )
                }
                Button {
                    open(preview)
                } label: {
                    row(preview)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.previews.row.\(index)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .homeCard()
    }

    private func row(_ preview: HomeRaces.Representable.RacePreview) -> some View {
        HStack(spacing: 14) {
            TribuneruText(
                content: preview.countdown,
                style: .vaporRowCountdown,
                color: .tribuneru(.vaporAccent),
                lineLimit: 1
            )
            .frame(
                minWidth: 40,
                alignment: .leading
            )
            TribuneruText(
                content: preview.name,
                style: .vaporResultTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporTextSecondary))
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
