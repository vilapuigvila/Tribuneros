//
//  CXRiderSections.swift
//  Tribuneros
//
//  Created by albert vila on 29/9/26.
//

import SwiftUI

// Building blocks shared by the CX rider screens (`CXWinnerDetailView`, `CXRiderDetailView`):
// everything rendered from a rider's cyclocross24 page (`DTO.CXRiderPage`).

extension DTO.CXRiderPage {
    /// A profile fact whose label mentions `keyword`, e.g. "Nationality" or "Team".
    func fact(containing keyword: String) -> String? {
        facts.first { $0.label.lowercased().contains(keyword.lowercased()) }?.value
    }

    var nationality: String? { fact(containing: "nationality") }
    var team: String? { fact(containing: "team") }
}

/// The palette a rider screen draws with: Mud inside the CX tab, Kit inside Paddock.
enum RiderLook {
    case mud
    case kit

    var page: Color {
        switch self {
        case .mud: .tribuneru(.mudPageBackground)
        case .kit: .tribuneru(.kitPageBackground)
        }
    }

    var card: Color {
        switch self {
        case .mud: .tribuneru(.mudCardSurface)
        case .kit: .tribuneru(.kitCardSurface)
        }
    }

    var raised: Color {
        switch self {
        case .mud: .tribuneru(.mudRaised)
        case .kit: .tribuneru(.kitAvatar)
        }
    }

    var primary: Color {
        switch self {
        case .mud: .tribuneru(.mudTextPrimary)
        case .kit: .tribuneru(.kitTextPrimary)
        }
    }

    var secondary: Color {
        switch self {
        case .mud: .tribuneru(.mudTextSecondary)
        case .kit: .tribuneru(.kitTextSecondary)
        }
    }

    var accent: Color {
        switch self {
        case .mud: .tribuneru(.mudAccent)
        case .kit: .tribuneru(.kitAccent)
        }
    }
}

extension View {
    func riderCard(
        _ look: RiderLook,
        cornerRadius: CGFloat = 20
    ) -> some View {
        background(look.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        look.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

/// A section of a rider screen: its title (and an optional trailing accessory), then its content.
struct RiderPanel<Trailing: View, Content: View>: View {
    let look: RiderLook
    let title: String
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                TribuneruText(
                    content: title,
                    style: .vaporHeading,
                    color: look.primary,
                    lineLimit: 1
                )
                Spacer(minLength: 12)
                trailing()
            }
            .frame(minHeight: 32, alignment: .leading)
            content()
        }
    }
}

extension RiderPanel where Trailing == EmptyView {
    init(
        look: RiderLook,
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.look = look
        self.title = title
        self.trailing = { EmptyView() }
        self.content = content
    }
}

/// A rounded card holding stacked rows with 14pt side padding.
struct RiderCardBox<Content: View>: View {
    let look: RiderLook
    var spacing: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riderCard(look)
    }
}

struct RiderDivider: View {
    let look: RiderLook

    var body: some View {
        TribunerosDivider(
            height: 0.5,
            color: look.primary.opacity(0.08)
        )
    }
}

struct RiderChevron: View {
    let look: RiderLook

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(look.secondary)
    }
}

struct RiderTag: View {
    let look: RiderLook
    let title: String
    var isHighlighted = false

    var body: some View {
        switch look {
        case .mud:
            MudTag(
                title: title,
                color: isHighlighted ? .tribuneru(.mudAccent) : .tribuneru(.mudTagNeutralText)
            )
        case .kit:
            CXDetailTag(
                title: title,
                color: isHighlighted ? look.accent : look.secondary
            )
        }
    }
}

