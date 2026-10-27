//
//  Tifosi.TVGuideView.swift
//  Tribuneros
//

import SwiftUI

extension Tifosi {

    struct TVGuideView: View {
        let screen: TVScreen
        let onTapChannel: (URL) -> Void
        let onSelectDay: (String?) -> Void
        let onRetry: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                TVDayStrip(
                    days: screen.days,
                    onSelect: onSelectDay
                )
                if !screen.isToday {
                    TribuneruText(
                        content: screen.dayTitle,
                        style: .vaporHeading,
                        color: .tribuneru(.tifosiTextPrimary),
                        lineLimit: 1
                    )
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("tifosi.tv.dayTitle")
                }
                content
            }
        }

        @ViewBuilder
        private var content: some View {
            switch screen.state {
            case .loading:
                Group {
                    if screen.isToday {
                        TVDeck(
                            cards: TVState.placeholders.deck(now: Date()),
                            now: Date(),
                            featuredID: nil,
                            onTapChannel: { _ in }
                        )
                    } else {
                        TVTickets(
                            races: TVState.placeholders.races,
                            featuredID: nil,
                            onTapChannel: { _ in }
                        )
                    }
                }
                .redacted(reason: .placeholder)
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.tr("Loading the TV guide"))
                .accessibilityIdentifier("tifosi.tv.loading")
            case .failed:
                message(
                    text: screen.isToday
                        ? L10n.tr("Couldn’t load today’s TV guide.")
                        : L10n.tr("Couldn’t load this day’s TV guide."),
                    identifier: "tifosi.tv.error",
                    showsRetry: true
                )
            case .empty:
                if screen.isToday {
                    message(
                        text: L10n.tr("No broadcasts listed for today."),
                        identifier: "tifosi.tv.empty",
                        showsRetry: false
                    )
                } else {
                    TVDayOff()
                }
            case .guide(let guide):
                if screen.isToday {
                    TimelineView(.everyMinute) { context in
                        TVDeck(
                            cards: guide.deck(
                                now: context.date,
                                featured: screen.featuredRaceID
                            ),
                            now: context.date,
                            featuredID: screen.featuredRaceID,
                            onTapChannel: onTapChannel
                        )
                    }
                } else {
                    TVTickets(
                        races: guide.races,
                        featuredID: screen.featuredRaceID,
                        onTapChannel: onTapChannel
                    )
                }
            }
        }

        private func message(
            text: String,
            identifier: String,
            showsRetry: Bool
        ) -> some View {
            VStack(spacing: 14) {
                TribuneruText(
                    content: text,
                    style: .vaporRowMeta,
                    color: .tribuneru(.tifosiTextSecondary),
                    lineLimit: 3
                )
                .multilineTextAlignment(.center)
                if showsRetry {
                    Button {
                        onRetry()
                    } label: {
                        TribuneruText(
                            content: L10n.tr("Try again"),
                            style: .vaporLink,
                            color: .tribuneru(.tifosiOnAccent),
                            lineLimit: 1
                        )
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Color.tribuneru(.tifosiAccent)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tifosi.tv.retry")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.tribuneru(.tifosiPanel))
            )
            .accessibilityIdentifier(identifier)
        }
    }
}

// MARK: - Day strip -
extension Tifosi {

    /// Seven tabs, today first; each bar grows with the day's race count.
    struct TVDayStrip: View {
        let days: [TVDay]
        let onSelect: (String?) -> Void

        var body: some View {
            if days.isEmpty {
                strip(TVState.placeholderDays)
                    .redacted(reason: .placeholder)
                    .disabled(true)
                    .accessibilityHidden(true)
            } else {
                strip(days)
            }
        }

        private func strip(_ days: [TVDay]) -> some View {
            HStack(spacing: 5) {
                ForEach(days) { day in
                    Button {
                        onSelect(day.offset == 0 ? nil : day.date)
                    } label: {
                        tab(day)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.accessibilityLabel)
                    .accessibilityAddTraits(day.isSelected ? .isSelected : [])
                    .accessibilityIdentifier("tifosi.tv.day.\(day.offset)")
                }
            }
            .animation(.easeOut(duration: 0.2), value: days)
        }

