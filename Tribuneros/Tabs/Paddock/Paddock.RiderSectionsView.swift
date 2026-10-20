//
//  Paddock.RiderSectionsView.swift
//  Tribuneros
//
//  The Paddock rider screen's sections drawn from the PCS page (`Paddock.RiderSections`), Kit
//  look. Each one is hidden when it has no rows.
//

import SwiftUI

extension Paddock {

    struct RiderSectionsView: View {
        let sections: RiderSections
        let riderName: String
        let openSeasonResults: (SeasonResultsContext) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 26) {
                if !sections.specialties.isEmpty {
                    panel(
                        title: L10n.tr("Specialties"),
                        id: "specialties"
                    ) {
                        RiderCardBox(look: .kit) {
                            ForEach(Array(sections.specialties.enumerated()), id: \.offset) { index, item in
                                if index > 0 {
                                    RiderDivider(look: .kit)
                                }
                                specialty(item)
                            }
                        }
                    }
                }
                if !sections.keyStats.isEmpty {
                    panel(
                        title: L10n.tr("Key statistics"),
                        id: "keyStats"
                    ) {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                            spacing: 10
                        ) {
                            ForEach(Array(sections.keyStats.enumerated()), id: \.offset) { _, stat in
                                keyStat(stat)
                            }
                        }
                    }
                }
                if !sections.topResults.isEmpty {
                    panel(
                        title: L10n.tr("Top results"),
                        id: "topResults"
                    ) {
                        RiderCardBox(look: .kit) {
                            ForEach(Array(sections.topResults.enumerated()), id: \.offset) { index, item in
                                if index > 0 {
                                    RiderDivider(look: .kit)
                                }
                                topResult(item)
                            }
                        }
                    }
                }
                if !sections.program.isEmpty {
                    panel(
                        title: L10n.tr("Program"),
                        id: "program"
                    ) {
                        RiderCardBox(look: .kit) {
                            ForEach(Array(sections.program.enumerated()), id: \.offset) { index, item in
                                if index > 0 {
                                    RiderDivider(look: .kit)
                                }
                                programRace(item)
                            }
                        }
                    }
                }
                if !sections.teams.isEmpty {
                    panel(
                        title: L10n.tr("Teams"),
                        id: "teams"
                    ) {
                        RiderCardBox(look: .kit) {
                            ForEach(Array(sections.teams.enumerated()), id: \.offset) { index, item in
                                if index > 0 {
                                    RiderDivider(look: .kit)
                                }
                                team(item)
                            }
                        }
                    }
                }
                if !sections.ranking.isEmpty {
                    panel(
                        title: L10n.tr("PCS ranking"),
                        id: "ranking"
                    ) {
                        RiderCardBox(look: .kit) {
                            ForEach(Array(sections.ranking.enumerated()), id: \.offset) { index, item in
                                if index > 0 {
                                    RiderDivider(look: .kit)
                                }
                                ranking(item)
                            }
                        }
                    }
                }
                if !sections.seasonResults.isEmpty {
                    panel(
                        title: L10n.tr("Season results"),
                        id: "seasonResults"
                    ) {
                        VStack(spacing: 10) {
                            if !sections.seasonPreview.isEmpty {
                                RiderCardBox(look: .kit) {
                                    ForEach(Array(sections.seasonPreview.enumerated()), id: \.element.id) { index, row in
                                        if index > 0 {
                                            RiderDivider(look: .kit)
                                        }
                                        SeasonResultRowView(row: row)
                                    }
                                }
                            }
                            Button {
                                openSeasonResults(
                                    SeasonResultsContext(
                                        riderName: riderName,
                                        rows: sections.seasonResults
                                    )
                                )
                            } label: {
                                RiderPageLink(
                                    look: .kit,
                                    title: L10n.tr("Season results")
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("paddock.rider.seasonResultsLink")
                        }
                    }
                }
            }
        }

