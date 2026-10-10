//
//  LiveRaceDetailView.swift
//  Tribuneros
//
//  The live race screen (route `liveRace`), opened from a LIVE race in the Today section. It shows
//  the race's PCS live page in three sections: the race stats with the profile, the situation on
//  the road and the timeline. The page is polled while the screen is open; see `HomeRaces.LiveRace`.
//

import SwiftUI

private typealias LiveRace = HomeRaces.LiveRace

struct LiveRaceDetailView: View {
    @StateObject private var viewModel: LiveRace.ViewModel<LiveRace.InteractorImpl>

    init(
        context: HomeRaces.LiveRace.Context,
        router: Router
    ) {
        _viewModel = StateObject(
            wrappedValue: LiveRace.ViewModel(
                context: context,
                router: router,
                interactor: LiveRace.InteractorImpl(url: context.url)
            )
        )
    }

    var body: some View {
        let state = viewModel.stateView
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if state.showHint {
                    hintButton
                }
                header(state)
                statusLine(state)
                content(state.body)
                if state.pcsURL != nil {
                    Button {
                        viewModel.action(.openOnPCS)
                    } label: {
                        VaporCard {
                            VaporMoreInfoLink(title: "Open on ProCyclingStats")
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .refreshable {
            await viewModel.refresh()
        }
        .background(Color.tribuneru(.vaporPageBackground))
        .preferredColorScheme(.dark)
        .navigationTitle("Live")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.action(.onAppear)
        }
        .onDisappear {
            viewModel.action(.onDisappear)
        }
    }

    private var hintButton: some View {
        Button {
            viewModel.action(.dismissHint)
        } label: {
            LiveRaceHintCallout()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HomeRaces.LiveRace.Hint.text)
        .accessibilityIdentifier("liveRace.hint")
    }

    private func header(_ state: LiveRace.ViewState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TribuneruText(
                content: state.title,
                style: .vaporHeading,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 3
            )
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("liveRace.title")

            if !state.subtitle.isEmpty || !state.flagCode.isEmpty {
                HStack(spacing: 8) {
                    if !state.flagCode.isEmpty {
                        VaporFlagView(countryCode: state.flagCode)
                    }
                    if !state.subtitle.isEmpty {
                        TribuneruText(
                            content: state.subtitle,
                            style: .vaporRowMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 2
                        )
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
    }

    /// "LIVE · Updating…" while the 60 s window runs, otherwise "Paused · pull to refresh", and the time of the last update.
    private func statusLine(_ state: LiveRace.ViewState) -> some View {
        HStack(spacing: 8) {
            if state.isPolling {
                RaceStatusTag(
                    kind: .live,
                    size: .small
                )
                TribuneruText(
                    content: "Updating…",
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            } else {
                TribuneruText(
                    content: "Paused · pull to refresh",
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            Spacer(minLength: 8)
            if !state.updatedText.isEmpty {
                TribuneruText(
                    content: state.updatedText,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("liveRace.status")
    }

    @ViewBuilder
    private func content(_ body: LiveRace.ViewState.Body) -> some View {
        switch body {
        case .loading:
            LiveRaceSections(content: .placeholders)
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading the live race")
        case .loaded(let loaded):
            LiveRaceSections(content: loaded)
        case .unavailable(let message):
            TribuneruText(
                content: message,
                style: .vaporRowMeta,
                color: .tribuneru(.vaporTextMuted),
                lineLimit: 3
            )
        }
    }
}

// MARK: - Sections -

private struct LiveRaceSections: View {
    let content: LiveRace.ViewState.Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            raceSection
            situationSection
            timelineSection
        }
    }

    private var raceSection: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Race")
        } content: {
            VStack(alignment: .leading, spacing: 16) {
                if content.stats.isEmpty && content.profile == nil {
                    emptyText("No race data on the page yet.")
                }
                if !content.stats.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(
                                .flexible(),
                                spacing: 10
                            ),
                            GridItem(
                                .flexible(),
                                spacing: 10
                            )
                        ],
                        spacing: 10
                    ) {
                        ForEach(content.stats) { stat in
                            LiveRaceStatTile(stat: stat)
                        }
                    }
                }
                if let profile = content.profile {
                    LiveRaceProfileCard(profile: profile)
                }
            }
            .accessibilityIdentifier("liveRace.stats")
        }
    }

    private var situationSection: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            VaporSectionHeader(title: "Situation")
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                if content.groups.isEmpty {
                    emptyText("Nothing on the road yet.")
                }
                ForEach(content.groups) { group in
                    LiveRaceGroupCard(group: group)
                }
            }
            .accessibilityIdentifier("liveRace.situation")
        }
    }

    /// The third and last section; events keep the order PCS lists them in (newest first).
    private var timelineSection: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelYesterday)) {
            VaporSectionHeader(title: "Timeline")
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                if content.events.isEmpty {
                    emptyText("No events yet.")
                }
                ForEach(Array(content.events.enumerated()), id: \.element.id) { index, event in
                    LiveRaceTimelineRow(
                        event: event,
                        isLast: index == content.events.count - 1
                    )
                }
            }
            .accessibilityIdentifier("liveRace.timeline")
        }
    }

    private func emptyText(_ text: String) -> some View {
        TribuneruText(
            content: text,
            style: .vaporRowMeta,
            color: .tribuneru(.vaporTextMuted),
            lineLimit: 2
        )
    }
}

