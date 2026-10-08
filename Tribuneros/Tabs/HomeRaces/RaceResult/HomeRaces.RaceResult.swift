//
//  HomeRaces.RaceResult.swift
//  Tribuneros
//
//  The race result screen (`RaceFinishedDetailView`), opened from a Results today, Yesterday or
//  History card: the homepage's title, route and podium right away, then the top 10 from the
//  race's PCS result page, and for a stage the general classification after it.
//

import Foundation

extension HomeRaces {
    enum RaceResult {

        /// The two tables a stage has. For a race without stages only `.stage` is used, and it
        /// means "the page that was tapped" (a one-day result, or a final GC).
        enum Classification: String, CaseIterable, Hashable, Sendable {
            case stage
            case gc

            var title: String {
                switch self {
                case .stage: "Stage"
                case .gc: "GC"
                }
            }
        }

        /// What the homepage name, details line ("Stage 5 | Mersch - Luxembourg (177km)") and URL
        /// say about a race.
        struct Descriptor: Equatable {
            enum Kind: Equatable {
                case oneDay
                /// "3", "2b"
                case stage(String)
                case prologue
                /// The homepage's "General classification" entry for a finished stage race.
                case generalClassification
            }

            let kind: Kind
            /// What follows the stage in the details line, e.g. "(ITT)".
            let marker: String?
            let route: Route
            let url: URL?

            init(
                name: String,
                details: String,
                url: URL?
            ) {
                let parts = details.split(
                    separator: "|",
                    maxSplits: 1,
                    omittingEmptySubsequences: false
                )
                let lead = parts.count == 2 ? Route.collapsed(String(parts[0])) : ""
                let routeText = parts.count == 2 ? String(parts[1]) : details
                let lastPath = url?.lastPathComponent.lowercased() ?? ""

                if let stage = Stage.split(name: name)?.stage
                    ?? Stage.number(inDetails: details)
                    ?? Stage.number(inURL: url) {
                    kind = .stage(stage)
                } else if lead.hasPrefix("Prologue") || lastPath == "prologue" {
                    kind = .prologue
                } else if lastPath == "gc"
                            || Route.collapsed(details).lowercased().hasPrefix("general classification") {
                    kind = .generalClassification
                } else {
                    kind = .oneDay
                }

                marker = Self.marker(in: lead)
                route = Route.parse(routeText)
                self.url = url
            }

            /// PCS serves the GC after a stage at the stage URL plus "-gc" (`stage-3` → `stage-3-gc`).
            var gcURL: URL? {
                guard let url else { return nil }
                let last = url.lastPathComponent
                switch kind {
                case .stage, .prologue:
                    guard last.hasPrefix("stage-") || last == "prologue" else { return nil }
                    return url
                        .deletingLastPathComponent()
                        .appending(path: last + "-gc")
                case .oneDay, .generalClassification:
                    return nil
                }
            }

            var classifications: [Classification] {
                gcURL == nil ? [] : Classification.allCases
            }

            func url(for classification: Classification) -> URL? {
                switch classification {
                case .stage: url
                case .gc: gcURL
                }
            }

            var kindLabel: String {
                switch kind {
                case .oneDay:
                    return Stage.oneDayLabel
                case .stage(let stage):
                    let label = Stage.label(stage)
                    return marker.map { "\(label) \($0)" } ?? label
                case .prologue:
                    return marker.map { "Prologue \($0)" } ?? "Prologue"
                case .generalClassification:
                    return "General classification"
                }
            }

            /// "Stage 3  ·  Sungai Petani › Kuala Kangsar  (189.7km)". The result page's route
            /// fills in what the homepage line lacks.
            func subtitle(page: DTO.RaceResultPage? = nil) -> String {
                let pageRoute = Route(
                    from: page?.from,
                    to: page?.to,
                    distance: page?.distance
                )
                let merged = Route(
                    from: route.from ?? pageRoute.from,
                    to: route.to ?? pageRoute.to,
                    distance: route.distance ?? pageRoute.distance
                )
                let label: String
                if kind == .oneDay, route.isEmpty, let stage = page?.stage {
                    label = stage
                } else {
                    label = kindLabel
                }
                return [label, merged.text]
                    .compactMap { $0 }
                    .joined(separator: "  ·  ")
            }

            /// "Stage 2a (ITT)" → "(ITT)"; nothing for a plain "Stage 2a".
            private static func marker(in lead: String) -> String? {
                let words = lead.split(separator: " ")
                let skipped: Int
                if lead.hasPrefix("Stage ") {
                    skipped = 2
                } else if lead.hasPrefix("Prologue") {
                    skipped = 1
                } else {
                    return nil
                }
                let rest = words.dropFirst(skipped).joined(separator: " ")
                return rest.isEmpty ? nil : rest
            }
        }

        /// "Montreal  - Montreal  (39.2km)" → from "Montreal", to "Montreal", distance "39.2km".
        struct Route: Equatable {
            let from: String?
            let to: String?
            let distance: String?

            var isEmpty: Bool {
                from == nil && to == nil && distance == nil
            }

            /// "From › To  (km)", or whichever part is known.
            var text: String? {
                let places = [from, to].compactMap { $0 }.joined(separator: " › ")
                let distanceText = distance.map { "(\($0))" }
                let parts = [places.isEmpty ? nil : places, distanceText].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: "  ")
            }

            static func parse(_ text: String) -> Route {
                var rest = collapsed(text)
                var distance: String?
                if let range = rest.range(
                    of: "\\(([^()]*[0-9][^()]*km)\\)$",
                    options: [.regularExpression, .caseInsensitive]
                ) {
                    distance = String(rest[range].dropFirst().dropLast())
                        .replacingOccurrences(of: " ", with: "")
                    rest = collapsed(String(rest[..<range.lowerBound]))
                }
                guard !rest.isEmpty,
                      !rest.lowercased().hasPrefix("general classification")
                else {
                    return Route(
                        from: nil,
                        to: nil,
                        distance: distance
                    )
                }
                if let dash = rest.range(of: " - ") {
                    let from = collapsed(String(rest[..<dash.lowerBound]))
                    let to = collapsed(String(rest[dash.upperBound...]))
                    return Route(
                        from: from.isEmpty ? nil : from,
                        to: to.isEmpty ? nil : to,
                        distance: distance
                    )
                }
                return Route(
                    from: rest,
                    to: nil,
                    distance: distance
                )
            }

            static func collapsed(_ text: String) -> String {
                text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            }
        }

        // MARK: - View -

        enum Action: Sendable {
            case onAppear
            case select(Classification)
            case openFullResults
        }

        struct ViewState: Equatable {
            struct Row: Identifiable, Equatable {
                var id: String { position + name }
                let position: String
                let name: String
                let team: String
                let time: String
                var countryCode: String = ""

                /// Stand-ins drawn redacted while the result page loads.
                static let placeholders: [Row] = (1...10).map {
                    Row(
                        position: "\($0)",
                        name: "Rider name placeholder",
                        team: "Team name placeholder",
                        time: $0 == 1 ? "0:00:00" : "+0:00"
                    )
                }
            }

            enum Table: Equatable {
                case loading
                case loaded([Row])
                /// The page couldn't be read: the homepage podium (when it matches the
                /// selected table) and why the rest is missing.
                case unavailable(
                    fallback: [Row],
                    message: String
                )
            }

            let title: String
            let subtitle: String
            let winnerImgURL: URL?
            /// Empty when there's nothing to switch between (one-day races).
            let classifications: [Classification]
            let selected: Classification
            let table: Table
            let fullResultsURL: URL?
        }
    }
}
