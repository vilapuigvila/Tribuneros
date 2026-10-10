//
//  HomeRaces.LiveRace.swift
//  Tribuneros
//
//  The live race screen (`LiveRaceDetailView`, route `liveRace`), opened from a LIVE race in the
//  Today section: the race's PCS live page (`<race path>/live`) in three sections, race stats with
//  the profile, the situation on the road, and the timeline. There is no streaming: the page is
//  polled every `Polling.interval` for `Polling.window`, then stops; pull to refresh polls again.
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
            struct Stat: Identifiable, Equatable {
                var id: String { label }
                /// Upper-cased: "KM TO GO".
                let label: String
                let value: String
                /// The status value ("racing") and Autosync "on" get the accent colour.
                var isHighlighted = false
            }

            struct Profile: Equatable {
                let points: [DTO.LivePage.Profile.Point]
                let progress: Double
                let elevationLabels: [String]
                let keypoints: [DTO.LivePage.Profile.Keypoint]
            }

            struct Group: Identifiable, Equatable {
                var id: String { badge + name }
                let badge: String
                let name: String
                let gap: String
                let riders: [DTO.LivePage.Group.Rider]
            }

            struct Event: Identifiable, Equatable {
                let id: String
                let badge: String
                let text: String
                /// "4m", "1h" relative to the last update; empty when unknown.
                let ago: String
                let header: [String]
                let rows: [[String]]
            }

            struct Content: Equatable {
                let stats: [Stat]
                let profile: Profile?
                let groups: [Group]
                let events: [Event]

                /// Stand-ins shaped like a real page, drawn redacted while it loads.
                static let placeholders = Content(
                    stats: ["KM TO GO", "KM DONE", "RACETIME", "AVG.", "START", "STATUS"].map {
                        Stat(
                            label: $0,
                            value: "000.0"
                        )
                    },
                    profile: nil,
                    groups: [
                        Group(
                            badge: "P",
                            name: "PELOTON",
                            gap: "",
                            riders: [
                                DTO.LivePage.Group.Rider(
                                    bib: "000",
                                    name: "Rider name placeholder",
                                    countryCode: ""
                                )
                            ]
                        )
                    ],
                    events: (1...4).map {
                        Event(
                            id: "placeholder-\($0)",
                            badge: "000",
                            text: "Timeline event placeholder text that spans a line",
                            ago: "0m",
                            header: [],
                            rows: []
                        )
                    }
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