        private func tab(_ day: TVDay) -> some View {
            let ink: Color.Palette = day.isSelected ? .tifosiOnAccent : .tifosiTextPrimary
            let bar: Color.Palette = day.isSelected ? .tifosiOnAccent : day.raceCount > 0 ? .tifosiAccent : .tifosiTag
            return VStack(spacing: 2) {
                TribuneruText(
                    content: day.weekday,
                    style: .vaporFeedTag,
                    color: .tribuneru(day.isSelected ? .tifosiOnAccent : .tifosiTextSecondary),
                    lineLimit: 1
                )
                .minimumScaleFactor(0.7)
                TribuneruText(
                    content: day.dayNumber,
                    style: .vaporRowTime,
                    color: .tribuneru(ink),
                    lineLimit: 1
                )
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.tribuneru(bar))
                    .frame(
                        width: 22,
                        height: CGFloat(min(max(day.raceCount * 5, 2), 22))
                    )
                    .frame(
                        height: 22,
                        alignment: .bottom
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.tribuneru(day.isSelected ? .tifosiAccent : .tifosiPanel))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        Color.tribuneru(day.isSelected ? .tifosiAccent : .tifosiLine),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Deck -
extension Tifosi {

    /// Today's races as a stack, most relevant in front; drag the front card up (or tap the arrow) for the next.
    struct TVDeck: View {
        let cards: [TVDeckCard]
        let now: Date
        let featuredID: String?
        let onTapChannel: (URL) -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var index = 0
        @State private var dragOffset: CGFloat = 0

        private let stripStep: CGFloat = 26
        private let commitDistance: CGFloat = 70

        var body: some View {
            if cards.isEmpty {
                EmptyView()
            } else {
                deck
            }
        }

        private var deck: some View {
            let count = cards.count
            let current = index % count
            let behind = min(count - 1, 2)
            return VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .top) {
                    if behind > 0 {
                        ForEach(Array((1...behind).reversed()), id: \.self) { depth in
                            strip(
                                cards[(current + depth) % count],
                                depth: depth,
                                behind: behind
                            )
                        }
                    }
                    TVDeckFrontCard(
                        card: cards[current],
                        isFeatured: cards[current].id == featuredID,
                        position: L10n.tr("%lld of %lld", current + 1, count),
                        now: now,
                        onTapChannel: onTapChannel
                    )
                    .id(cards[current].id)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .padding(.top, CGFloat(behind) * stripStep)
                    .offset(y: dragOffset)
                    .onChange(of: featuredID) {
                        index = 0
                        dragOffset = 0
                    }
                    .gesture(
                        dragGesture,
                        including: count > 1 ? .all : .subviews
                    )
                    .accessibilityAction(named: L10n.tr("Next race")) {
                        advance()
                    }
                }
                if count > 1 {
                    footer
                }
            }
        }

        private func strip(
            _ card: TVDeckCard,
            depth: Int,
            behind: Int
        ) -> some View {
            HStack(spacing: 6) {
                TribuneruText(
                    content: card.race.startText,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.tifosiTextSecondary),
                    lineLimit: 1
                )
                TribuneruText(
                    content: card.race.title,
                    style: .vaporRowMeta,
                    color: .tribuneru(depth == 1 ? .tifosiTextMuted : .tifosiTextSecondary),
                    lineLimit: 1
                )
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .frame(
                height: 60,
                alignment: .top
            )
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.tribuneru(depth == 1 ? .tifosiCard : .tifosiPanel))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        Color.tribuneru(depth == 1 ? .tifosiTag : .tifosiLine),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, CGFloat(depth) * 12)
            .padding(.top, CGFloat(behind - depth) * stripStep)
            .accessibilityHidden(true)
        }

