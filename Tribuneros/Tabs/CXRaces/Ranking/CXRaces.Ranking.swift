//
//  CXRaces.Ranking.swift
//  Tribuneros
//
//  A full cyclocross24 ranking or series standings table (route `cxZone(.ranking)`), from the
//  `cxStandings` documents: category chips over the whole table. Opened from a rider's standing
//  panel (on that category) and from a Standings list header (on the page's default category).
//  UCI rankings hold their top 100, series standings the whole table.
//

import Foundation

extension CXRaces {
    enum Ranking {

        enum Action: Sendable {
            case onAppear
            case selectCategory(Int)
            /// A row, by its index in the shown page.
            case openRow(Int)
        }

        struct ViewState: Equatable {
            struct Chip: Identifiable, Equatable {
                let id: Int
                let title: String
                let isSelected: Bool

                static let placeholders: [Chip] = (0..<3).map {
                    Chip(
                        id: $0,
                        title: "Category", // l10n:ignore
                        isSelected: $0 == 0
                    )
                }
            }

            struct Row: Identifiable, Equatable {
                /// Index in the page's rows.
                let id: Int
                let position: String
                let rider: String
                let flagURL: URL?
                /// `nil` when the page has no team column.
                let team: String?
                let points: String

                static let placeholders: [Row] = (0..<12).map {
                    Row(
                        id: $0,
                        position: "\($0 + 1)",
                        rider: "Rider name placeholder", // l10n:ignore
                        flagURL: nil,
                        team: nil,
                        points: "000"
                    )
                }
            }

            enum Body: Equatable {
                case loading
                case loaded([Row])
                case unavailable(String)
            }

            let title: String
            let logoURL: URL?
            /// `nil` until a page has told which categories there are.
            let chips: [Chip]?
            let body: Body
        }
    }
}
