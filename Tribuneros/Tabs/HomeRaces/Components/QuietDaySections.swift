//
//  QuietDaySections.swift
//  Tribuneros
//

import SwiftUI

/// The Today Races page when nothing races or finished today or yesterday: a short notice, the latest
/// History result as a hero, then the next few under "Earlier".
struct QuietDaySections: View {
    static let earlierLimit = 5

    let history: [HomeRaces.Representable.RaceFinished]
    let action: (HomeRaces.Action) -> Void

    private var earlier: ArraySlice<HomeRaces.Representable.RaceFinished> {
        history.dropFirst().prefix(Self.earlierLimit)
    }

    private var seeAll: (() -> Void)? {
        guard history.count > Self.earlierLimit + 1 else { return nil }
        return { action(.navigate(.historyResults)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            QuietDayNotice()

            if let latest = history.first {
                HomeSection(title: L10n.tr("Latest finish")) {
                    LatestFinishCard(race: latest) {
                        action(.openRaceResult(latest))
                    }
                }
            }

            if !earlier.isEmpty {
                HomeSection(
                    title: L10n.tr("Earlier"),
                    seeAll: seeAll,
                    seeAllIdentifier: "home.earlier.seeAll"
                ) {
                    VStack(spacing: 12) {
                        ForEach(Array(earlier.enumerated()), id: \.element.id) { index, race in
                            HistoryRaceRow(race: race) {
                                action(.openRaceResult(race))
                            }
                            .accessibilityIdentifier("home.earlier.row.\(index)")
                        }
                    }
                }
            }
        }
    }
}

struct QuietDayNotice: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.tribuneru(.vaporTextSecondary))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                TribuneruText(
                    content: L10n.tr("No racing today"),
                    style: .vaporRowTitle,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                TribuneruText(
                    content: L10n.tr("Nothing finished yesterday either. Here is the latest."),
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .homeCard(cornerRadius: 14)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.quiet.notice")
    }
}

/// The newest History result as a hero: the day painting (History has no winner photos), date, race and winner.
struct LatestFinishCard: View {
    let race: HomeRaces.Representable.RaceFinished
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                art
                details
            }
            .homeCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.latest.hero")
    }

    private var art: some View {
        ZStack(alignment: .topLeading) {
            RaceArtView(art: .day)
            ImageScrim(
                top: 0.4,
                topEnd: 0.3,
                bottom: 0,
                bottomEnd: 1
            )
            if !race.raceDetails.isEmpty {
                TribuneruText(
                    content: race.raceDetails.uppercased(with: L10n.locale),
                    style: .vaporTag,
                    color: .tribuneru(.vaporTagNeutralText),
                    lineLimit: 1
                )
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Color.tribuneru(.vaporTagNeutral).opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .padding(14)
            }
        }
        .frame(height: 170)
        .clipped()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if !race.raceCountryCode.isEmpty {
                    VaporFlagView(countryCode: race.raceCountryCode)
                }
                TribuneruText(
                    content: race.race,
                    style: .vaporHeroTitle,
                    color: .tribuneru(.white(level: 1)),
                    lineLimit: 2
                )
            }
            if let winner = race.winner {
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.tribuneru(.vaporAccent))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        TribuneruText(
                            content: winner.name,
                            style: .vaporResultTitle,
                            color: .tribuneru(.white(level: 1)),
                            lineLimit: 1
                        )
                        TribuneruText(
                            content: L10n.tr("Winner"),
                            style: .vaporRowMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
}

#if DEBUG
#Preview("Quiet day") {
    ScrollView {
        QuietDaySections(
            history: HomeRaces.Representable.placeholderResults.map {
                var race = $0
                race.visibility = .shown
                return race
            }
        ) { _ in }
        .padding(16)
    }
    .background(Color.tribuneru(.vaporPageBackground))
    .preferredColorScheme(.dark)
}
#endif
