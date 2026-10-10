//
//  TodayRacesListView.swift
//  Tribuneros
//

import SwiftUI

struct TodayRacesListView: View {
    let races: [HomeRaces.Representable.RaceNext]
    let action: (HomeRaces.Action) -> Void

    private var liveCount: Int {
        races.filter(\.isLive).count
    }

    var body: some View {
        HomeListScreen {
            VStack(alignment: .leading, spacing: 18) {
                heading
                LazyVStack(spacing: 12) {
                    ForEach(Array(races.enumerated()), id: \.element.id) { index, race in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if race.isLive {
                                action(.navigate(.liveRace(index: index)))
                            } else {
                                action(.navigate(.nextToFinishRace(index: index)))
                            }
                        } label: {
                            TodayRaceRow(race: race)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("todayRaces.row.\(index)")
                    }
                }
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: "Today's races",
                style: .vaporSectionTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            .accessibilityAddTraits(.isHeader)
            HStack(spacing: 8) {
                if liveCount > 0 {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.tribuneru(.vaporLiveRed))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.tribuneru(.vaporLiveRed).opacity(0.25), lineWidth: 3)
                            )
                        TribuneruText(
                            content: "\(liveCount) live",
                            style: .vaporHeroSubtitle,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 1
                        )
                    }
                    separator
                }
                TribuneruText(
                    content: summary,
                    style: .vaporBannerSubtitle,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("todayRaces.summary")
        }
        .padding(.horizontal, 2)
    }

    private var separator: some View {
        TribuneruText(
            content: "·",
            style: .vaporBannerSubtitle,
            color: .tribuneru(.vaporTextSecondary),
            lineLimit: 1
        )
    }

    private var summary: String {
        let later = races.count - liveCount
        return later > 0 ? "\(later) later today · by finish time" : "by finish time"
    }
}

struct TodayRaceRow: View {
    private enum Sizes {
        static let artSide: CGFloat = 96
    }

    let race: HomeRaces.Representable.RaceNext

    var body: some View {
        TimelineView(.everyMinute) { context in
            row(now: context.date)
        }
    }

    private func row(now: Date) -> some View {
        let isFinished = race.isFinished(now: now)
        return HStack(spacing: 14) {
            RaceArtView.fallback
                .frame(width: Sizes.artSide, height: Sizes.artSide)
                .overlay(alignment: .topLeading) {
                    RaceStatusTag(
                        kind: isFinished ? .finished : race.statusKind,
                        size: .small
                    )
                    .padding(6)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                TribuneruText(
                    content: race.title,
                    style: .vaporRowTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
                HStack(spacing: 6) {
                    VaporFlagView(countryCode: race.flagCode)
                    TribuneruText(
                        content: metaText,
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TribuneruText(
                        content: race.eta,
                        style: .vaporRowTime,
                        color: .tribuneru(.vaporTextPrimary)
                    )
                    TribuneruText(
                        content: "ETA",
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary)
                    )
                    Spacer(minLength: 0)
                    remaining(now: now)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporTextSecondary))
        }
        .padding(12)
        .homeCard(cornerRadius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFinished ? race.accessibilityDescription + ", finished" : race.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func remaining(now: Date) -> some View {
        if let remaining = race.remainingTimeDescription(now: now) {
            TribuneruText(
                content: "\(remaining) left",
                style: .vaporRowCountdown,
                color: race.isLive
                    ? Color.tribuneru(.vaporAccent)
                    : Color.tribuneru(.vaporTextPrimary).opacity(0.55),
                lineLimit: 1
            )
        }
    }

    private var metaText: String {
        [race.subtitle, race.category, race.raceType]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

}
