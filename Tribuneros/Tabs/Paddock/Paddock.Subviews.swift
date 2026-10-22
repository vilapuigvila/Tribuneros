//
//  Paddock.Subviews.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import SwiftUI

extension View {
    func kitCard(cornerRadius: CGFloat = 20) -> some View {
        background(Color.tribuneru(.kitCardSurface))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        Color.tribuneru(.kitTextPrimary).opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Header -

extension Paddock {

    struct Header: View {
        let date: Date

        var body: some View {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "megaphone")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundColor(.tribuneru(.kitTextPrimary))
                    TribuneruText(
                        content: L10n.tr("Paddock"),
                        style: .vaporSectionTitle,
                        color: .tribuneru(.kitTextPrimary),
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
                TribuneruText(
                    content: L10n.dateFormatter(template: "EEEddMMM").string(from: date),
                    style: .vaporScreenDate,
                    color: .tribuneru(.kitTextSecondary),
                    lineLimit: 1
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("paddock.header")
        }
    }
}

// MARK: - Press -

extension Paddock {

    /// The press sites as big circles: three in view and the edge of a fourth, so the row reads as scrollable.
    struct PressStrip: View {
        private enum Sizes {
            static let circle: CGFloat = 92
            static let width: CGFloat = 98
        }

        let items: [PressItem]
        let onTap: (PressItem) -> Void

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(items) { item in
                        Button {
                            onTap(item)
                        } label: {
                            bubble(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(item.name)
                        .accessibilityAddTraits(.isLink)
                        .accessibilityIdentifier("paddock.press.\(item.url.host ?? item.name)")
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
            .accessibilityLabel(L10n.tr("The press"))
        }

        private func bubble(_ item: PressItem) -> some View {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.tribuneru(.kitAvatar))
                    .overlay(
                        TribuneruText(
                            content: item.monogram,
                            style: .vaporHeading,
                            color: .tribuneru(.kitAvatarText),
                            lineLimit: 1
                        )
                    )
                    .padding(4)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.tribuneru(.kitAccent), lineWidth: 2.5)
                    )
                    .frame(width: Sizes.circle, height: Sizes.circle)
                TribuneruText(
                    content: item.name,
                    style: .vaporPressName,
                    color: .tribuneru(.kitAvatarText),
                    lineLimit: 1
                )
            }
            .frame(width: Sizes.width)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Section scaffolding -

extension Paddock {

    struct KitSection<Trailing: View, Content: View>: View {
        let title: String
        @ViewBuilder let trailing: () -> Trailing
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    TribuneruText(
                        content: title,
                        style: .vaporHeading,
                        color: .tribuneru(.kitTextPrimary),
                        lineLimit: 1
                    )
                    Spacer(minLength: 0)
                    trailing()
                }
                .frame(minHeight: 44)
                content()
            }
        }
    }
}

// MARK: - Birthdays -

extension Paddock {

    struct BirthdaysSection: View {
        let entries: [BirthdaysCard.Entry]
        let all: [BirthdaysCard.Entry]
        let onTap: (BirthdaysCard.Entry) -> Void

        @State private var showsMore = false
        @State private var pendingEntry: BirthdaysCard.Entry?

