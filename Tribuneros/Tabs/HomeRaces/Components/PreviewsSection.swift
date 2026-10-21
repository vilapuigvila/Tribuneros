//
//  PreviewsSection.swift
//  Tribuneros
//

import SwiftUI

/// The first preview floating over the bottom of the page; "+N" opens every preview.
struct PreviewsFloatingCard: View {
    let previews: [HomeRaces.Representable.RacePreview]
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        if let preview = previews.first {
            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action(.openRacePreview(preview))
                } label: {
                    HStack(spacing: 12) {
                        thumbnail(preview)
                        VStack(alignment: .leading, spacing: 3) {
                            TribuneruText(
                                content: L10n.tr("PREVIEW"),
                                style: .vaporTagSmall,
                                color: .tribuneru(.vaporPageBackground),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: preview.name,
                                style: .vaporResultTitle,
                                color: .tribuneru(.vaporPageBackground),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: L10n.tr("in %@", preview.countdown),
                                style: .vaporRowMeta,
                                color: .tribuneru(.vaporPageBackground),
                                lineLimit: 1
                            )
                        }
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                    }
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.previews.card")
                if previews.count > 1 {
                    moreButton(count: previews.count - 1)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .frame(height: 72)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.tribuneru(.vaporAccent))
            )
            .opacity(0.9)
        }
    }

    private func thumbnail(_ preview: HomeRaces.Representable.RacePreview) -> some View {
        ZStack {
            Color.tribuneru(.vaporPageBackground)
            TribuneruText(
                content: preview.countdown,
                style: .vaporRowCountdown,
                color: .tribuneru(.vaporAccent),
                lineLimit: 1
            )
        }
        .frame(
            width: 52,
            height: 52
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(
                    Color.tribuneru(.vaporPageBackground),
                    lineWidth: 2
                )
        )
    }

    private func moreButton(count: Int) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action(.navigate(.previews))
        } label: {
            TribuneruText(
                content: L10n.tr("+%lld", count),
                style: .vaporSeeAll,
                color: .tribuneru(.vaporPageBackground),
                lineLimit: 1
            )
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                Capsule().fill(Color.tribuneru(.vaporPageBackground).opacity(0.18))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.previews.more")
    }
}

struct RacePreviewsCard: View {
    let previews: [HomeRaces.Representable.RacePreview]
    var identifierPrefix = "home.previews"
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
                .accessibilityIdentifier("\(identifierPrefix).row.\(index)")
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
