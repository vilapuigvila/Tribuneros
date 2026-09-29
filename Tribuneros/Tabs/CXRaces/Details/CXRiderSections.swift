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

/// Round rider photo, or a placeholder until/unless the rider page provides one.
struct CXRiderAvatar: View {
    let url: URL?

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
                    .foregroundColor(.tribuneru(.vaporTextSecondary))
            }
        }
        .frame(width: 80, height: 80)
        .background(Color.tribuneru(.vaporCardSurface))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.tribuneru(.vaporAccent), lineWidth: 1.5)
        )
    }
}

/// Small labelled value box (time, age, points...).
struct CXStatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TribuneruText(
                content: label.uppercased(),
                style: .vaporGroupLabel,
                color: .tribuneru(.vaporTextSecondary),
                lineLimit: 1
            )
            TribuneruText(
                content: value,
                style: .vaporFinishTime,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 1
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tribuneru(.vaporCardSurface))
        .cornerRadius(8)
    }
}

/// "Profile" panel: the label/value facts parsed from the rider page.
struct CXRiderFactsPanel: View {
    let facts: [DTO.CXRiderPage.Fact]

    var body: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelYesterday)) {
            VaporSectionHeader(title: "Profile")
        } content: {
            VaporCard(spacing: 0) {
                ForEach(facts.indices, id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        TribuneruText(
                            content: facts[index].label,
                            style: .vaporMeta,
                            color: .tribuneru(.vaporTextSecondary),
                            lineLimit: 1
                        )
                        .frame(width: 110, alignment: .leading)
                        TribuneruText(
                            content: facts[index].value,
                            style: .vaporRaceNameResult,
                            color: .tribuneru(.vaporTextPrimary),
                            lineLimit: 2
                        )
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)

                    if index < facts.count - 1 {
                        CXRiderDivider()
                    }
                }
            }
        }
    }
}

/// "Recent results" panel; a row with a race link opens it through `openResult`.
struct CXRiderRecentResultsPanel: View {
    let results: [DTO.CXRiderPage.Result]
    let openResult: (DTO.CXRiderPage.Result) -> Void

    var body: some View {
        VaporPanel(panelColor: .tribuneru(.vaporPanelTomorrow)) {
            VaporSectionHeader(title: "Recent results")
        } content: {
            VaporCard(spacing: 0) {
                ForEach(results.indices, id: \.self) { index in
                    let item = results[index]
                    Button {
                        openResult(item)
                    } label: {
                        HStack(spacing: 10) {
                            PositionBadge(position: item.position)
                            VStack(alignment: .leading, spacing: 2) {
                                TribuneruText(
                                    content: item.race,
                                    style: .vaporRaceNameResult,
                                    color: .tribuneru(.vaporTextPrimary),
                                    lineLimit: 1
                                )
                                TribuneruText(
                                    content: item.date,
                                    style: .vaporMonoMeta,
                                    color: .tribuneru(.vaporTextSecondary),
                                    lineLimit: 1
                                )
                            }
                            Spacer(minLength: 0)
                            if item.raceURL != nil {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.tribuneru(.vaporTextSecondary))
                            }
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(item.raceURL == nil)

                    if index < results.count - 1 {
                        CXRiderDivider()
                    }
                }
            }
        }
    }
}

private struct CXRiderDivider: View {
    var body: some View {
        TribunerosDivider(
            height: 0.5,
            color: .tribuneru(.vaporTextSecondary).opacity(0.2)
        )
    }
}

/// Finishing position; wins are highlighted in the accent colour.
private struct PositionBadge: View {
    let position: String

    var body: some View {
        let isWin = position == "1"
        TribuneruText(
            content: position,
            style: .vaporFinishTime,
            color: isWin ? .tribuneru(.vaporPageBackground) : .tribuneru(.vaporTextPrimary),
            lineLimit: 1
        )
        .frame(width: 30, height: 30)
        .background(
            isWin
            ? Color.tribuneru(.vaporAccent)
            : Color.tribuneru(.vaporPageBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