        var body: some View {
            KitSection(title: L10n.tr("Birthdays today")) {
                TribuneruText(
                    content: L10n.tr("%lld riders", all.count),
                    style: .vaporMonoMeta,
                    color: .tribuneru(.kitTextSecondary),
                    lineLimit: 1
                )
            } content: {
                VStack(spacing: 0) {
                    PaddockBirthdayArt()
                        .frame(height: 120)
                        .clipped()
                    VStack(spacing: 0) {
                        rows(entries, idPrefix: "paddock.birthday") { onTap($0) }
                        if all.count > entries.count {
                            divider
                            moreButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .kitCard()
            }
            // Push only once the sheet is gone, so the rider screen lands on the Paddock stack.
            .sheet(
                isPresented: $showsMore,
                onDismiss: {
                    guard let entry = pendingEntry else { return }
                    pendingEntry = nil
                    onTap(entry)
                }
            ) {
                moreSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                    .presentationBackground(Color.tribuneru(.kitPageBackground))
                    .preferredColorScheme(.dark)
            }
        }

        private var divider: some View {
            TribunerosDivider(
                height: 0.5,
                color: Color.tribuneru(.kitTextPrimary).opacity(0.08)
            )
        }

        private func rows(
            _ entries: [BirthdaysCard.Entry],
            idPrefix: String,
            onTap: @escaping (BirthdaysCard.Entry) -> Void
        ) -> some View {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                if index > 0 {
                    divider
                }
                Button {
                    onTap(entry)
                } label: {
                    row(entry)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(idPrefix).\(index)")
            }
        }

        private var moreButton: some View {
            Button {
                showsMore = true
            } label: {
                HStack(spacing: 6) {
                    TribuneruText(
                        content: L10n.tr("See all %lld birthdays", all.count),
                        style: .vaporSeeAll,
                        color: .tribuneru(.kitAccent),
                        lineLimit: 1
                    )
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.tribuneru(.kitAccent))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paddock.birthday.more")
        }

        private var moreSheet: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TribuneruText(
                        content: L10n.tr("Birthdays today"),
                        style: .vaporHeading,
                        color: .tribuneru(.kitTextPrimary),
                        lineLimit: 1
                    )
                    .padding(.top, 20)
                    VStack(spacing: 0) {
                        rows(all, idPrefix: "paddock.birthday.sheet") { entry in
                            pendingEntry = entry
                            showsMore = false
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .kitCard()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .accessibilityIdentifier("paddock.birthday.sheet")
        }

        private func row(_ entry: BirthdaysCard.Entry) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RiderLine(rider: entry.rider)
                Spacer(minLength: 8)
                TribuneruText(
                    content: L10n.tr("turns"),
                    style: .vaporRowMeta,
                    color: .tribuneru(.kitTextSecondary)
                )
                TribuneruText(
                    content: entry.age,
                    style: .vaporRowTime,
                    color: .tribuneru(.kitAccent)
                )
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Moves -

extension Paddock {

    struct MovesSection: View {
        let state: ViewState
        let action: (Action) -> Void

        var body: some View {
            KitSection(title: L10n.tr("Moves")) {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 14) {
                    SegmentedControl(state: state) {
                        action(.didSelectFilter($0.filter))
                    }
                    content
                }
            }
        }

        @ViewBuilder
        private var content: some View {
            switch state.feed {
            case .loading:
                Timeline(
                    sections: Section.placeholders(for: state.segment),
                    action: { _ in }
                )
                .redacted(reason: .placeholder)
                .shimmering()
                .disabled(true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.tr("Loading the paddock"))
            case .empty:
                message(L10n.tr("Nothing new in the paddock."))
            case .error:
                VStack(alignment: .leading, spacing: 12) {
                    message(L10n.tr("Couldn't load the paddock from ProCyclingStats."))
                    Button {
                        action(.didRequestRefresh)
                    } label: {
                        TribuneruText(
                            content: L10n.tr("Try again"),
                            style: .vaporSeeAll,
                            color: .tribuneru(.kitAccent)
                        )
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(
                            Capsule().fill(Color.tribuneru(.kitAccent).opacity(0.14))
                        )
                    }
                    .buttonStyle(.plain)
                }
            case .loaded(let sections):
                if sections.isEmpty {
                    message(
                        state.segment == .transfers
                            ? L10n.tr("No transfers right now.")
                            : L10n.tr("No program changes right now.")
                    )
                } else {
                    Timeline(
                        sections: sections,
                        action: action
                    )
                }
            }
        }

        private func message(_ text: String) -> some View {
            TribuneruText(
                content: text,
                style: .vaporMeta,
                color: .tribuneru(.kitTextSecondary),
                lineLimit: 2
            )
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kitCard()
        }
    }

    private struct SegmentedControl: View {
        let state: ViewState
        let onSelect: (Segment) -> Void

        var body: some View {
            HStack(spacing: 4) {
                ForEach(Segment.allCases, id: \.self) { segment in
                    let isSelected = segment == state.segment
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        onSelect(segment)
                    } label: {
                        HStack(spacing: 8) {
                            TribuneruText(
                                content: segment.title,
                                style: .vaporLink,
                                color: .tribuneru(isSelected ? .kitTextPrimary : .kitTextSecondary),
                                lineLimit: 1
                            )
                            TribuneruText(
                                content: "\(state.count(of: segment))",
                                style: .vaporResultTime,
                                color: Color.tribuneru(isSelected ? .kitTextPrimary : .kitTextSecondary).opacity(0.75),
                                lineLimit: 1
                            )
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.tribuneru(.kitSegmentSelected) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("paddock.segment.\(segment == .transfers ? "transfers" : "programs")")
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.tribuneru(.kitSegmentTrack))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.tribuneru(.kitTextPrimary).opacity(0.08), lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.2), value: state.segment)
        }
    }

    /// Day labels and cards hung on a time rail: the time on the left, a dot, then the card.
    private struct Timeline: View {
        let sections: [Section]
        let action: (Action) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    rail(time: nil, dot: nil) {
                        TribuneruText(
                            content: section.displayTitle.uppercased(with: L10n.locale),
                            style: .vaporTagSmall,
                            color: .tribuneru(.kitTextSecondary)
                        )
                        .padding(.top, 18)
                        .padding(.bottom, 4)
                    }
                    ForEach(section.cards) { card in
                        switch card {
                        case .transfer(let transfer):
                            rail(time: transfer.date, dot: .tribuneru(.kitAccent)) {
                                TransferCardView(card: transfer) {
                                    action(.didTapOnRider(.transfer(transfer)))
                                }
                            }
                        case .program(let program):
                            rail(time: program.timeAgo, dot: .tribuneru(.kitProgram)) {
                                ProgramCardView(card: program) {
                                    action(.didTapOnRider(.program(program)))
                                }
                            }
                        case .birthdays:
                            EmptyView()
                        }
                    }
                }
            }
        }

        private func rail<Content: View>(
            time: String?,
            dot: Color?,
            @ViewBuilder content: () -> Content
        ) -> some View {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    if let dot {
                        TribuneruText(
                            content: time ?? "",
                            style: .vaporMonoMeta,
                            color: .tribuneru(.kitTextSecondary),
                            lineLimit: 1
                        )
                        .padding(.top, 14)
                        Circle()
                            .fill(dot)
                            .frame(width: 10, height: 10)
                        Rectangle()
                            .fill(Color.tribuneru(.kitRail))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(width: 44)
                .accessibilityHidden(true)
                content()
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Feed cards -

extension Paddock {

    private struct TransferCardView: View {
        let card: TransferCard
        let onTap: () -> Void

        var body: some View {
            Button {
                onTap()
            } label: {
                CardBody(
                    tag: L10n.tr("TRANSFER"),
                    tagColor: .tribuneru(.kitAccent),
                    rider: card.rider
                ) {
                    ChangeLine(
                        sign: "→",
                        signColor: .tribuneru(.kitAccent),
                        text: card.teamName
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
    }

    private struct ProgramCardView: View {
        let card: ProgramCard
        let onTap: () -> Void

        var body: some View {
            Button {
                onTap()
            } label: {
                CardBody(
                    tag: L10n.tr("PROGRAM"),
                    tagColor: .tribuneru(.kitProgram),
                    rider: card.rider
                ) {
                    ForEach(Array(card.changes.enumerated()), id: \.offset) { _, change in
                        ChangeLine(
                            sign: change.isAdded ? "+" : "−",
                            signColor: .tribuneru(change.isAdded ? .kitAdded : .kitDropped),
                            text: change.raceName,
                            signLabel: change.isAdded ? L10n.tr("Added") : L10n.tr("Dropped")
                        )
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
    }

    private struct CardBody<Lines: View>: View {
        let tag: String
        let tagColor: Color
        let rider: Rider
        @ViewBuilder let lines: () -> Lines

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                TribuneruText(
                    content: tag,
                    style: .vaporTagSmall,
                    color: tagColor
                )
                RiderLine(rider: rider)
                VStack(alignment: .leading, spacing: 4) {
                    lines()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .kitCard(cornerRadius: 18)
            .contentShape(Rectangle())
        }
    }

    private struct ChangeLine: View {
        let sign: String
        let signColor: Color
        let text: String
        var signLabel: String?

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TribuneruText(
                    content: sign,
                    style: .vaporChangeSign,
                    color: signColor
                )
                .frame(width: 12, alignment: .leading)
                .accessibilityLabel(signLabel ?? "")
                .accessibilityHidden(signLabel == nil)
                TribuneruText(
                    content: text,
                    style: .vaporBannerSubtitle,
                    color: .tribuneru(.kitTextMuted),
                    lineLimit: 2
                )
            }
        }
    }

    private struct RiderLine: View {
        let rider: Rider

        var body: some View {
            HStack(spacing: 7) {
                if !rider.countryCode.isEmpty {
                    VaporFlagView(countryCode: rider.countryCode)
                }
                TribuneruText(
                    content: rider.name,
                    style: .vaporResultTitle,
                    color: .tribuneru(.kitTextPrimary),
                    lineLimit: 1
                )
            }
        }
    }
}

// MARK: - Placeholders -

extension Paddock.Section {

    /// The loading timeline for one segment: the feed placeholders with only that segment's cards.
    static func placeholders(for segment: Paddock.Segment) -> [Paddock.Section] {
        placeholders.map { section in
            .init(
                title: section.title,
                cards: section.cards.filter { card in
                    switch (segment, card) {
                    case (.transfers, .transfer), (.programs, .program): true
                    default: false
                    }
                }
            )
        }
    }
}