// MARK: - Race -

private struct LiveRaceStatTile: View {
    let stat: LiveRace.ViewState.Stat

    var body: some View {
        VaporCard(spacing: 4) {
            TribuneruText(
                content: stat.label,
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            TribuneruText(
                content: stat.value,
                style: .vaporStatTime,
                color: stat.isHighlighted
                    ? Color.tribuneru(.vaporAccent)
                    : Color.tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LiveRaceProfileCard: View {
    let profile: LiveRace.ViewState.Profile

    var body: some View {
        VaporCard(spacing: 8) {
            LiveRaceProfileChart(profile: profile)
            if !profile.elevationLabels.isEmpty {
                elevationLabels
            }
        }
    }

    private var elevationLabels: some View {
        HStack(spacing: 0) {
            ForEach(Array(profile.elevationLabels.enumerated()), id: \.offset) { index, label in
                if index > 0 {
                    Spacer(minLength: 0)
                }
                TribuneruText(
                    content: "\(label) m",
                    style: .vaporMonoMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
        }
    }
}

/// The race profile: the elevation line filled, the done part (up to `progress`) in the accent
/// colour and the rest dimmer, with the keypoints marked along it.
private struct LiveRaceProfileChart: View {
    let profile: LiveRace.ViewState.Profile

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                LiveRaceProfileShape(
                    points: profile.points,
                    closesToBase: true
                )
                .fill(Color.tribuneru(.vaporTextSecondary).opacity(0.16))

                LiveRaceProfileShape(
                    points: profile.points,
                    closesToBase: true
                )
                .fill(Color.tribuneru(.vaporAccent).opacity(0.34))
                .mask(alignment: .leading) {
                    doneMask(proxy.size)
                }

                LiveRaceProfileShape(points: profile.points)
                    .stroke(Color.tribuneru(.vaporTextSecondary), lineWidth: 1.5)

                LiveRaceProfileShape(points: profile.points)
                    .stroke(Color.tribuneru(.vaporAccent), lineWidth: 2)
                    .mask(alignment: .leading) {
                        doneMask(proxy.size)
                    }

                ForEach(Array(profile.keypoints.enumerated()), id: \.offset) { _, keypoint in
                    Circle()
                        .fill(Color.tribuneru(.vaporTextPrimary))
                        .frame(
                            width: 6,
                            height: 6
                        )
                        .position(
                            markerPoint(
                                keypoint,
                                in: proxy.size
                            )
                        )
                    TribuneruText(
                        content: keypoint.name,
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 1
                    )
                    .fixedSize()
                    .position(
                        labelPoint(
                            keypoint,
                            in: proxy.size
                        )
                    )
                }
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height
            )
        }
        .frame(height: 140)
    }

    /// Covers the part of the chart that is done, from the leading edge to `progress`.
    private func doneMask(_ size: CGSize) -> some View {
        Rectangle()
            .frame(
                width: size.width * CGFloat(min(max(profile.progress, 0), 1)),
                height: size.height
            )
    }

    private func markerPoint(
        _ keypoint: DTO.LivePage.Profile.Keypoint,
        in size: CGSize
    ) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(min(max(keypoint.x, 0), 1)),
            y: size.height * CGFloat(1 - min(max(altitude(at: keypoint.x), 0), 1))
        )
    }

    /// The name sits just above its marker, kept inside the chart's width.
    private func labelPoint(
        _ keypoint: DTO.LivePage.Profile.Keypoint,
        in size: CGSize
    ) -> CGPoint {
        let marker = markerPoint(
            keypoint,
            in: size
        )
        return CGPoint(
            x: min(max(marker.x, 48), size.width - 48),
            y: max(marker.y - 12, 8)
        )
    }

    /// The profile's height (0...1) at the point nearest to `x`.
    private func altitude(at x: Double) -> Double {
        guard let nearest = profile.points.min(by: { abs($0.x - x) < abs($1.x - x) }) else {
            return 0
        }
        return nearest.y
    }
}

/// The elevation line through `points` (0...1, x left to right, y bottom to top). With
/// `closesToBase` it is also closed down to the bottom edge, for filling.
private struct LiveRaceProfileShape: Shape {
    let points: [DTO.LivePage.Profile.Point]
    var closesToBase = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func place(_ point: DTO.LivePage.Profile.Point) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * CGFloat(min(max(point.x, 0), 1)),
                y: rect.minY + rect.height * CGFloat(1 - min(max(point.y, 0), 1))
            )
        }

