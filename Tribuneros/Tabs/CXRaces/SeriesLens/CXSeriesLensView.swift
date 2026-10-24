//
//  CXSeriesLensView.swift
//  Tribuneros
//

import SwiftUI

extension View {
    func mudCard(cornerRadius: CGFloat = 20) -> some View {
        background(Color.tribuneru(.mudCardSurface))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        Color.tribuneru(.mudTextPrimary).opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

extension CXRaces {

    /// The CX Zone page: a series picker, then that series' next round, leaders, last round
    /// and the rounds still to come.
    struct SeriesLensView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets
        @Environment(\.tabBarHeight) private var tabBarHeight
        @Binding var selectedSeries: RaceSeries?
        @Binding var flippedRaces: Set<String>

        let representable: Representable
        let action: (CXRaces.Action) -> Void

        private var availableSeries: [RaceSeries] {
            SeriesLens.availableSeries(in: representable.calendarEvents)
        }

        private var series: RaceSeries? {
            guard let selectedSeries, availableSeries.contains(selectedSeries) else {
                return availableSeries.first
            }
            return selectedSeries
        }

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    if let series {
                        let lens = SeriesLens(
                            series: series,
                            representable: representable
                        )
                        NextRoundSection(
                            lens: lens,
                            open: { action(.didTapOnCalendarEvent($0)) }
                        )
                        if !lens.leaders.isEmpty {
                            LeadersSection(
                                leaders: lens.leaders,
                                openRider: { action(.didTapOnStandingRider($0)) },
                                openStandings: { action(.didTapOnStandings) }
                            )
                        }
                        if let lastRound = lens.lastRound {
                            LastRoundSection(
                                round: lastRound,
                                podium: lens.lastPodium,
                                openEvent: { action(.didTapOnCalendarEvent($0)) },
                                openRider: { action(.didTapOnPodiumRider($0)) },
                                openResults: { action(.didTapOnLatestResults) }
                            )
                        }
                        if !lens.roundsLeft.isEmpty {
                            RoundsLeftSection(
                                rounds: lens.roundsLeft,
                                open: { action(.didTapOnCalendarEvent($0)) },
                                openCalendar: { action(.didTapOnNextRaces(series: series)) }
                            )
                        }
                    } else {
                        EmptyCalendarCard()
                    }
                    Color.clear
                        .frame(height: safeAreaInsets.bottom * 3 + 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.tribuneru(.mudPageBackground))
            .overlay {
                if let latest = SeriesLens.latestRace(in: representable.races) {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        LatestResultCard(
                            race: latest,
                            winner: SeriesLens.winner(of: latest),
                            otherCount: SeriesLens.otherLatestResultCount(in: representable.races),
                            isShown: CXRaces.resultVisibility(of: latest, flipped: flippedRaces) == .shown,
                            toggle: { CXRaces.flip(latest, in: &flippedRaces) },
                            openAll: { action(.didTapOnLatestResults) }
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, safeAreaInsets.bottom + tabBarHeight + 8)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundColor(.tribuneru(.mudTextPrimary))
                        TribuneruText(
                            content: L10n.tr("CX Zone"),
                            style: .vaporSectionTitle,
                            color: .tribuneru(.mudTextPrimary),
                            lineLimit: 1
                        )
                    }
                    Spacer(minLength: 0)
                    TribuneruText(
                        content: L10n.tr("Season %@", SeriesLens.seasonLabel()),
                        style: .vaporScreenDate,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("cx.header")

                if availableSeries.count > 1 {
                    chips
                }
            }
            .padding(.top, 16)
        }

        private var chips: some View {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableSeries) { chip in
                            let isSelected = chip == series
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedSeries = chip
                            } label: {
                                TribuneruText(
                                    content: chip.title,
                                    style: .vaporLink,
                                    color: .tribuneru(isSelected ? .mudAccent : .mudTextMuted),
                                    lineLimit: 1
                                )
                                .padding(.horizontal, 16)
                                .frame(minHeight: 40)
                                .background(
                                    Capsule().fill(
                                        isSelected
                                            ? Color.tribuneru(.mudAccent).opacity(0.14)
                                            : Color.tribuneru(.mudCardSurface)
                                    )
                                )
                                .overlay(
                                    Capsule().strokeBorder(
                                        isSelected
                                            ? Color.tribuneru(.mudAccent).opacity(0.4)
                                            : Color.tribuneru(.mudTextPrimary).opacity(0.08),
                                        lineWidth: 1
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                            .accessibilityIdentifier("cx.series.\(chip.rawValue)")
                            .id(chip.id)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onAppear {
                    // Wait one runloop so the chips are laid out before centering.
                    DispatchQueue.main.async {
                        proxy.scrollTo(series?.id, anchor: .center)
                    }
                }
                .onChange(of: series) {
                    withAnimation {
                        proxy.scrollTo(series?.id, anchor: .center)
                    }
                }
            }
            .padding(.horizontal, -16)
            .accessibilityLabel(L10n.tr("Series"))
        }
    }
}

// MARK: - Section scaffolding -

private struct MudSection<Content: View>: View {
    let title: String
    let pillTitle: String
    var pillIdentifier: String = ""
    let pillAction: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                TribuneruText(
                    content: title,
                    style: .vaporHeading,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 1
                )
                Spacer(minLength: 0)
                Button(action: pillAction) {
                    HStack(spacing: 4) {
                        TribuneruText(
                            content: pillTitle,
                            style: .vaporSeeAll,
                            color: .tribuneru(.mudAccent),
                            lineLimit: 1
                        )
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.tribuneru(.mudAccent))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.tribuneru(.mudAccent).opacity(0.14))
                    )
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(pillIdentifier)
            }
            .frame(minHeight: 44)
            content()
        }
    }
}

private struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.tribuneru(.mudTextSecondary))
    }
}

// MARK: - Next round -

private struct NextRoundSection: View {
    let lens: CXRaces.SeriesLens
    let open: (DTO.CXCalendarEvent) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let round = lens.nextRound {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    open(round.event)
                } label: {
                    hero(
                        series: lens.series,
                        tag: L10n.tr("NEXT ROUND"),
                        pill: countdown(to: round),
                        title: round.event.race,
                        subtitle: subtitle(of: round)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cx.nextRound")
            } else {
                hero(
                    series: lens.series,
                    tag: L10n.tr("Finished"),
                    pill: nil,
                    title: L10n.tr("Season finished"),
                    subtitle: L10n.tr("No more rounds in this series this season.")
                )
            }
            progress
        }
        .mudCard()
    }

    private func hero(
        series: CXRaces.RaceSeries,
        tag: String,
        pill: String?,
        title: String,
        subtitle: String
    ) -> some View {
        ZStack {
            CXSeriesArt(series: series)
            ImageScrim(
                top: 0.5,
                topEnd: 0.34,
                bottom: 0.8,
                bottomEnd: 0.46,
                tint: .tribuneru(.mudPageBackground)
            )
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    MudTag(title: tag)
                    Spacer(minLength: 0)
                    if let pill {
                        TribuneruText(
                            content: pill,
                            style: .vaporPill,
                            color: .tribuneru(.mudTextPrimary),
                            lineLimit: 1
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.tribuneru(.mudPageBackground).opacity(0.62))
                        )
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: title,
                        style: .vaporHeroTitle,
                        color: .tribuneru(.white(level: 1)),
                        lineLimit: 2
                    )
                    .artTitleShadow()
                    TribuneruText(
                        content: subtitle,
                        style: .vaporHeroSubtitle,
                        color: Color.tribuneru(.mudTextPrimary).opacity(0.88),
                        lineLimit: 1
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
            }
            .padding(14)
        }
        .frame(height: 196)
        .clipped()
        .accessibilityElement(children: .combine)
    }

    private var segmentSpacing: CGFloat {
        min(4, 120 / CGFloat(max(lens.rounds.count, 1)))
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TribuneruText(
                    content: L10n.tr("SEASON PROGRESS"),
                    style: .vaporTagSmall,
                    color: .tribuneru(.mudTextSecondary),
                    lineLimit: 1
                )
                Spacer(minLength: 8)
                TribuneruText(
                    content: L10n.tr(
                        "%1$lld of %2$lld raced",
                        lens.doneCount,
                        lens.rounds.count
                    ),
                    style: .vaporResultTime,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 1
                )
            }
            HStack(spacing: segmentSpacing) {
                ForEach(lens.rounds) { round in
                    Capsule()
                        .fill(segmentColor(round))
                        .frame(height: 6)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func segmentColor(_ round: CXRaces.SeriesLens.Round) -> Color {
        if round.number <= lens.doneCount {
            return .tribuneru(.mudAccent)
        }
        if round.number == lens.nextRound?.number {
            return Color.tribuneru(.mudAccent).opacity(0.4)
        }
        return .tribuneru(.mudTrack)
    }

    private func countdown(to round: CXRaces.SeriesLens.Round) -> String {
        switch lens.days(to: round) {
        case ..<1: L10n.tr("Today")
        case 1: L10n.tr("Tomorrow")
        case let days: L10n.tr("In %lld days", days)
        }
    }

    private func subtitle(of round: CXRaces.SeriesLens.Round) -> String {
        [
            L10n.dateFormatter(template: "EEEddMMM").string(from: round.date),
            round.event.raceCountry ?? "",
            round.event.raceClass
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}

// MARK: - Leaders -

private struct LeadersSection: View {
    let leaders: [CXRaces.SeriesLens.Leader]
    let openRider: (CXRaces.RiderStanding) -> Void
    let openStandings: () -> Void

    var body: some View {
        MudSection(
            title: L10n.tr("Leaders"),
            pillTitle: L10n.tr("Standings"),
            pillIdentifier: "cx.leaders.standings",
            pillAction: openStandings
        ) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(leaders) { leader in
                    Button {
                        openRider(leader.standing)
                    } label: {
                        card(leader)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cx.leader.\(leader.id)")
                }
                if leaders.count == 1 {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func card(_ leader: CXRaces.SeriesLens.Leader) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TribuneruText(
                content: leader.standing.category.uppercased(with: L10n.locale),
                style: .vaporTagSmall,
                color: .tribuneru(.mudTextSecondary),
                lineLimit: 1
            )
            avatar(leader)
            TribuneruText(
                content: leader.standing.rider,
                style: .vaporResultTitle,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 2
            )
            HStack(alignment: .firstTextBaseline) {
                TribuneruText(
                    content: leader.standing.points,
                    style: .vaporRowTime,
                    color: .tribuneru(.mudAccent),
                    lineLimit: 1
                )
                Spacer(minLength: 4)
                if let gap = leader.gap {
                    TribuneruText(
                        content: gap,
                        style: .vaporFinishTime,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mudCard()
        .contentShape(Rectangle())
    }

    private func avatar(_ leader: CXRaces.SeriesLens.Leader) -> some View {
        ZStack {
            Color.tribuneru(.mudTagNeutral)
            if let url = leader.imageURL {
                CachedImageView(
                    imageUrl: url,
                    cornerRadius: 0
                )
            } else {
                TribuneruText(
                    content: CXRaces.riderInitials(leader.standing.rider),
                    style: .vaporResultTitle,
                    color: .tribuneru(.mudTagNeutralText)
                )
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.tribuneru(.mudAccent), lineWidth: 2))
    }
}

// MARK: - Last round -

private struct LastRoundSection: View {
    let round: CXRaces.SeriesLens.Round
    let podium: CXRaces.SeriesLens.LastPodium?
    let openEvent: (DTO.CXCalendarEvent) -> Void
    let openRider: (CXRaces.RiderPodium) -> Void
    let openResults: () -> Void

    var body: some View {
        MudSection(
            title: L10n.tr("Last round"),
            pillTitle: L10n.tr("Results"),
            pillIdentifier: "cx.lastRound.results",
            pillAction: openResults
        ) {
            VStack(spacing: 0) {
                Button {
                    openEvent(round.event)
                } label: {
                    titleRow
                }
                .buttonStyle(.plain)
                MudDivider()
                if let podium {
                    ForEach(Array(podium.podium.enumerated()), id: \.offset) { index, rider in
                        if index > 0 {
                            MudDivider()
                        }
                        Button {
                            openRider(
                                CXRaces.RiderPodium(
                                    podium: rider,
                                    category: podium.category,
                                    race: podium.race
                                )
                            )
                        } label: {
                            podiumRow(rider)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cx.lastRound.podium.\(index)")
                    }
                } else if !round.event.winnerName.isEmpty {
                    winnerRow
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .mudCard()
        }
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: round.event.race,
                style: .vaporResultTitle,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 1
            )
            Spacer(minLength: 8)
            TribuneruText(
                content: L10n.dateFormatter(template: "EEEddMMM")
                    .string(from: round.date)
                    .uppercased(with: L10n.locale),
                style: .vaporMonoMeta,
                color: .tribuneru(.mudTextSecondary),
                lineLimit: 1
            )
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func podiumRow(_ rider: DTO.CX24Homepage.Podium) -> some View {
        HStack(spacing: 12) {
            positionBadge(rider.position == 1)
                .overlay(
                    TribuneruText(
                        content: "\(rider.position)",
                        style: .vaporStatTime,
                        color: .tribuneru(rider.position == 1 ? .mudAccent : .mudTextMuted)
                    )
                )
            TribuneruText(
                content: rider.rider,
                style: .vaporRaceNameNext,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 1
            )
            Spacer(minLength: 8)
            TribuneruText(
                content: rider.time,
                style: .vaporStatTime,
                color: .tribuneru(rider.position == 1 ? .mudTextPrimary : .mudTextSecondary),
                lineLimit: 1
            )
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var winnerRow: some View {
        HStack(spacing: 12) {
            positionBadge(true)
                .overlay(
                    TribuneruText(
                        content: "1",
                        style: .vaporStatTime,
                        color: .tribuneru(.mudAccent)
                    )
                )
            VStack(alignment: .leading, spacing: 2) {
                TribuneruText(
                    content: L10n.tr("Winner"),
                    style: .vaporTagSmall,
                    color: .tribuneru(.mudTextSecondary),
                    lineLimit: 1
                )
                TribuneruText(
                    content: round.event.winnerName,
                    style: .vaporRaceNameNext,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 1
                )
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    private func positionBadge(_ isWinner: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                isWinner
                    ? Color.tribuneru(.mudAccent).opacity(0.16)
                    : Color.tribuneru(.mudRaised)
            )
            .frame(width: 28, height: 28)
    }
}

// MARK: - Rounds left -

private struct RoundsLeftSection: View {
    let rounds: [CXRaces.SeriesLens.Round]
    let open: (DTO.CXCalendarEvent) -> Void
    let openCalendar: () -> Void

    var body: some View {
        MudSection(
            title: L10n.tr("Rounds left"),
            pillTitle: L10n.tr("Calendar"),
            pillIdentifier: "cx.roundsLeft.calendar",
            pillAction: openCalendar
        ) {
            VStack(spacing: 0) {
                ForEach(rounds) { round in
                    if round.number != rounds.first?.number {
                        MudDivider()
                    }
                    Button {
                        open(round.event)
                    } label: {
                        row(round)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cx.roundsLeft.row.\(round.number)")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .mudCard()
        }
    }

    private func row(_ round: CXRaces.SeriesLens.Round) -> some View {
        HStack(spacing: 14) {
            TribuneruText(
                content: "R\(round.number)",
                style: .vaporMonoMeta,
                color: .tribuneru(.mudTextSecondary),
                lineLimit: 1
            )
            .frame(width: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                TribuneruText(
                    content: round.event.race,
                    style: .vaporRowTitle,
                    color: .tribuneru(.mudTextPrimary),
                    lineLimit: 1
                )
                if let country = round.event.raceCountry, !country.isEmpty {
                    TribuneruText(
                        content: country,
                        style: .vaporRowMeta,
                        color: .tribuneru(.mudTextSecondary),
                        lineLimit: 1
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TribuneruText(
                content: L10n.dateFormatter(template: "dMMM").string(from: round.date),
                style: .vaporResultTime,
                color: .tribuneru(.mudTextPrimary),
                lineLimit: 1
            )
            Chevron()
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Latest result -

/// The latest result floating over the bottom of the page. Its painting hides the winner until held,
/// and a tap opens every latest result.
private struct LatestResultCard: View {
    let race: DTO.CX24Homepage.Race
    let winner: DTO.CX24Homepage.Podium?
    let otherCount: Int
    let isShown: Bool
    let toggle: () -> Void
    let openAll: () -> Void

    @State private var longPressCompleted = false

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                TribuneruText(
                    content: L10n.tr("LATEST RESULT"),
                    style: .vaporTagSmall,
                    color: .tribuneru(.mudPageBackground),
                    lineLimit: 1
                )
                TribuneruText(
                    content: race.title,
                    style: .vaporResultTitle,
                    color: .tribuneru(.mudPageBackground),
                    lineLimit: 1
                )
                subtitle
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default) {
                openList()
            }
            .accessibilityAction(named: isShown ? L10n.tr("Hide results") : L10n.tr("Show results"), toggle)
            if otherCount > 0 {
                TribuneruText(
                    content: L10n.tr("+%lld", otherCount),
                    style: .vaporSeeAll,
                    color: .tribuneru(.mudPageBackground),
                    lineLimit: 1
                )
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(
                    Capsule().fill(Color.tribuneru(.mudPageBackground).opacity(0.18))
                )
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.tribuneru(.mudAccent))
        )
        .opacity(0.8)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture(perform: handleTap)
        .onLongPressGesture(
            minimumDuration: isShown ? SpoilerHold.hideDuration : SpoilerHold.duration,
            perform: holdCard,
            onPressingChanged: handlePressing
        )
    }

    private func handlePressing(_ pressing: Bool) {
        if pressing {
            longPressCompleted = false
        }
    }

    private func handleTap() {
        // A completed long press must not also open the list when the finger lifts.
        guard !longPressCompleted else { return }
        openList()
    }

    private func openList() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        openAll()
    }

    private var thumbnail: some View {
        ZStack {
            Color.tribuneru(.mudPageBackground)
            if let winner {
                TribuneruText(
                    content: CXRaces.riderInitials(winner.rider),
                    style: .vaporResultTitle,
                    color: .tribuneru(.mudAccent)
                )
            }
            RaceArtView(art: .spoiler)
                .opacity(isShown ? 0 : 1)
                .animation(
                    isShown ? .easeInOut(duration: SpoilerHold.revealDuration) : nil,
                    value: isShown
                )
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Color.tribuneru(.mudPageBackground), lineWidth: 2)
        )
        .accessibilityElement()
        .accessibilityLabel(isShown ? (winner?.rider ?? "") : L10n.tr("Result hidden"))
        .accessibilityIdentifier("cx.latestResult.thumbnail")
    }

    @ViewBuilder
    private var subtitle: some View {
        if !isShown {
            TribuneruText(
                content: L10n.tr("Hold the card to see the winner"),
                style: .vaporRowMeta,
                color: .tribuneru(.mudPageBackground),
                lineLimit: 1
            )
        } else if let winner {
            TribuneruText(
                content: "\(winner.rider) · \(winner.time)",
                style: .vaporRowMeta,
                color: .tribuneru(.mudPageBackground),
                lineLimit: 1
            )
        }
    }

    private func holdCard() {
        longPressCompleted = true
        if isShown {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        toggle()
    }
}

// MARK: - Empty -

private struct EmptyCalendarCard: View {
    var body: some View {
        TribuneruText(
            content: L10n.tr("Calendar is empty."),
            style: .vaporMeta,
            color: .tribuneru(.mudTextSecondary),
            lineLimit: 2
        )
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mudCard()
    }
}
