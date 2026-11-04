//
//  Paddock.DirectorySection.swift
//  Tribuneros
//
//  The Races | Teams section (Kit look): a segmented control over at most three rows and a
//  "See all" button that pushes the whole PCS list (routes `paddockRaces` / `paddockTeams`).
//  Rows aren't tappable: there is no native race or team screen yet and no Paddock tap opens a web view.
//

import SwiftUI

extension Paddock {

    struct DirectorySection: View {
        let races: Listing<RaceItem>
        let teams: Listing<TeamItem>
        let action: (Action) -> Void

        /// View-local, like the Settings language sheet: it never leaves the screen.
        @State private var selected: Directory = .races

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                DirectoryControl(selected: $selected)
                VStack(spacing: 0) {
                    switch selected {
                    case .races:
                        racesBody
                    case .teams:
                        teamsBody
                    }
                }
                .kitCard()
            }
            .accessibilityIdentifier("paddock.directory")
        }

        // MARK: Races

        @ViewBuilder
        private var racesBody: some View {
            switch races {
            case .loading:
                RaceRows(races: RaceItem.placeholders)
                    .redacted(reason: .placeholder)
                    .shimmering()
                    .disabled(true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.tr("Loading the races"))
            case .failed:
                failure(L10n.tr("Couldn't load the races from ProCyclingStats."))
            case .loaded(let all):
                if all.isEmpty {
                    failure(L10n.tr("No races right now."), retry: false)
                } else {
                    RaceRows(races: Paddock.previewRaces(all))
                    seeAll(Directory.races.seeAllTitle, id: "paddock.directory.seeAllRaces") {
                        action(.didTapOnAllRaces)
                    }
                }
            }
        }

        // MARK: Teams

        @ViewBuilder
        private var teamsBody: some View {
            switch teams {
            case .loading:
                TeamRows(teams: TeamItem.placeholders)
                    .redacted(reason: .placeholder)
                    .shimmering()
                    .disabled(true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.tr("Loading the teams"))
            case .failed:
                failure(L10n.tr("Couldn't load the teams from ProCyclingStats."))
            case .loaded(let all):
                if all.isEmpty {
                    failure(L10n.tr("No teams right now."), retry: false)
                } else {
                    TeamRows(teams: Array(all.prefix(Paddock.directoryPreviewLimit)))
                    seeAll(Directory.teams.seeAllTitle, id: "paddock.directory.seeAllTeams") {
                        action(.didTapOnAllTeams)
                    }
                }
            }
        }

        // MARK: Pieces

        private func seeAll(
            _ title: String,
            id: String,
            onTap: @escaping () -> Void
        ) -> some View {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    TribuneruText(
                        content: title,
                        style: .vaporSeeAll,
                        color: .tribuneru(.kitAccent),
                        lineLimit: 1
                    )
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.tribuneru(.kitAccent))
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.tribuneru(.kitAvatar))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
        }

        private func failure(
            _ text: String,
            retry: Bool = true
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                TribuneruText(
                    content: text,
                    style: .vaporMeta,
                    color: .tribuneru(.kitTextSecondary),
                    lineLimit: 2
                )
                if retry {
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
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct DirectoryControl: View {
        @Binding var selected: Directory

        var body: some View {
            HStack(spacing: 4) {
                ForEach(Directory.allCases, id: \.self) { directory in
                    let isSelected = directory == selected
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        selected = directory
                    } label: {
                        TribuneruText(
                            content: directory.title,
                            style: .vaporLink,
                            color: .tribuneru(isSelected ? .kitTextPrimary : .kitTextSecondary),
                            lineLimit: 1
                        )
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.tribuneru(.kitSegmentSelected) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("paddock.directory.\(directory == .races ? "races" : "teams")")
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
            .animation(.easeOut(duration: 0.2), value: selected)
        }
    }

    // MARK: - Rows (shared by the section and the full lists) -

    struct RaceRows: View {
        let races: [RaceItem]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(Array(races.enumerated()), id: \.element.id) { index, race in
                    if index > 0 {
                        RiderDivider(look: .kit)
                    }
                    RaceRowView(race: race)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    struct RaceRowView: View {
        let race: RaceItem

        var body: some View {
            HStack(spacing: 12) {
                TribuneruText(
                    content: race.dateLabel,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.kitProgram),
                    lineLimit: 1
                )
                .frame(width: 56, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: race.name,
                        style: .vaporRowTitle,
                        color: .tribuneru(.kitTextPrimary),
                        lineLimit: 2
                    )
                    if !race.raceClass.isEmpty {
                        TribuneruText(
                            content: race.raceClass,
                            style: .vaporMonoMeta,
                            color: .tribuneru(.kitTextSecondary),
                            lineLimit: 1
                        )
                    }
                }
                Spacer(minLength: 8)
                if !race.countryCode.isEmpty {
                    VaporFlagView(countryCode: race.countryCode)
                }
            }
            .frame(minHeight: 56)
            .accessibilityElement(children: .combine)
        }
    }

    struct TeamRows: View {
        let teams: [TeamItem]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(Array(teams.enumerated()), id: \.element.id) { index, team in
                    if index > 0 {
                        RiderDivider(look: .kit)
                    }
                    TeamRowView(team: team)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    struct TeamRowView: View {
        let team: TeamItem

        var body: some View {
            HStack(spacing: 12) {
                TribuneruText(
                    content: team.monogram,
                    style: .vaporMonoMeta,
                    color: .tribuneru(.kitAvatarText),
                    lineLimit: 1
                )
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.tribuneru(.kitAvatar)))
                TribuneruText(
                    content: team.name,
                    style: .vaporRowTitle,
                    color: .tribuneru(.kitTextPrimary),
                    lineLimit: 2
                )
                Spacer(minLength: 8)
                if !team.division.isEmpty {
                    TribuneruText(
                        content: team.division,
                        style: .vaporMonoMeta,
                        color: .tribuneru(.kitTextSecondary),
                        lineLimit: 1
                    )
                }
                if !team.countryCode.isEmpty {
                    VaporFlagView(countryCode: team.countryCode)
                }
            }
            .frame(minHeight: 56)
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Full lists (pushed) -

    struct RacesListView: View {
        /// The men's calendar, from the Paddock screen's own state; the women's one is loaded here on demand.
        let races: Listing<RaceItem>
        @StateObject private var model = RacesListModel()

        var body: some View {
            let listing = model.circuit == .men ? races : model.women
            DirectoryListScreen(
                title: L10n.tr("Races"),
                countLabel: L10n.tr("%lld RACES", listing.items.count),
                loading: listing == .loading
            ) {
                RaceCircuitControl(
                    selected: model.circuit,
                    onSelect: model.select
                )
            } rows: {
                rows(for: listing)
            } placeholders: {
                RaceListRows(races: RaceItem.placeholders)
            }
            .accessibilityIdentifier("paddock.racesList")
        }

        @ViewBuilder
        private func rows(for listing: Listing<RaceItem>) -> some View {
            switch listing {
            case .loading:
                RaceListRows(races: RaceItem.placeholders)
            case .failed:
                message(
                    L10n.tr("Couldn't load the races from ProCyclingStats."),
                    retry: model.circuit == .women
                )
            case .loaded(let items):
                if items.isEmpty {
                    message(L10n.tr("No races right now."), retry: false)
                } else {
                    RaceListRows(races: items)
                }
            }
        }

        private func message(
            _ text: String,
            retry: Bool
        ) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                TribuneruText(
                    content: text,
                    style: .vaporMeta,
                    color: .tribuneru(.kitTextSecondary),
                    lineLimit: 2
                )
                if retry {
                    Button {
                        model.loadWomen()
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
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Men | Women switch of the pushed races list, drawn like the section's Races | Teams control.
    private struct RaceCircuitControl: View {
        let selected: RaceCircuit
        let onSelect: (RaceCircuit) -> Void

        var body: some View {
            HStack(spacing: 4) {
                ForEach(RaceCircuit.allCases, id: \.self) { circuit in
                    let isSelected = circuit == selected
                    Button {
                        guard !isSelected else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        onSelect(circuit)
                    } label: {
                        TribuneruText(
                            content: circuit.title,
                            style: .vaporLink,
                            color: .tribuneru(isSelected ? .kitTextPrimary : .kitTextSecondary),
                            lineLimit: 1
                        )
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Color.tribuneru(.kitSegmentSelected) : .clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("paddock.racesList.\(circuit == .men ? "men" : "women")")
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
            .animation(.easeOut(duration: 0.2), value: selected)
        }
    }

    /// The pushed list's rows: taller than the section's preview, with the end date of a stage race and the season.
    struct RaceListRows: View {
        let races: [RaceItem]

        var body: some View {
            VStack(spacing: 0) {
                ForEach(Array(races.enumerated()), id: \.element.id) { index, race in
                    if index > 0 {
                        RiderDivider(look: .kit)
                    }
                    RaceListRowView(race: race)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    struct RaceListRowView: View {
        let race: RaceItem

        /// "2.UWT · 2027", whichever parts are known.
        private var meta: String {
            [race.raceClass, race.season.map(String.init) ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }

        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: race.dateLabel,
                        style: .vaporMonoMeta,
                        color: .tribuneru(.kitProgram),
                        lineLimit: 1
                    )
                    if let end = race.endLabel {
                        TribuneruText(
                            content: "– \(end)",
                            style: .vaporMonoMeta,
                            color: .tribuneru(.kitTextSecondary),
                            lineLimit: 1
                        )
                    }
                }
                .frame(width: 64, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    TribuneruText(
                        content: race.name,
                        style: .vaporRowTitle,
                        color: .tribuneru(.kitTextPrimary),
                        lineLimit: 2
                    )
                    if !meta.isEmpty {
                        TribuneruText(
                            content: meta,
                            style: .vaporMonoMeta,
                            color: .tribuneru(.kitTextSecondary),
                            lineLimit: 1
                        )
                    }
                }
                Spacer(minLength: 8)
                if !race.countryCode.isEmpty {
                    VaporFlagView(countryCode: race.countryCode)
                }
            }
            .padding(.vertical, 12)
            .frame(minHeight: 88)
            .accessibilityElement(children: .combine)
        }
    }

    struct TeamsListView: View {
        let teams: Listing<TeamItem>

        var body: some View {
            DirectoryListScreen(
                title: L10n.tr("Teams"),
                countLabel: L10n.tr("%lld TEAMS", teams.items.count),
                loading: teams == .loading
            ) {
                EmptyView()
            } rows: {
                TeamRows(teams: teams.items)
            } placeholders: {
                TeamRows(teams: TeamItem.placeholders)
            }
            .accessibilityIdentifier("paddock.teamsList")
        }
    }

    private struct DirectoryListScreen<Accessory: View, Rows: View, Placeholders: View>: View {
        let title: String
        let countLabel: String
        let loading: Bool
        /// Sits between the title and the card (the races list's Men | Women switch).
        @ViewBuilder let accessory: () -> Accessory
        @ViewBuilder let rows: () -> Rows
        @ViewBuilder let placeholders: () -> Placeholders

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        TribuneruText(
                            content: title,
                            style: .vaporSectionTitle,
                            color: .tribuneru(.kitTextPrimary),
                            lineLimit: 1
                        )
                        if !loading {
                            TribuneruText(
                                content: countLabel,
                                style: .vaporMonoMeta,
                                color: .tribuneru(.kitTextSecondary),
                                lineLimit: 1
                            )
                        }
                    }
                    .accessibilityElement(children: .combine)
                    accessory()
                    VStack(spacing: 0) {
                        if loading {
                            placeholders()
                                .redacted(reason: .placeholder)
                                .shimmering()
                                .disabled(true)
                        } else {
                            rows()
                        }
                    }
                    .kitCard()
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(Color.tribuneru(.kitPageBackground))
            .preferredColorScheme(.dark)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
