//
//  VaporRaceCards.swift
//  Tribuneros
//
//  The 2-column grid cards used inside `VaporSectionPanel` on the Home
//  screen. See `agent-doc/home_redesign_spec.md` §5 for what each card shows.
//

import SwiftUI

/// Card shape shared by all three — a rounded `cardSurface` box with 12pt
/// padding and 10pt internal spacing.
private struct VaporCard<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tribuneru(.vaporCardSurface))
        .cornerRadius(8)
    }
}

// MARK: - LiveStats -

struct VaporLiveStatsCard: View {
    let race: HomeRaces.Representable.LiveRace

    var body: some View {
        VaporCard {
            LiveBadge()

            TribuneruText(
                content: race.raceName,
                style: .vaporRaceNameNext,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )

            if let ridersCount = race.ridersCount {
                TribuneruText(
                    content: "\(ridersCount) riders",
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary)
                )
            }
        }
    }
}

/// The small "LIVE" pill shown on a `VaporLiveStatsCard`. Not the same as the
/// 6×6 dot `VaporSectionHeader(showsLiveDot:)` puts beside a section title —
/// that marks the whole section, this marks one race within it.
private struct LiveBadge: View {
    var body: some View {
        TribuneruText(
            content: "LIVE",
            style: .vaporSpoilerChip,
            color: .tribuneru(.vaporLive)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.tribuneru(.vaporLive).opacity(0.16))
        .cornerRadius(4)
    }
}

// MARK: - Next to finish -

struct VaporNextToFinishCard: View {
    let race: HomeRaces.Representable.RaceNext

    var body: some View {
        VaporCard {
            HStack(alignment: .top, spacing: 8) {
                VaporFlagView(countryCode: race.flagCode)
                    .padding(.top, 2)
                TribuneruText(
                    content: race.name,
                    style: .vaporRaceNameNext,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 2
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TribuneruText(
                    content: race.eta,
                    style: .vaporETANext,
                    color: .tribuneru(.vaporTextPrimary)
                )
                Spacer(minLength: 6)
                if let remaining = race.remainingTimeDescription {
                    TribuneruText(
                        content: remaining,
                        style: .vaporCountdown,
                        color: .tribuneru(.vaporAccent)
                    )
                }
            }

            TribuneruText(
                content: metaText,
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
        }
    }

    /// "165 km · 1.1" — built from what `RaceNext` actually carries.
    /// (The mockup's "Stage 7" / "One-day race" prefix was decorative sample
    /// copy; the model has no field for it.)
    private var metaText: String {
        [race.distance.isEmpty ? nil : "\(race.distance) km", race.raceType]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

extension HomeRaces.Representable.RaceNext {
    /// A short "time until finish" label derived from `eta` (a wall-clock
    /// "HH:mm" string), or `nil` if it can't be parsed or has already passed.
    /// Presentation-only — there is no live race clock elsewhere in the app.
    var remainingTimeDescription: String? {
        let parser = DateFormatter()
        parser.dateFormat = "HH:mm"
        parser.timeZone = .current
        guard let etaTimeOnly = parser.date(from: eta) else { return nil }

        let calendar = Calendar.current
        let now = Date()
        var todayAtEta = calendar.dateComponents([.year, .month, .day], from: now)
        let etaComponents = calendar.dateComponents([.hour, .minute], from: etaTimeOnly)
        todayAtEta.hour = etaComponents.hour
        todayAtEta.minute = etaComponents.minute
        guard let etaDate = calendar.date(from: todayAtEta) else { return nil }

        let secondsRemaining = etaDate.timeIntervalSince(now)
        guard secondsRemaining > 0 else { return nil }

        let totalMinutes = Int(secondsRemaining / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Results (today / yesterday) -

struct VaporResultCard: View {
    let race: HomeRaces.Representable.RaceFinished

    private var winner: HomeRaces.Representable.RaceFinished.Winner? {
        race.podium.first
    }

    var body: some View {
        VaporCard {
            HStack(alignment: .top, spacing: 8) {
                if let winner {
                    VaporFlagView(countryCode: winner.countryCode)
                        .padding(.top, 2)
                }
                TribuneruText(
                    content: metaText,
                    style: .vaporRaceNameResult,
                    color: .tribuneru(.vaporTextPrimary).opacity(0.72),
                    lineLimit: 2
                )
            }

            TribuneruText(
                content: winner?.name ?? race.race,
                style: .vaporWinnerName,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )

            if let time = winner?.time, !time.isEmpty {
                TribuneruText(
                    content: time,
                    style: .vaporFinishTime,
                    color: .tribuneru(.vaporTextPrimary).opacity(0.6)
                )
            }
        }
    }

    private var metaText: String {
        race.raceDetails.isEmpty ? race.race : "\(race.race) · \(race.raceDetails)"
    }
}

// MARK: - Races tomorrow -

struct VaporTomorrowCard: View {
    let race: HomeRaces.Representable.RaceTomorrow

    var body: some View {
        VaporCard(spacing: 8) {
            TribuneruText(
                content: race.start,
                style: .vaporStartTimeTomorrow,
                color: .tribuneru(.vaporTextPrimary)
            )
            TribuneruText(
                content: race.name,
                style: .vaporRaceNameTomorrow,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            if !race.eta.isEmpty {
                TribuneruText(
                    content: "ETA \(race.eta)",
                    style: .vaporETALine,
                    color: .tribuneru(.vaporTextSecondary)
                )
            }
        }
    }
}

#if DEBUG
#Preview("Vapor cards") {
    ZStack {
        Color.tribuneru(.vaporPanelRacing).ignoresSafeArea()
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            VaporLiveStatsCard(race: .init(
                status: "live", isLive: true, raceName: "World Championships MU - ITT",
                ridersCount: 63, racePath: "race/world-championships-itt-u23/2026/result/live",
                url: nil
            ))
            VaporNextToFinishCard(race: .init(
                eta: "16:58", duration: "6H 48M", name: "Milano–Sanremo",
                category: "UCI", raceType: "1.UWT", distance: "288",
                urlPath: nil, flagCode: "it"
            ))
            VaporTomorrowCard(race: .init(start: "10:45", eta: "15:30", name: "Coppi e Bartali · Stage 4", url: nil))
        }
        .padding(20)
    }
    .preferredColorScheme(.dark)
}
#endif