/// The identity card at the top of a rider screen: tags, photo, name, country and team. It
/// spans the same width as the panels under it.
struct RiderHeaderCard: View {
    let look: RiderLook
    let tags: [(title: String, isHighlighted: Bool)]
    let avatarURL: URL?
    let name: String
    let flag: VaporFlagView?
    let country: String?
    let team: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                ForEach(tags.indices, id: \.self) { index in
                    RiderTag(
                        look: look,
                        title: tags[index].title,
                        isHighlighted: tags[index].isHighlighted
                    )
                }
            }
            HStack(alignment: .center, spacing: 16) {
                CXRiderAvatar(
                    url: avatarURL,
                    look: look
                )
                VStack(alignment: .leading, spacing: 6) {
                    TribuneruText(
                        content: name,
                        style: .vaporSectionTitle,
                        color: look.primary,
                        lineLimit: 2
                    )
                    if let country {
                        HStack(spacing: 8) {
                            flag
                            TribuneruText(
                                content: country,
                                style: .vaporMeta,
                                color: look.secondary,
                                lineLimit: 1
                            )
                        }
                    }
                    if let team, !team.isEmpty {
                        TribuneruText(
                            content: team,
                            style: .vaporMeta,
                            color: look.secondary,
                            lineLimit: 2
                        )
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riderCard(look)
    }
}

/// The footer link to the rider's page on the source site.
struct RiderPageLink: View {
    let look: RiderLook
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            TribuneruText(
                content: title,
                style: .vaporSeeAll,
                color: look.accent,
                lineLimit: 1
            )
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(look.accent)
        }
        .frame(minHeight: 44)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .riderCard(look)
        .contentShape(Rectangle())
    }
}

/// Round rider photo, or a placeholder until/unless the rider page provides one.
struct CXRiderAvatar: View {
    let url: URL?
    let look: RiderLook

    var body: some View {
        Group {
            if let url {
                CachedImageView(
                    imageUrl: url,
                    cornerRadius: 40
                )
                .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(look.secondary)
            }
        }
        .frame(width: 80, height: 80)
        .background(look.raised)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(look.accent, lineWidth: 1.5)
        )
    }
}

/// Small labelled value box (time, age, points...).
struct CXStatTile: View {
    let label: String
    let value: String
    let look: RiderLook

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TribuneruText(
                content: label.uppercased(with: L10n.locale),
                style: .vaporGroupLabel,
                color: look.secondary,
                lineLimit: 1
            )
            TribuneruText(
                content: value,
                style: .vaporFinishTime,
                color: look.primary,
                lineLimit: 2
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .riderCard(
            look,
            cornerRadius: 14
        )
    }
}

/// "Profile" panel: the label/value facts parsed from the rider page.
struct CXRiderFactsPanel: View {
    let facts: [DTO.CXRiderPage.Fact]
    let look: RiderLook

    var body: some View {
        RiderPanel(
            look: look,
            title: L10n.tr("Profile")
        ) {
            RiderCardBox(look: look) {
                ForEach(facts.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        TribuneruText(
                            content: facts[index].label,
                            style: .vaporMeta,
                            color: look.secondary,
                            lineLimit: 1
                        )
                        .frame(width: 110, alignment: .leading)
                        TribuneruText(
                            content: facts[index].value,
                            style: .vaporRaceNameResult,
                            color: look.primary,
                            lineLimit: 2
                        )
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)

                    if index < facts.count - 1 {
                        RiderDivider(look: look)
                    }
                }
            }
        }
    }
}

/// "Recent results" panel; a row with a race link goes through `openResult` (the view model
/// opens the winner screen for a win, the race detail otherwise).
struct CXRiderRecentResultsPanel: View {
    let results: [DTO.CXRiderPage.Result]
    let look: RiderLook
    let openResult: (DTO.CXRiderPage.Result) -> Void

    var body: some View {
        RiderPanel(
            look: look,
            title: L10n.tr("Recent results")
        ) {
            RiderCardBox(look: look) {
                ForEach(results.indices, id: \.self) { index in
                    let item = results[index]
                    Button {
                        openResult(item)
                    } label: {
                        HStack(spacing: 10) {
                            PositionBadge(
                                position: item.position,
                                look: look
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                TribuneruText(
                                    content: item.race,
                                    style: .vaporRaceNameResult,
                                    color: look.primary,
                                    lineLimit: 1
                                )
                                TribuneruText(
                                    content: item.date,
                                    style: .vaporMonoMeta,
                                    color: look.secondary,
                                    lineLimit: 1
                                )
                            }
                            Spacer(minLength: 0)
                            if item.raceURL != nil {
                                RiderChevron(look: look)
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(item.raceURL == nil)

                    if index < results.count - 1 {
                        RiderDivider(look: look)
                    }
                }
            }
        }
    }
}

/// Finishing position; wins are highlighted in the accent colour.
private struct PositionBadge: View {
    let position: String
    let look: RiderLook

    var body: some View {
        let isWin = position == "1"
        TribuneruText(
            content: position,
            style: .vaporFinishTime,
            color: isWin ? look.page : look.primary,
            lineLimit: 1
        )
        .frame(width: 30, height: 30)
        .background(isWin ? look.accent : look.raised)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
