//
//  LiveRaceDetailView.swift
//  Tribuneros
//
//  The live race screen (route `liveRace`), opened from a LIVE race in the Today section. It shows
//  the race's PCS live page in three sections: the profile with the race state, the race data (the
//  KPI strip) and the situation on the road. The page is polled while the screen is open; see
//  `HomeRaces.LiveRace`.
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

    /// The polling dot, "Updating…" while the 60 s window runs (otherwise "Paused · pull to refresh"), and the last update time.
    private func statusLine(_ state: LiveRace.ViewState) -> some View {
        HStack(spacing: 8) {
            LiveRacePollingDot(isPolling: state.isPolling)
            TribuneruText(
                content: state.isPolling ? "Updating…" : "Paused · pull to refresh",
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
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
        .accessibilityElement(children: .contain)
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
            profileSection
            raceDataSection
            situationSection
        }
    }

    private var profileSection: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Profile")
        } content: {
            if let profile = content.profile {
                LiveRaceProfileChart(profile: profile)
            } else {
                emptyText("No profile on the page yet.")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("liveRace.profile")
    }

    private var raceDataSection: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
            VaporSectionHeader(title: "Race data")
        } content: {
            if content.stats.isEmpty {
                emptyText("No race data on the page yet.")
            } else {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(
                        alignment: .top,
                        spacing: 24
                    ) {
                        ForEach(content.stats) { stat in
                            LiveRaceStatTile(stat: stat)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("liveRace.stats")
    }

    private var situationSection: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
            VaporSectionHeader(title: "Situation")
        } content: {
            if content.groups.isEmpty {
                emptyText("Nothing on the road yet.")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(content.groups.enumerated()), id: \.offset) { index, group in
                        LiveRaceGroupRow(
                            group: group,
                            isLast: index == content.groups.count - 1
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("liveRace.situation")
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

// MARK: - Race data -

/// A label in small caps over the bold value.
private struct LiveRaceStatTile: View {
    let stat: LiveRace.ViewState.Stat

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            TribuneruText(
                content: stat.label,
                style: .vaporGroupLabel,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            TribuneruText(
                content: stat.value,
                style: .vaporRowTime,
                color: stat.isHighlighted
                    ? Color.tribuneru(.vaporAccent)
                    : Color.tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Profile -

/// The race profile: the part already ridden in pale yellow-green, the rest in bright green, with
/// the keypoints on the line, the front and the peloton on it, and the km axis underneath.
private struct LiveRaceProfileChart: View {
    private static let labelBand: CGFloat = 52
    private static let plotHeight: CGFloat = 130
    private static let axisHeight: CGFloat = 20
    private static let chartHeight = labelBand + plotHeight + axisHeight
    private static let rowCount = 3
    private static let rowHeight: CGFloat = 14
    private static let nameGap: CGFloat = 6

    let profile: LiveRace.ViewState.Profile

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            if !profile.elevationLabels.isEmpty {
                elevationScale
            }
            GeometryReader { proxy in
                chart(width: proxy.size.width)
            }
            .frame(height: Self.chartHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Elevation profile, \(percentDone) percent ridden")
        }
    }

    private var elevationScale: some View {
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

    private var percentDone: Int {
        Int((progress * 100).rounded())
    }

    private var progress: Double {
        min(max(profile.progress, 0), 1)
    }

    private func chart(width: CGFloat) -> some View {
        let placements = keypointPlacements(width: width)
        let kmLabels = profile.kmLabels.filter { $0.x <= 1 }
        let plotBottom = Self.labelBand + Self.plotHeight
        return ZStack(alignment: .topLeading) {
            LiveRaceProfileShape(
                points: profile.points,
                closesToBase: true
            )
            .fill(Color.tribuneru(.vaporProfileFuture))
            .frame(
                width: width,
                height: Self.plotHeight
            )
            .offset(y: Self.labelBand)

            LiveRaceProfileShape(
                points: profile.points,
                closesToBase: true
            )
            .fill(Color.tribuneru(.vaporProfileDone))
            .frame(
                width: width,
                height: Self.plotHeight
            )
            .mask(alignment: .leading) {
                Rectangle()
                    .frame(
                        width: width * CGFloat(progress),
                        height: Self.plotHeight
                    )
            }
            .offset(y: Self.labelBand)

            Canvas { context, _ in
                let ink = Color.tribuneru(.vaporTextPrimary)
                for placement in placements {
                    var stem = Path()
                    stem.move(to: CGPoint(
                        x: placement.stemX,
                        y: placement.baseY
                    ))
                    stem.addLine(to: CGPoint(
                        x: placement.stemX,
                        y: Self.stemTopY(row: placement.row)
                    ))
                    context.stroke(stem, with: .color(ink), lineWidth: 1)
                    if placement.isClimb {
                        let square = CGRect(
                            x: placement.stemX - 2.5,
                            y: Self.stemTopY(row: placement.row) - 2.5,
                            width: 5,
                            height: 5
                        )
                        context.fill(Path(square), with: .color(ink))
                    }
                }
                for label in kmLabels {
                    let tick = CGRect(
                        x: plotX(label.x, width: width) - 0.5,
                        y: plotBottom,
                        width: 1,
                        height: 4
                    )
                    context.fill(Path(tick), with: .color(Color.tribuneru(.vaporTextSecondary)))
                }
            }
            .frame(
                width: width,
                height: Self.chartHeight
            )

            ForEach(placements, id: \.index) { placement in
                TribuneruText(
                    content: placement.name,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .fixedSize()
                .position(
                    x: placement.labelX,
                    y: Self.labelCenterY(row: placement.row)
                )
            }

            ForEach(kmLabels.filter { $0.km % 20 == 0 }, id: \.km) { label in
                TribuneruText(
                    content: "\(label.km)",
                    style: .vaporMonoMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
                .fixedSize()
                .position(
                    x: min(max(plotX(label.x, width: width), 12), width - 12),
                    y: plotBottom + 12
                )
            }

            if let front = frontPoint(width: width) {
                bubble("1", fill: .vaporTextPrimary, text: .vaporPageBackground)
                    .position(front)
            }

            if let peloton = pelotonPoint(width: width) {
                bubble("P", fill: .vaporGroupBadge, text: .vaporTextPrimary)
                    .position(peloton)
            }
        }
        .frame(
            width: width,
            height: Self.chartHeight,
            alignment: .topLeading
        )
    }

    private func bubble(
        _ text: String,
        fill: Color.Palette,
        text textColor: Color.Palette
    ) -> some View {
        TribuneruText(
            content: text,
            style: .vaporPill,
            color: .tribuneru(textColor),
            lineLimit: 1
        )
        .frame(
            width: 18,
            height: 18
        )
        .background(Circle().fill(Color.tribuneru(fill)))
        .overlay(
            Circle()
                .stroke(
                    Color.tribuneru(.vaporPageBackground),
                    lineWidth: 1.5
                )
        )
    }

    // MARK: Geometry

    private func plotX(_ x: Double, width: CGFloat) -> CGFloat {
        width * CGFloat(min(max(x, 0), 1))
    }

    /// The chart's y for a height (0...1) of the profile.
    private func plotY(_ altitude: Double) -> CGFloat {
        Self.labelBand + Self.plotHeight * CGFloat(1 - min(max(altitude, 0), 1))
    }

    /// The profile's height (0...1) at the point nearest to `x`.
    private func altitude(at x: Double) -> Double {
        profile.points.min(by: { abs($0.x - x) < abs($1.x - x) })?.y ?? 0
    }

    private static func labelCenterY(row: Int) -> CGFloat {
        labelBand - 10 - rowHeight * CGFloat(row)
    }

    /// Where a stem ends: just under its name, which sits on `row`.
    private static func stemTopY(row: Int) -> CGFloat {
        labelCenterY(row: row) + 9
    }

    private func frontPoint(width: CGFloat) -> CGPoint? {
        guard let routeKm = profile.routeKm, routeKm > 0, let frontKm = profile.frontKm else {
            return nil
        }
        let x = frontKm / routeKm
        return CGPoint(
            x: plotX(x, width: width),
            y: plotY(altitude(at: x))
        )
    }

    /// Estimated from the front's km and the gap: drawn below the line so it doesn't cover the front.
    private func pelotonPoint(width: CGFloat) -> CGPoint? {
        guard let routeKm = profile.routeKm, routeKm > 0, let pelotonKm = profile.pelotonKm else {
            return nil
        }
        let x = pelotonKm / routeKm
        let plotBottom = Self.labelBand + Self.plotHeight
        return CGPoint(
            x: plotX(x, width: width),
            y: min(plotY(altitude(at: x)) + 20, plotBottom - 9)
        )
    }

    // MARK: Keypoint names

    /// A keypoint's name and stem, before the rows are chosen.
    private struct KeypointPlacement {
        let index: Int
        let name: String
        let isClimb: Bool
        let stemX: CGFloat
        let baseY: CGFloat
        var row = 0
        var labelX: CGFloat = 0
        var halfWidth: CGFloat = 0

        var labelRange: ClosedRange<CGFloat> {
            (labelX - halfWidth - LiveRaceProfileChart.nameGap)...(labelX + halfWidth + LiveRaceProfileChart.nameGap)
        }
    }

    private func keypointPlacements(width: CGFloat) -> [KeypointPlacement] {
        let candidates = profile.keypoints.enumerated().map { index, keypoint in
            KeypointPlacement(
                index: index,
                name: keypoint.name,
                isClimb: keypoint.isClimb,
                stemX: plotX(keypoint.x, width: width),
                baseY: plotY(altitude(at: keypoint.x))
            )
        }
        var placed: [KeypointPlacement] = []
        for var candidate in candidates.sorted(by: { $0.stemX < $1.stemX }) {
            // A rough width per character: the name is centred on its stem, kept inside the chart.
            candidate.halfWidth = CGFloat(candidate.name.count) * 3.2 + 2
            candidate.labelX = min(max(candidate.stemX, candidate.halfWidth), width - candidate.halfWidth)
            for row in 0..<Self.rowCount {
                var next = candidate
                next.row = row
                if placed.allSatisfy({ !conflicts(next, $0) }) {
                    placed.append(next)
                    break
                }
            }
        }
        return placed
    }

    /// Two names on one row, or a name and a stem crossing each other. Stems run from the profile up to their row.
    private func conflicts(
        _ new: KeypointPlacement,
        _ old: KeypointPlacement
    ) -> Bool {
        if new.row == old.row, new.labelRange.overlaps(old.labelRange) {
            return true
        }
        if old.row >= new.row, new.labelRange.contains(old.stemX) {
            return true
        }
        return new.row >= old.row && old.labelRange.contains(new.stemX)
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

/// One group: a blue badge on a vertical line, its name and gap, then numbered rider rows.
private struct LiveRaceGroupRow: View {
    private static let visibleRiderCount = 10

    let group: LiveRace.ViewState.Group
    let isLast: Bool

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 14
        ) {
            VStack(spacing: 0) {
                TribuneruText(
                    content: group.badge,
                    style: .vaporPill,
                    color: .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                .frame(
                    width: 30,
                    height: 30
                )
                .background(Circle().fill(Color.tribuneru(.vaporGroupBadge)))
                if !isLast {
                    Rectangle()
                        .fill(Color.tribuneru(.vaporTagNeutral))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    TribuneruText(
                        content: group.name,
                        style: .vaporGroupLabel,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                    if !group.gap.isEmpty {
                        TribuneruText(
                            content: group.gap,
                            style: .vaporPill,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 1
                        )
                    }
                }
                ForEach(Array(group.riders.prefix(Self.visibleRiderCount).enumerated()), id: \.offset) { _, rider in
                    riderRow(rider)
                }
                if group.riders.count > Self.visibleRiderCount {
                    TribuneruText(
                        content: "+\(group.riders.count - Self.visibleRiderCount) more",
                        style: .vaporRowMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 1
                    )
                }
            }
            .padding(.bottom, isLast ? 0 : 18)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        }
    }

    private func riderRow(_ rider: LiveRace.ViewState.Rider) -> some View {
        HStack(spacing: 10) {
            TribuneruText(
                content: rider.position,
                style: .vaporPill,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            .frame(
                width: 20,
                alignment: .trailing
            )
            TribuneruText(
                content: rider.bib,
                style: .vaporPill,
                color: .tribuneru(.vaporPageBackground),
                lineLimit: 1
            )
            .frame(minWidth: 36)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.tribuneru(.vaporTextPrimary))
            )
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
            VaporFlagView(countryCode: rider.countryCode)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("liveRace.rider")
    }
}

// MARK: - Polling -

/// The status line's bullet: green and pulsing while polling, red and still when paused. Still in both states with Reduce Motion.
private struct LiveRacePollingDot: View {
    let isPolling: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(Color.tribuneru(isPolling ? .vaporLive : .vaporLiveRed))
            .frame(
                width: 8,
                height: 8
            )
            .opacity(isDimmed ? 0.3 : 1)
            .onAppear {
                updatePulse()
            }
            .onChange(of: isPolling) { _, _ in
                updatePulse()
            }
            .onChange(of: reduceMotion) { _, _ in
                updatePulse()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isPolling ? "Live updates on" : "Live updates paused")
            .accessibilityIdentifier("liveRace.pollingDot")
    }

    private func updatePulse() {
        guard isPolling, !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDimmed = false
            }
            return
        }
        isDimmed = false
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            isDimmed = true
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