        private var footer: some View {
            HStack(spacing: 12) {
                TribuneruText(
                    content: L10n.tr("Most relevant first · drag the card up for the next"),
                    style: .vaporRowMeta,
                    color: .tribuneru(.tifosiTextSecondary),
                    lineLimit: 2
                )
                Spacer(minLength: 0)
                Button {
                    advance()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.tribuneru(.tifosiAccent))
                        .frame(
                            width: 44,
                            height: 44
                        )
                        .background(Circle().fill(Color.tribuneru(.tifosiPanel)))
                        .overlay(
                            Circle().strokeBorder(
                                Color.tribuneru(.tifosiTag),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("Next race"))
                .accessibilityIdentifier("tifosi.tv.deck.next")
            }
        }

        private var dragGesture: some Gesture {
            DragGesture(minimumDistance: 8)
                .onChanged { drag in
                    guard abs(drag.translation.height) > abs(drag.translation.width) else { return }
                    dragOffset = min(drag.translation.height, 0)
                }
                .onEnded { drag in
                    let isFlick = drag.predictedEndTranslation.height < -commitDistance * 2
                    if -drag.translation.height >= commitDistance || isFlick {
                        advance()
                    } else {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { dragOffset = 0 }
                    }
                }
        }

        private func advance() {
            guard cards.count > 1 else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                index = (index + 1) % cards.count
                dragOffset = 0
            }
        }
    }

    struct TVDeckFrontCard: View {
        let card: TVDeckCard
        let isFeatured: Bool
        let position: String
        let now: Date
        let onTapChannel: (URL) -> Void

        private var race: TVRace { card.race }

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    TribuneruText(
                        content: tag,
                        style: .vaporTagSmall,
                        color: .tribuneru(card.status == .onAir ? .tifosiOnAccent : .tifosiTagText),
                        lineLimit: 1
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.tribuneru(card.status == .onAir ? .tifosiAccent : .tifosiTag))
                    )
                    .accessibilityIdentifier("tifosi.tv.deck.tag")
                    TVDisciplineTag(title: race.discipline)
                    Spacer(minLength: 0)
                    TribuneruText(
                        content: position,
                        style: .vaporMonoMeta,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 1
                    )
                }
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: big,
                        style: .tifosiDeckCountdown,
                        color: .tribuneru(card.status == .ended ? .tifosiTextSecondary : .tifosiAccent),
                        lineLimit: 1
                    )
                    .minimumScaleFactor(0.6)
                    if let caption {
                        TribuneruText(
                            content: caption,
                            style: .vaporMonoMeta,
                            color: .tribuneru(.tifosiTextMuted),
                            lineLimit: 1
                        )
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: race.title,
                        style: .vaporHeading,
                        color: .tribuneru(.tifosiTextPrimary),
                        lineLimit: 2
                    )
                    .accessibilityIdentifier("tifosi.tv.race.\(race.title)")
                    TribuneruText(
                        content: race.meta,
                        style: .vaporRowMeta,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 2
                    )
                }
                TVChannelChips(
                    channels: race.channels,
                    onTap: onTapChannel
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.tribuneru(.tifosiCard))
                    .shadow(
                        color: .tribuneru(.tifosiPageBackground),
                        radius: 12,
                        y: -6
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        Color.tribuneru(card.status == .onAir || isFeatured ? .tifosiAccent : .tifosiTag),
                        lineWidth: isFeatured ? 3 : 1
                    )
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tifosi.tv.deck")
            .accessibilityValue(isFeatured ? L10n.tr("Featured") : "")
        }

        private var tag: String {
            switch card.status {
            case .onAir: L10n.tr("ON AIR")
            case .next: L10n.tr("NEXT")
            case .later: L10n.tr("LATER")
            case .ended: L10n.tr("ENDED")
            }
        }

        private var big: String {
            switch card.status {
            case .onAir: race.remaining(now: now) ?? race.startText
            case .next, .later: race.countdown(now: now) ?? race.startText
            case .ended: race.startText
            }
        }

        private var caption: String? {
            switch card.status {
            case .onAir:
                race.remaining(now: now) == nil ? nil : L10n.tr("LEFT")
            case .next, .later:
                race.countdown(now: now) == nil ? nil : L10n.tr("TO THE START · %@", race.startText)
            case .ended:
                nil
            }
        }
    }
}

// MARK: - Other days -
extension Tifosi {

    struct TVTickets: View {
        let races: [TVRace]
        let featuredID: String?
        let onTapChannel: (URL) -> Void

        var body: some View {
            VStack(spacing: 10) {
                ForEach(races) { race in
                    ticket(race)
                }
            }
        }

        private func ticket(_ race: TVRace) -> some View {
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    TribuneruText(
                        content: race.startText,
                        style: .vaporRowTime,
                        color: .tribuneru(.tifosiAccent),
                        lineLimit: 1
                    )
                    TribuneruText(
                        content: race.discipline.uppercased(with: L10n.locale),
                        style: .vaporFeedTag,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 1
                    )
                }
                .frame(width: 78)
                .frame(maxHeight: .infinity)
                .background(Color.tribuneru(.tifosiCard))
                TVTicketPerforation()
                    .stroke(
                        Color.tribuneru(.tifosiPageBackground),
                        style: StrokeStyle(
                            lineWidth: 2,
                            dash: [4, 4]
                        )
                    )
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 6) {
                    TribuneruText(
                        content: race.title,
                        style: .vaporRowTitle,
                        color: .tribuneru(.tifosiTextPrimary),
                        lineLimit: 2
                    )
                    .accessibilityIdentifier("tifosi.tv.race.\(race.title)")
                    TribuneruText(
                        content: race.meta,
                        style: .vaporRowMeta,
                        color: .tribuneru(.tifosiTextSecondary),
                        lineLimit: 2
                    )
                    TVChannelChips(
                        channels: race.channels,
                        onTap: onTapChannel
                    )
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.tribuneru(.tifosiPanel))
            }
            .fixedSize(horizontal: false, vertical: true)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        Color.tribuneru(race.id == featuredID ? .tifosiAccent : .tifosiLine),
                        lineWidth: race.id == featuredID ? 3 : 1
                    )
            )
            .accessibilityValue(race.id == featuredID ? L10n.tr("Featured") : "")
        }
    }

    struct TVTicketPerforation: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return path
        }
    }

    struct TVDayOff: View {
        var body: some View {
            VStack(spacing: 6) {
                TribuneruText(
                    content: L10n.tr("No races on TV"),
                    style: .vaporRowTitle,
                    color: .tribuneru(.tifosiTextPrimary),
                    lineLimit: 1
                )
                TribuneruText(
                    content: L10n.tr("A rare day off. Go ride your own bike."),
                    style: .vaporRowMeta,
                    color: .tribuneru(.tifosiTextSecondary),
                    lineLimit: 2
                )
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        Color.tribuneru(.tifosiTag),
                        style: StrokeStyle(
                            lineWidth: 1,
                            dash: [5, 4]
                        )
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tifosi.tv.dayOff")
        }
    }

    struct TVDisciplineTag: View {
        let title: String

        var body: some View {
            TribuneruText(
                content: title.uppercased(with: L10n.locale),
                style: .vaporFeedTag,
                color: .tribuneru(.tifosiTagText),
                lineLimit: 1
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.tribuneru(.tifosiTag)))
        }
    }
}

