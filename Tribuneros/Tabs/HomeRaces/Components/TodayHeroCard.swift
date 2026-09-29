//
//  TodayHeroCard.swift
//  Tribuneros
//
//  The "Today" section: the first race of the day as one big card, or a resting scene when
//  the day has no races. "See all" opens the whole list once there is more than one.
//

import SwiftUI

struct TodaySection: View {
    let races: [HomeRaces.Representable.RaceNext]
    let action: (HomeRaces.Action) -> Void

    private var seeAll: (() -> Void)? {
        guard races.count > 1 else { return nil }
        return { action(.navigate(.todayRaces)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(
                title: "Today",
                seeAll: seeAll,
                seeAllIdentifier: "home.today.seeAll"
            )
            if let race = races.first {
                TodayHeroCard(race: race) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    action(.navigate(.nextToFinishRace(index: 0)))
                }
            } else {
                TodayEmptyCard()
            }
        }
    }
}

struct TodayHeroCard: View {
    private enum Sizes {
        static let artHeight: CGFloat = 232
        static let cornerRadius: CGFloat = 20
    }

    let race: HomeRaces.Representable.RaceNext
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                art
                stats
            }
            .homeCard(cornerRadius: Sizes.cornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.today.hero")
    }

    private var art: some View {
        ZStack {
            RaceArtView(art: .day)
            LinearGradient(
                colors: [Color.tribuneru(.vaporPageBackground).opacity(0.5), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.3)
            )
            LinearGradient(
                colors: [Color.tribuneru(.vaporPageBackground).opacity(0.78), .clear],
                startPoint: .bottom,
                endPoint: UnitPoint(x: 0.5, y: 0.54)
            )
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
            .shadow(color: Color.tribuneru(.black).opacity(0.5), radius: 7, x: 0, y: 1)
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
            HStack(spacing: 8) {
                statIcon("clock")
                TribuneruText(
                    content: race.eta,
                    style: .vaporStatTime,
                    color: .tribuneru(.vaporTextPrimary)
                )
                TribuneruText(
                    content: "ETA",
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary)
                )
            }
            Spacer(minLength: 8)
            if !race.raceType.isEmpty {
                statValue(icon: "trophy", value: race.raceType)
                Spacer(minLength: 8)
            }
            if !race.category.isEmpty {
                statValue(icon: "person", value: race.category)
                Spacer(minLength: 8)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporTextSecondary))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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

    private var accessibilityText: String {
        var parts = [
            race.title,
            race.stageLabel ?? "one-day race",
            race.isLive ? "live now" : "later today",
            "expected finish \(race.eta)"
        ]
        if let remaining = race.remainingTimeDescription() {
            parts.append("in \(remaining)")
        }
        return parts.joined(separator: ", ")
    }
}

/// The "in 2h 14m" capsule on a race image, kept current by the minute. Absent once the ETA passed.
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
    var body: some View {
        ZStack {
            RaceArtView(art: .night)
            EllipticalGradient(
                colors: [Color.tribuneru(.vaporAccent).opacity(0.10), .clear],
                center: UnitPoint(x: 0.24, y: 0.32),
                startRadiusFraction: 0,
                endRadiusFraction: 0.7
            )
            LinearGradient(
                colors: [Color.tribuneru(.vaporPageBackground).opacity(0.4), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.28)
            )
            LinearGradient(
                colors: [Color.tribuneru(.vaporPageBackground).opacity(0.7), .clear],
                startPoint: .bottom,
                endPoint: UnitPoint(x: 0.5, y: 0.42)
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
                    .shadow(color: Color.tribuneru(.black).opacity(0.5), radius: 7, x: 0, y: 1)
                    TribuneruText(
                        content: "Nothing on today's list yet. New races show up here as soon as they're listed.",
                        style: .vaporBannerSubtitle,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.8),
                        lineLimit: 3
                    )
                    .frame(maxWidth: 270, alignment: .leading)
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .frame(height: 282)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.tribuneru(.vaporTextPrimary).opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.today.empty")
    }
}