        guard let first = points.first, let last = points.last else {
            return path
        }
        path.move(to: place(first))
        for point in points.dropFirst() {
            path.addLine(to: place(point))
        }
        if closesToBase {
            path.addLine(
                to: CGPoint(
                    x: place(last).x,
                    y: rect.maxY
                )
            )
            path.addLine(
                to: CGPoint(
                    x: place(first).x,
                    y: rect.maxY
                )
            )
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Situation -

private struct LiveRaceGroupCard: View {
    private static let visibleRiderCount = 10

    let group: LiveRace.ViewState.Group

    var body: some View {
        VaporCard(spacing: 10) {
            header
            ForEach(Array(visibleRiders.enumerated()), id: \.offset) { _, rider in
                riderRow(rider)
            }
            if hiddenCount > 0 {
                TribuneruText(
                    content: "+\(hiddenCount) more",
                    style: .vaporRowMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: group.badge,
                style: .vaporPill,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            .frame(
                width: 28,
                height: 28
            )
            .background(Circle().fill(Color.tribuneru(.vaporTagNeutral)))
            TribuneruText(
                content: group.name,
                style: .vaporRowTitle,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            Spacer(minLength: 8)
            if !group.gap.isEmpty {
                TribuneruText(
                    content: group.gap,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
        }
    }

    private var visibleRiders: [DTO.LivePage.Group.Rider] {
        Array(group.riders.prefix(Self.visibleRiderCount))
    }

    private var hiddenCount: Int {
        max(group.riders.count - Self.visibleRiderCount, 0)
    }

    private func riderRow(_ rider: DTO.LivePage.Group.Rider) -> some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: rider.bib,
                style: .vaporPill,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            .frame(
                width: 36,
                alignment: .leading
            )
            VaporFlagView(countryCode: rider.countryCode)
            TribuneruText(
                content: rider.name,
                style: .vaporRaceNameNext,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }
}

// MARK: - Timeline -

private struct LiveRaceTimelineRow: View {
    let event: LiveRace.ViewState.Event
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                TribuneruText(
                    content: event.badge,
                    style: .vaporPill,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .frame(
                    width: 34,
                    height: 34
                )
                .background(Circle().fill(Color.tribuneru(.vaporTagNeutral)))
                if !isLast {
                    Rectangle()
                        .fill(Color.tribuneru(.vaporTextPrimary).opacity(0.14))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    TribuneruText(
                        content: event.text,
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 4
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    if !event.ago.isEmpty {
                        TribuneruText(
                            content: event.ago,
                            style: .vaporMonoMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                        .fixedSize()
                    }
                }
                if !event.header.isEmpty {
                    tableRow(
                        event.header,
                        color: .tribuneru(.vaporTextSecondary)
                    )
                }
                ForEach(Array(event.rows.enumerated()), id: \.offset) { _, row in
                    tableRow(
                        row,
                        color: .tribuneru(.vaporTextPrimary)
                    )
                }
            }
            .padding(.bottom, 18)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("liveRace.event")
    }

    private func tableRow(
        _ cells: [String],
        color: Color
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                TribuneruText(
                    content: cell,
                    style: .vaporRowMeta,
                    color: color,
                    lineLimit: 1
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
        }
    }
}

// MARK: - Hint -

/// The one-time hint at the top: an accent box with a down arrow; a tap dismisses it.
private struct LiveRaceHintCallout: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down")
                .font(
                    .system(
                        size: 13,
                        weight: .bold
                    )
                )
                .foregroundColor(.tribuneru(.vaporPageBackground))
            TribuneruText(
                content: HomeRaces.LiveRace.Hint.text,
                style: .vaporLink,
                color: .tribuneru(.vaporPageBackground),
                lineLimit: 2
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .background(
            Color.tribuneru(.vaporAccent),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }
}