// MARK: - Channel chips -
extension Tifosi {

    struct TVChannelChips: View {
        let channels: [TVChannel]
        let onTap: (URL) -> Void

        var body: some View {
            if channels.isEmpty {
                TribuneruText(
                    content: L10n.tr("No channel listed yet"),
                    style: .vaporRowMeta,
                    color: .tribuneru(.tifosiTextMuted),
                    lineLimit: 1
                )
            } else {
                TVFlowLayout(spacing: 8) {
                    ForEach(channels) { channel in
                        chip(channel)
                    }
                }
            }
        }

        @ViewBuilder
        private func chip(_ channel: TVChannel) -> some View {
            if let url = channel.url {
                Button {
                    onTap(url)
                } label: {
                    label(channel)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tifosi.tv.channel.\(channel.name)")
            } else {
                label(channel)
                    .accessibilityIdentifier("tifosi.tv.channel.\(channel.name)")
            }
        }

        private func label(_ channel: TVChannel) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    TribuneruText(
                        content: channel.name,
                        style: .vaporPill,
                        color: .tribuneru(channel.isLocal ? .tifosiOnAccent : .tifosiTextPrimary),
                        lineLimit: 1
                    )
                    if channel.url != nil {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.tribuneru(channel.isLocal ? .tifosiOnAccent : .tifosiTextSecondary))
                    }
                }
                if !channel.regions.isEmpty {
                    TribuneruText(
                        content: channel.regions,
                        style: .vaporMonoMeta,
                        color: .tribuneru(channel.isLocal ? .tifosiOnAccent : .tifosiTextSecondary),
                        lineLimit: 1
                    )
                }
                if channel.isLocal {
                    TribuneruText(
                        content: L10n.tr("In your country"),
                        style: .vaporFeedTag,
                        color: .tribuneru(.tifosiOnAccent),
                        lineLimit: 1
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tribuneru(channel.isLocal ? .tifosiAccent : .tifosiTag))
            )
            .accessibilityElement(children: .combine)
        }
    }

    struct TVFlowLayout: Layout {
        let spacing: CGFloat

        func sizeThatFits(
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout ()
        ) -> CGSize {
            let rows = arrange(
                width: proposal.width ?? .infinity,
                subviews: subviews
            )
            return CGSize(
                width: proposal.width ?? rows.maxWidth,
                height: rows.height
            )
        }

        func placeSubviews(
            in bounds: CGRect,
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout ()
        ) {
            let rows = arrange(
                width: bounds.width,
                subviews: subviews
            )
            for item in rows.items {
                subviews[item.index].place(
                    at: CGPoint(
                        x: bounds.minX + item.origin.x,
                        y: bounds.minY + item.origin.y
                    ),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }

        private struct Item {
            let index: Int
            let origin: CGPoint
            let size: CGSize
        }

        private func arrange(
            width: CGFloat,
            subviews: Subviews
        ) -> (items: [Item], height: CGFloat, maxWidth: CGFloat) {
            var items: [Item] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            var maxWidth: CGFloat = 0
            for index in subviews.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                if x > 0 && x + size.width > width {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                items.append(Item(index: index, origin: CGPoint(x: x, y: y), size: size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
                maxWidth = max(maxWidth, x - spacing)
            }
            return (items, y + rowHeight, maxWidth)
        }
    }
}
