//
//  CXRaces.RiderResults.swift
//  Tribuneros
//
//  A rider's whole cyclocross24 results table (route `cxZone(.riderResults)`), newest first and
//  grouped by season, from the `cxRiders` document. Opened from the rider and winner screens'
//  "All results" link; rows open the race the way "Recent results" rows do.
//

import Foundation

extension CXRaces {
    enum RiderResults {

        enum Action: Sendable {
            case onAppear
            /// A row, by its index in the rider page's results.
            case openResult(Int)
        }

        struct ViewState: Equatable {
            struct Row: Identifiable, Equatable {
                /// Index in the rider page's results.
                let id: Int
                let position: String
                let race: String
                let date: String
                let isTappable: Bool
            }

            struct Season: Identifiable, Equatable {
                var id: String { title }
                /// "2025–26", or "Others" for rows without a readable date.
                let title: String
                let rows: [Row]

                /// Stand-ins drawn redacted while the rider page loads.
                static let placeholders: [Season] = [
                    Season(
                        title: "2025–26",
                        rows: (0..<8).map {
                            Row(
                                id: $0,
                                position: "\($0 + 1)",
                                race: "Race name placeholder", // l10n:ignore
                                date: "00-00-0000",
                                isTappable: false
                            )
                        }
                    )
                ]
            }

            enum Body: Equatable {
                case loading
                case loaded([Season])
                case unavailable(String)
            }

            let title: String
            let subtitle: String
            let body: Body
        }

        /// Newest first, grouped by season (a season starts in July). Rows of the same day keep the
        /// page's order; rows without a readable date go last, in an "Others" group.
        static func seasons(_ results: [DTO.CXRiderPage.Result]) -> [ViewState.Season] {
            let dated = results.enumerated().map { index, result in
                (index: index, result: result, date: date(result.date))
            }
            let sorted = dated
                .filter { $0.date != nil }
                .sorted { lhs, rhs in
                    guard let left = lhs.date, let right = rhs.date, left != right else {
                        return lhs.index < rhs.index
                    }
                    return left > right
                }
            var seasons: [ViewState.Season] = []
            for item in sorted {
                guard let date = item.date else { continue }
                let title = seasonTitle(for: date)
                let row = row(item.index, item.result)
                if let last = seasons.last, last.title == title {
                    seasons[seasons.count - 1] = .init(
                        title: title,
                        rows: last.rows + [row]
                    )
                } else {
                    seasons.append(
                        .init(
                            title: title,
                            rows: [row]
                        )
                    )
                }
            }
            let undated = dated
                .filter { $0.date == nil }
                .map { row($0.index, $0.result) }
            if !undated.isEmpty {
                seasons.append(
                    .init(
                        title: L10n.tr("Others"),
                        rows: undated
                    )
                )
            }
            return seasons
        }

        /// "2025–26" for any date from July 2025 through June 2026.
        static func seasonTitle(for date: Date) -> String {
            let parts = Service.cxCalendar.dateComponents(
                [.year, .month],
                from: date
            )
            let year = parts.year ?? 0
            let start = (parts.month ?? 1) >= 7 ? year : year - 1
            return String(format: "%d–%02d", start, (start + 1) % 100)
        }

        /// Rider pages write "04-01-2026", sometimes "4.1.2026" or "04/01/2026".
        static func date(_ text: String) -> Date? {
            let parts = text.split { "-./".contains($0) }.compactMap { Int($0) }
            guard parts.count == 3, (1...31).contains(parts[0]), (1...12).contains(parts[1]) else { return nil }
            return Service.cxCalendar.date(
                from: DateComponents(
                    year: parts[2],
                    month: parts[1],
                    day: parts[0]
                )
            )
        }

        private static func row(
            _ index: Int,
            _ result: DTO.CXRiderPage.Result
        ) -> ViewState.Row {
            .init(
                id: index,
                position: result.position,
                race: result.race,
                date: result.date,
                isTappable: result.raceURL != nil
            )
        }
    }
}
