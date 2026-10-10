//
//  HomeRaces.LiveRace.swift
//  Tribuneros
//
//  The live race screen (`LiveRaceDetailView`, route `liveRace`), opened from a LIVE race in the
//  Today section: the race's PCS live page (`<race path>/live`) in three sections, the profile with
//  the race state, the race data (KPI strip) and the situation on the road. There is no streaming:
//  the page is polled every `Polling.interval` for `Polling.window`, then stops; pull to refresh
//  polls again.
//

import Foundation

extension HomeRaces {
    enum LiveRace {

        /// The route's payload: what the Today card already knows, shown before the page loads.
        struct Context: Hashable, Sendable {
            let name: String
            /// "Stage 3 · 1.UWT"-style line from the Today card; may be empty.
            let subtitle: String
            let flagCode: String
            /// The PCS live page, `nil` when the race has no path.
            let url: URL?

            /// `urlPath` is the Today race's PCS path ("race/il-lombardia/2026/result", relative or
            /// absolute); its live page is that path plus "/live".
            static func liveURL(urlPath: String?) -> URL? {
                guard var path = urlPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !path.isEmpty
                else {
                    return nil
                }
                if let host = path.range(of: "procyclingstats.com/") {
                    path = String(path[host.upperBound...])
                }
                path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                if !path.hasSuffix("/live") {
                    path += "/live"
                }
                return URL(string: "https://www.procyclingstats.com/" + path)
            }
        }

        enum Polling {
            static let interval: TimeInterval = 5
            static let window: TimeInterval = 60
        }

        /// Shown on a fresh install, once more 48 hours after that, then never (same rule as
        /// `SpoilerHint`, own stored values: `UserSettings.liveHintFirstShown` / `liveHintShownCount`).
        enum Hint {
            static let text = "Live updates every 5 seconds for a minute. Pull down to follow again."
            static let repeatInterval: TimeInterval = 48 * 3600
            static let maxShowings = 2

            static func shouldShow(
                now: Date,
                firstShown: Date?,
                count: Int
            ) -> Bool {
                guard count < maxShowings else { return false }
                guard count > 0, let firstShown else { return true }
                return now.timeIntervalSince(firstShown) >= repeatInterval
            }
        }

        // MARK: - Interactor contract -

        enum Load: Equatable {
            case idle
            case loading
            case loaded(DTO.LivePage)
            case failed
        }

        struct Domain: Equatable {
            let url: URL?
            /// The last page read; a failed poll keeps the previous `.loaded` page.
            var load: Load = .idle
            /// True while the 60 s polling window runs.
            var isPolling = false
            /// When the last successful poll finished.
            var updatedAt: Date?
            var showHint = false
        }

        enum UseCase: Sendable {
            /// First appearance: evaluates the hint, loads at once and starts the polling window
            /// (no-op if it is already running).
            case start
            /// Pull to refresh: loads at once and restarts the polling window.
            case refresh
            /// The screen went away: stops polling.
            case stop
            case dismissHint
        }

        // MARK: - View contract -

        enum Action: Sendable {
            case onAppear
            case onDisappear
            /// Awaited by `.refreshable`, so the spinner stays until the first poll lands.
            case refresh
            case dismissHint
            case openOnPCS
        }

        struct ViewState: Equatable {
            /// The KPI strip, in screen order.
            struct Stat: Identifiable, Equatable {
                var id: String { label }
                /// Upper-cased: "KM TO GO".
                let label: String
                let value: String
                /// The status value ("racing") gets the accent colour.
                var isHighlighted = false
            }

            struct Profile: Equatable {
                let points: [DTO.LivePage.Profile.Point]
                /// Share of the route done, 0...1.
                let progress: Double
                let keypoints: [DTO.LivePage.Profile.Keypoint]
                /// Km axis labels; `x` is the position on the chart (0...1, the last may sit just past 1).
                let kmLabels: [DTO.LivePage.Profile.KmLabel]
                /// The route's length in km; nil when the page doesn't give it.
                let routeKm: Double?
                /// Km done by the front group (the KM DONE stat).
                let frontKm: Double?
                /// Estimated km done by the peloton, nil when unknown; see `ViewModel.estimatedPelotonKm`.
                let pelotonKm: Double?
                /// Elevation labels in metres, e.g. ["200", "400"].
                let elevationLabels: [String]
            }

            struct Rider: Identifiable, Equatable {
                var id: String { "\(bib)-\(name)" }
                /// The place in the group; empty when PCS shows none.
                let position: String
                let bib: String
                let name: String
                let countryCode: String
            }

            /// One group on the road, in PCS's order (the first is the head of the race).
            struct Group: Identifiable, Equatable {
                var id: String { badge + name }
                /// "1", "2"… or "P".
                let badge: String
                /// Upper-cased: "BREAK", "PELOTON".
                let name: String
                /// "+1:25"; empty for the first group.
                let gap: String
                let isPeloton: Bool
                let riders: [Rider]
            }

            struct Content: Equatable {
                let stats: [Stat]
                let profile: Profile?
                let groups: [Group]

                /// Stand-ins shaped like a real page, drawn redacted while it loads.
                static let placeholders = Content(
                    stats: ["KM TO GO", "KM DONE", "RACETIME", "AVG.", "START", "STATUS"].map {
                        Stat(
                            label: $0,
                            value: "000.0"
                        )
                    },
                    profile: Profile(
                        points: (0..<8).map { index in
                            DTO.LivePage.Profile.Point(
                                x: Double(index) / 7,
                                y: 0.3 + 0.4 * Double(index % 3) / 2
                            )
                        },
                        progress: 0.3,
                        keypoints: [],
                        kmLabels: [],
                        routeKm: nil,
                        frontKm: nil,
                        pelotonKm: nil,
                        elevationLabels: ["200", "400"]
                    ),
                    groups: [
                        Group(
                            badge: "P",
                            name: "PELOTON",
                            gap: "",
                            isPeloton: true,
                            riders: [
                                Rider(
                                    position: "1",
                                    bib: "000",
                                    name: "Rider name placeholder",
                                    countryCode: ""
                                )
                            ]
                        )
                    ]
                )
            }

            enum Body: Equatable {
                case loading
                case loaded(Content)
                case unavailable(message: String)
            }

            let title: String
            let subtitle: String
            let flagCode: String
            let body: Body
            let isPolling: Bool
            /// "Updated 12:04:31", empty before the first load.
            let updatedText: String
            let showHint: Bool
            let pcsURL: URL?
        }
    }
}
