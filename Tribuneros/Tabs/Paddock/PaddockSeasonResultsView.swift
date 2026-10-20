//
//  PaddockSeasonResultsView.swift
//  Tribuneros
//
//  A rider's whole current-season table (route `paddockSeasonResults`), Kit look. Stage rows are
//  indented under their race; rows aren't tappable (a race page would be a PCS web view).
//

import SwiftUI

extension Paddock {

    struct SeasonResultsView: View {
        let context: SeasonResultsContext

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        TribuneruText(
                            content: context.riderName,
                            style: .vaporSectionTitle,
                            color: .tribuneru(.kitTextPrimary),
                            lineLimit: 2
                        )
                        TribuneruText(
                            content: L10n.tr("%lld RESULTS", context.rows.count),
                            style: .vaporMonoMeta,
                            color: .tribuneru(.kitTextSecondary),
                            lineLimit: 1
                        )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("paddock.seasonResults.header")
                    RiderCardBox(look: .kit) {
                        ForEach(Array(context.rows.enumerated()), id: \.element.id) { index, row in
                            if index > 0 {
                                RiderDivider(look: .kit)
                            }
                            SeasonResultRowView(row: row)
                        }
                    }
                }
                .padding()
                .padding(.bottom, 40)
            }
            .background(RiderLook.kit.page)
            .preferredColorScheme(.dark)
            .navigationTitle(L10n.tr("Season results"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// One race or stage line, shared by the rider screen's preview and the full screen.
    struct SeasonResultRowView: View {
        let row: SeasonResultRow

        var body: some View {
            HStack(spacing: 10) {
                if row.isStage {
                    Color.clear
                        .frame(width: 16)
                }
                TribuneruText(
                    content: row.result,
                    style: .vaporFinishTime,
                    color: row.result == "1" ? RiderLook.kit.page : RiderLook.kit.primary,
                    lineLimit: 1
                )
                .frame(width: 34, height: 30)
                .background(row.result == "1" ? RiderLook.kit.accent : RiderLook.kit.raised)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: row.race,
                        style: row.isStage ? .vaporMeta : .vaporRaceNameResult,
                        color: row.isStage ? RiderLook.kit.secondary : RiderLook.kit.primary,
                        lineLimit: 2
                    )
                    TribuneruText(
                        content: meta,
                        style: .vaporMonoMeta,
                        color: RiderLook.kit.secondary,
                        lineLimit: 1
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        }

        private var meta: String {
            [row.date, row.raceClass, row.distance, row.points.map { L10n.tr("%@ pts", $0) }]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
    }
}
