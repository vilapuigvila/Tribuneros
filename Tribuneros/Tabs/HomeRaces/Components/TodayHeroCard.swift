//
//  TodayHeroCard.swift
//  Tribuneros
//

import SwiftUI

struct TodaySection: View {
    let races: [HomeRaces.Representable.RaceNext]
    var isCompact = false
    let action: (HomeRaces.Action) -> Void

    private var seeAll: (() -> Void)? {
        guard races.count > 1 else { return nil }
        return { action(.navigate(.todayRaces)) }
    }

    var body: some View {
        HomeSection(
            title: "Today",
            seeAll: seeAll,
            seeAllIdentifier: "home.today.seeAll"
        ) {
            if let race = races.first {
                TodayHeroCard(race: race) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action(.navigate(.nextToFinishRace(index: 0)))
                }
            } else {
                TodayEmptyCard(isCompact: isCompact)
            }
        }
    }
}

struct TodayHeroCard: View {
    private enum Sizes {
        static let artHeight: CGFloat = 232
    }

    let race: HomeRaces.Representable.RaceNext
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                art
                stats
            }
            .homeCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(race.accessibilityDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.today.hero")
    }

    private var art: some View {
        ZStack {
            RaceArtView(art: .day)
            ImageScrim()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    RaceStatusTag(kind: race.statusKind)
                    Spacer(minLength: 0)
                    RemainingPill(race: race)
                }
                Spacer(minLength: 0)
                titleBlock
            }
            .padding(14)
        }
        .frame(height: Sizes.artHeight)
        .clipped()
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: race.title,
                style: .vaporHeroTitle,
                color: .tribuneru(.white(level: 1)),
                lineLimit: 2
            )
            .artTitleShadow()
            HStack(spacing: 8) {
                VaporFlagView(countryCode: race.flagCode)
                TribuneruText(
                    content: race.subtitle,
                    style: .vaporHeroSubtitle,
                    color: Color.tribuneru(.vaporTextPrimary).opacity(0.88),
                    lineLimit: 1
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private var stats: some View {
        HStack(spacing: 8) {
            if let startTime = race.startTime {
                statTime(
                    icon: "clock",
                    time: startTime,
                    label: "START"
                )
                Spacer(minLength: 8)
            }
            statTime(
                icon: "flag.checkered",
                time: race.eta,
                label: "ETA"
            )
            Spacer(minLength: 8)
            if !race.raceType.isEmpty {
                statValue(icon: "trophy", value: race.raceType)
                Spacer(minLength: 8)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporTextSecondary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func statTime(
        icon: String,
        time: String,
        label: String
    ) -> some View {
        HStack(spacing: 8) {
            statIcon(icon)
            TribuneruText(
                content: time,
                style: .vaporStatTime,
                color: .tribuneru(.vaporTextPrimary)
            )
            TribuneruText(
                content: label,
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary)
            )
        }
    }

    private func statValue(icon: String, value: String) -> some View {
        HStack(spacing: 8) {
            statIcon(icon)
            TribuneruText(
                content: value,
                style: .vaporRaceNameNext,
                color: .tribuneru(.vaporTextPrimary)
            )
        }
    }

    private func statIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.tribuneru(.vaporTextSecondary))
    }
}

struct RemainingPill: View {
    let race: HomeRaces.Representable.RaceNext

    var body: some View {
        TimelineView(.everyMinute) { context in
            if let remaining = race.remainingTimeDescription(now: context.date) {
                TribuneruText(
                    content: "in \(remaining)",
                    style: .vaporPill,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.tribuneru(.vaporPageBackground).opacity(0.62))
                )
            }
        }
    }
}

struct TodayEmptyCard: View {
    var isCompact = false

    var body: some View {
        ZStack {
            RaceArtView(art: .night)
            EllipticalGradient(
                colors: [Color.tribuneru(.vaporAccent).opacity(0.10), .clear],
                center: UnitPoint(x: 0.24, y: 0.32),
                startRadiusFraction: 0,
                endRadiusFraction: 0.7
            )
            ImageScrim(
                top: 0.4,
                topEnd: 0.28,
                bottom: 0.7,
                bottomEnd: 0.42
            )
            VStack(alignment: .leading, spacing: 0) {
                RaceStatusTag(kind: .noRaces)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 6) {
                    TribuneruText(
                        content: "The peloton is resting",
                        style: .vaporHeroTitle,
                        color: .tribuneru(.white(level: 1)),
                        lineLimit: 2
                    )
                    .artTitleShadow()
                    TribuneruText(
                        content: "Nothing on today's list yet. New races show up here as soon as they're listed.",
                        style: .vaporBannerSubtitle,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.8),
                        lineLimit: isCompact ? 2 : 3
                    )
                    .frame(maxWidth: 270, alignment: .leading)
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .frame(height: isCompact ? 141 : 282)
        .homeCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.today.empty")
    }
}
