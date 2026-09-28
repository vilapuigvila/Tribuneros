//
//  Paddock.Subviews.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import SwiftUI

// MARK: - Press -

extension Paddock {

    struct PressPanel: View {
        let items: [PressItem]
        let onTap: (URL) -> Void

        var body: some View {
            VaporPanel(panelColor: .tribuneru(.vaporPanelToday)) {
                VaporSectionHeader(title: "The press") {
                    TribuneruText(
                        content: items.count == 1 ? "1 site" : "\(items.count) sites",
                        style: .vaporScreenDate,
                        color: .tribuneru(.vaporTextSecondary)
                    )
                    .padding(.top, 12)
                }
            } content: {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(items) { item in
                            Button {
                                onTap(item.url)
                            } label: {
                                PressCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
    }

    private struct PressCard: View {
        let item: PressItem

        var body: some View {
            VaporCard(spacing: 12) {
                HStack {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.tribuneru(.vaporAccent))
                        .frame(width: 30, height: 30)
                        .background(Color.tribuneru(.vaporAccent).opacity(0.12))
                        .cornerRadius(6)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.tribuneru(.vaporTextSecondary))
                }
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: item.name,
                        style: .vaporPressName,
                        color: .tribuneru(.vaporTextPrimary),
                        lineLimit: 2
                    )
                    if let domain = item.domain {
                        TribuneruText(
                            content: domain,
                            style: .vaporMonoMeta,
                            color: .tribuneru(.vaporTextSecondary)
                        )
                    }
                }
                .frame(minHeight: 50, alignment: .topLeading)
            }
            .frame(width: 140)
        }
    }
}

// MARK: - Feed -

extension Paddock {

    struct FeedPanel: View {
        let filter: Filter
        let feed: Feed
        let action: (Action) -> Void

        var body: some View {
            VaporPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
                VaporSectionHeader(
                    title: "Paddock",
                    showsLiveDot: true
                )
            } content: {
                VStack(alignment: .leading, spacing: 16) {
                    FilterChips(selected: filter) {
                        action(.didSelectFilter($0))
                    }
                    content
                }
            }
        }

        @ViewBuilder
        private var content: some View {
            switch feed {
            case .loading:
                LoaderView(title: "Loading the paddock…")
            case .empty:
                message("Nothing new in the paddock.")
            case .error:
                VStack(alignment: .leading, spacing: 12) {
                    message("Couldn't load the paddock from ProCyclingStats.")
                    Button {
                        action(.didRequestRefresh)
                    } label: {
                        ChipLabel(
                            title: "Try again",
                            isSelected: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            case .loaded(let sections):
                if sections.isEmpty {
                    message("Nothing here for this filter.")
                } else {
                    ForEach(sections) { section in
                        FeedSectionView(section: section) {
                            action(.didTapOnLink($0))
                        }
                    }
                }
            }
        }

        private func message(_ text: String) -> some View {
            TribuneruText(
                content: text,
                style: .vaporMeta,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 2
            )
        }
    }

    private struct FilterChips: View {
        let selected: Filter
        let onSelect: (Filter) -> Void

        var body: some View {
            HStack(spacing: 6) {
                ForEach(Filter.allCases, id: \.self) { filter in
                    Button {
                        onSelect(filter)
                    } label: {
                        ChipLabel(
                            title: filter.title,
                            isSelected: filter == selected
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private struct ChipLabel: View {
        let title: String
        let isSelected: Bool

        var body: some View {
            let color: Color = isSelected ? .tribuneru(.vaporAccent) : .tribuneru(.vaporTextSecondary)
            TribuneruText(
                content: title,
                style: .vaporSpoilerChip,
                color: color
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(Color.tribuneru(.vaporAccent).opacity(isSelected ? 0.08 : 0))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(color, lineWidth: 0.5)
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
    }

    private struct FeedSectionView: View {
        let section: Section
        let onTap: (URL?) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                TribuneruText(
                    content: section.title.uppercased(),
                    style: .vaporGroupLabel,
                    color: .tribuneru(.vaporTextSecondary)
                )
                ForEach(section.cards) { card in
                    switch card {
                    case .transfer(let transfer):
                        TransferCardView(
                            card: transfer,
                            onTap: onTap
                        )
                    case .program(let program):
                        ProgramCardView(
                            card: program,
                            onTap: onTap
                        )
                    case .birthdays(let birthdays):
                        BirthdaysCardView(
                            card: birthdays,
                            onTap: onTap
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Feed cards -

extension Paddock {

    private struct TransferCardView: View {
        let card: TransferCard
        let onTap: (URL?) -> Void

        var body: some View {
            Button {
                onTap(card.rider.url)
            } label: {
                VaporCard(spacing: 8) {
                    Kicker(
                        tag: "TRANSFER",
                        tagColor: .tribuneru(.vaporTextSecondary),
                        time: card.date
                    )
                    RiderLine(rider: card.rider)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.tribuneru(.vaporAccent))
                        TribuneruText(
                            content: card.teamName,
                            style: .vaporFeedDetail,
                            color: .tribuneru(.vaporTextPrimary).opacity(0.72)
                        )
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private struct ProgramCardView: View {
        let card: ProgramCard
        let onTap: (URL?) -> Void

        var body: some View {
            Button {
                onTap(card.rider.url)
            } label: {
                VaporCard(spacing: 8) {
                    Kicker(
                        tag: "PROGRAM",
                        tagColor: .tribuneru(.vaporAccent),
                        time: card.timeAgo
                    )
                    RiderLine(rider: card.rider)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(card.changes.enumerated()), id: \.offset) { _, change in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                TribuneruText(
                                    content: change.isAdded ? "+" : "−",
                                    style: .vaporChangeSign,
                                    color: change.isAdded ? .tribuneru(.vaporLive) : .tribuneru(.vaporNegative)
                                )
                                .frame(width: 10, alignment: .leading)
                                .accessibilityLabel(change.isAdded ? "Added" : "Dropped")
                                TribuneruText(
                                    content: change.raceName,
                                    style: .vaporFeedDetail,
                                    color: .tribuneru(.vaporTextPrimary).opacity(0.72),
                                    lineLimit: 2
                                )
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private struct BirthdaysCardView: View {
        let card: BirthdaysCard
        let onTap: (URL?) -> Void

        var body: some View {
            VaporCard(spacing: 10) {
                Kicker(
                    tag: "BIRTHDAYS",
                    tagColor: .tribuneru(.vaporTextSecondary),
                    time: "today"
                )
                ForEach(Array(card.entries.enumerated()), id: \.offset) { _, entry in
                    Button {
                        onTap(entry.rider.url)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 7) {
                            RiderLine(rider: entry.rider)
                            Spacer(minLength: 8)
                            TribuneruText(
                                content: "turns",
                                style: .vaporMeta,
                                color: .tribuneru(.vaporTextSecondary)
                            )
                            TribuneruText(
                                content: entry.age,
                                style: .vaporAge,
                                color: .tribuneru(.vaporTextPrimary)
                            )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private struct Kicker: View {
        let tag: String
        let tagColor: Color
        let time: String

        var body: some View {
            HStack(alignment: .firstTextBaseline) {
                TribuneruText(
                    content: tag,
                    style: .vaporFeedTag,
                    color: tagColor
                )
                Spacer(minLength: 8)
                TribuneruText(
                    content: time,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.vaporTextSecondary)
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
                    style: .vaporWinnerName,
                    color: .tribuneru(.vaporTextPrimary)
                )
            }
        }
    }
}
