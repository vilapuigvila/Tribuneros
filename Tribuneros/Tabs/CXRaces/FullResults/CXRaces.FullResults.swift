//
//  CXRaces.FullResults.swift
//  Tribuneros
//
//  Every Men Elite row of a calendar race's results (route `cxZone(.fullResults)`), opened from the
//  event detail's "full results" link. The rows come from the `cxResults` document the detail
//  already loaded; the screen only fetches them itself when it was opened without any.
//

import Foundation

extension CXRaces {
    enum FullResults {

        enum Action: Sendable {
            case onAppear
            case openRow(Int)
        }

        struct ViewState: Equatable {
            struct Row: Identifiable, Equatable {
                /// Index in the results.
                let id: Int
                let position: String
                let rider: String
                let team: String
                let time: String
                let flagURL: URL?

                var isWinner: Bool { position == "1" }

                /// Stand-ins drawn redacted while the results load.
                static let placeholders: [Row] = (0..<12).map {
                    Row(
                        id: $0,
                        position: "\($0 + 1)",
                        rider: "Rider name placeholder", // l10n:ignore
                        team: "Team name placeholder", // l10n:ignore
                        time: "+0:00",
                        flagURL: nil
                    )
                }
            }

            enum Body: Equatable {
                case loading
                case loaded([Row])
                case unavailable(String)
            }

            let title: String
            let subtitle: String
            let body: Body
        }
    }
}