        private func panel<Content: View>(
            title: String,
            id: String,
            @ViewBuilder content: @escaping () -> Content
        ) -> some View {
            RiderPanel(
                look: .kit,
                title: title,
                content: content
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("paddock.rider.\(id)")
        }

        private func specialty(_ item: RiderSections.Specialty) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TribuneruText(
                        content: item.title,
                        style: .vaporRaceNameResult,
                        color: RiderLook.kit.primary,
                        lineLimit: 1
                    )
                    Spacer(minLength: 8)
                    TribuneruText(
                        content: "\(item.points)",
                        style: .vaporFinishTime,
                        color: RiderLook.kit.accent,
                        lineLimit: 1
                    )
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(RiderLook.kit.raised)
                        Capsule()
                            .fill(RiderLook.kit.accent)
                            .frame(width: max(4, proxy.size.width * item.fraction))
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
        }

        private func keyStat(_ stat: RiderSections.KeyStat) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                TribuneruText(
                    content: stat.value,
                    style: .vaporStatTime,
                    color: RiderLook.kit.accent,
                    lineLimit: 1
                )
                TribuneruText(
                    content: stat.title,
                    style: .vaporGroupLabel,
                    color: RiderLook.kit.secondary,
                    lineLimit: 2
                )
                if let detail = stat.detail, !detail.isEmpty {
                    TribuneruText(
                        content: detail,
                        style: .vaporMonoMeta,
                        color: RiderLook.kit.secondary,
                        lineLimit: 2
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .riderCard(
                .kit,
                cornerRadius: 14
            )
            .accessibilityElement(children: .combine)
        }

        private func topResult(_ item: RiderSections.TopResult) -> some View {
            HStack(spacing: 10) {
                TribuneruText(
                    content: item.count,
                    style: .vaporFinishTime,
                    color: RiderLook.kit.accent,
                    lineLimit: 1
                )
                .frame(width: 40, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: item.race,
                        style: .vaporRaceNameResult,
                        color: RiderLook.kit.primary,
                        lineLimit: 2
                    )
                    let meta = [item.kind, item.years].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                    if !meta.isEmpty {
                        TribuneruText(
                            content: meta,
                            style: .vaporMonoMeta,
                            color: RiderLook.kit.secondary,
                            lineLimit: 2
                        )
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        }

        private func programRace(_ item: RiderSections.ProgramRace) -> some View {
            HStack(spacing: 10) {
                TribuneruText(
                    content: item.date,
                    style: .vaporMonoMeta,
                    color: RiderLook.kit.accent,
                    lineLimit: 1
                )
                .frame(width: 48, alignment: .leading)
                if let code = item.countryCode, !code.isEmpty {
                    VaporFlagView(countryCode: code)
                }
                TribuneruText(
                    content: item.race,
                    style: .vaporRaceNameResult,
                    color: RiderLook.kit.primary,
                    lineLimit: 2
                )
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
        }

        private func team(_ item: RiderSections.Team) -> some View {
            HStack(spacing: 10) {
                TribuneruText(
                    content: item.season,
                    style: .vaporMonoMeta,
                    color: RiderLook.kit.accent,
                    lineLimit: 1
                )
                .frame(width: 48, alignment: .leading)
                TribuneruText(
                    content: item.team,
                    style: .vaporRaceNameResult,
                    color: RiderLook.kit.primary,
                    lineLimit: 2
                )
                Spacer(minLength: 8)
                if let level = item.level, !level.isEmpty {
                    TribuneruText(
                        content: level,
                        style: .vaporMonoMeta,
                        color: RiderLook.kit.secondary,
                        lineLimit: 1
                    )
                }
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
        }

        private func ranking(_ item: RiderSections.Ranking) -> some View {
            HStack(spacing: 10) {
                TribuneruText(
                    content: item.season,
                    style: .vaporMonoMeta,
                    color: RiderLook.kit.accent,
                    lineLimit: 1
                )
                .frame(width: 48, alignment: .leading)
                TribuneruText(
                    content: L10n.tr("%@ pts", item.points),
                    style: .vaporRaceNameResult,
                    color: RiderLook.kit.primary,
                    lineLimit: 1
                )
                Spacer(minLength: 8)
                TribuneruText(
                    content: "#\(item.rank)",
                    style: .vaporFinishTime,
                    color: RiderLook.kit.primary,
                    lineLimit: 1
                )
            }
            .padding(.vertical, 10)
            .accessibilityElement(children: .combine)
        }
    }
}
