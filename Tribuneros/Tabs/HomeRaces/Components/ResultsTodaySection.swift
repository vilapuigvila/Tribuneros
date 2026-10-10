//
//  ResultsTodaySection.swift
//  Tribuneros
//

import SwiftUI

struct ResultsTodaySection: View {
    let races: [HomeRaces.Representable.RaceFinished]
    var firstFinishExpected: String?
    var isHintAnchor = false
    let action: (HomeRaces.Action) -> Void

    var body: some View {
        HomeSection(title: L10n.tr("Results today")) {
            if races.isEmpty {
                ResultsAwaitingCard(firstFinishExpected: firstFinishExpected)
            } else {
                cards
            }
        }
    }

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(races.enumerated()), id: \.offset) { index, race in
                    ResultHighlightCard(
                        race: race,
                        visibility: race.visibility
                    )
                    .accessibilityIdentifier("home.results.\(race.visibility == .placeholder ? "placeholder" : "card").\(index)")
                    .spoilerHintAnchor(isHintAnchor && index == 0)
                    .spoilerArt(
                        race.visibility,
                        size: CGSize(width: 180, height: 112),
                        alignment: .top,
                        identifier: "home.results.spoilerArt.\(index)"
                    )
                    .resultGestures(
                        race.visibility,
                        open: { action(.openRaceResult(race)) },
                        toggle: { action(.toggleReveal(race)) }
                    )
                    .spoilerCrossfade(race.visibility)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .padding(.horizontal, -16)
    }
}

/// Results today before the first finish: the empty podium painting, full width, with the expected time.
struct ResultsAwaitingCard: View {
    private static let bands: [Color.Palette] = [
        .championBlue,
        .championRed,
        .championBlack,
        .championYellow,
        .championGreen
    ]

    var firstFinishExpected: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var labelColor: Color.Palette = .vaporTextPrimary
    @State private var hasPlayedBands = false

    var body: some View {
        RaceArtView(
            art: .emptyPodium,
            alignment: .top
        )
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .overlay(alignment: .bottom) {
            if let firstFinishExpected {
                label(firstFinishExpected)
            }
        }
        .homeCard(cornerRadius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("home.results.empty")
    }

    private var accessibilityText: String {
        guard let firstFinishExpected else { return L10n.tr("No results yet") }
        return L10n.tr("No results yet, first finish expected %@", firstFinishExpected)
    }

    private func label(_ time: String) -> some View {
        TribuneruText(
            content: L10n.tr("First finish expected %@", time),
            style: .vaporAwaitingLabel,
            color: .tribuneru(labelColor),
            lineLimit: 1
        )
        .contentTransition(.interpolate)
        .opacity(0.8)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.tribuneru(.vaporPageBackground).opacity(0.6))
        .task { await playBands() }
    }

    /// One pass through the jersey's bands: 1s fade into each, held 2s, then back to the usual color.
    private func playBands() async {
        guard !hasPlayedBands, !reduceMotion else { return }
        hasPlayedBands = true
        for band in Self.bands {
            withAnimation(.easeInOut(duration: 1)) { labelColor = band }
            guard (try? await Task.sleep(for: .seconds(3))) != nil else {
                labelColor = .vaporTextPrimary
                return
            }
        }
        withAnimation(.easeInOut(duration: 1)) { labelColor = .vaporTextPrimary }
    }
}

/// A section with nothing to list yet; same footprint as one of its result cards, no gestures.
struct ResultsEmptyCard: View {
    let title: String
    var subtitle: String?
    let size: CGSize
    let identifier: String
    var isFullWidth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: title,
                style: .vaporResultTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            if let subtitle {
                TribuneruText(
                    content: subtitle,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }
        }
        .padding(16)
        .frame(
            maxWidth: isFullWidth ? .infinity : size.width,
            minHeight: size.height,
            maxHeight: size.height,
            alignment: .leading
        )
        .homeCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

struct ResultHighlightCard: View {
    private enum Sizes {
        static let width: CGFloat = 180
        static let photoHeight: CGFloat = 112
        static let cornerRadius: CGFloat = 16
    }

    let race: HomeRaces.Representable.RaceFinished
    var visibility: HomeRaces.ResultVisibility = .shown

    var body: some View {
        card
    }

    private var shownRace: HomeRaces.Representable.RaceFinished {
        race.shown(visibility)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            WinnerPhoto(
                url: shownRace.winnerImgURL,
                size: CGSize(width: Sizes.width, height: Sizes.photoHeight),
                isHiddenBySpoiler: visibility == .hidden
            )
            details
        }
        .frame(width: Sizes.width, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.tribuneru(.vaporCardSurface))
        .clipShape(RoundedRectangle(cornerRadius: Sizes.cornerRadius))
        .accessibilityElement(children: .combine)
        .redactedResult(
            visibility,
            title: race.race
        )
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: shownRace.race,
                style: .vaporRaceNameResult,
                color: Color.tribuneru(.vaporTextPrimary).opacity(0.72),
                lineLimit: 2
            )
            .unredacted(if: visibility == .hidden)
            if !shownRace.raceDetails.isEmpty {
                TribuneruText(
                    content: shownRace.raceDetails,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
            }
            if let winner = shownRace.winner {
                HStack(spacing: 6) {
                    VaporFlagView(countryCode: winner.countryCode)
                    TribuneruText(
                        content: winner.name,
                        style: .vaporWinnerName,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                }
                if !winner.time.isEmpty {
                    TribuneruText(
                        content: winner.time,
                        style: .vaporFinishTime,
                        color: Color.tribuneru(.vaporTextPrimary).opacity(0.6)
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}
