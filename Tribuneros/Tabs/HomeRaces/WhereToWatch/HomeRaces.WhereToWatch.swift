//
//  HomeRaces.WhereToWatch.swift
//  Tribuneros
//
//  The native "Where to watch" screen (`WhereToWatchView`), shown instead of the coursedujour.com
//  web page when Remote Config flag `ct_coursedujour_native` is on: the site's day strip and, for
//  the selected day, every race with its start time and the channels that broadcast it.
//

import Foundation

extension HomeRaces {
    enum WhereToWatch {

        enum Action: Sendable {
            case onAppear
            case select(String)
            case retry
        }

        struct ViewState: Equatable {
            struct Day: Identifiable, Equatable {
                /// "2026-10-02"
                let id: String
                /// "FRI", or "TODAY"
                let weekday: String
                let number: String
                /// "3 races"
                let count: String
                let isSelected: Bool
            }

            struct Channel: Identifiable, Equatable {
                var id: String { name }
                let name: String
                let regions: String
                /// The channel's own broadcast window, when the site lists one.
                let time: String?
            }

            struct Race: Identifiable, Equatable {
                let id: String
                let title: String
                /// "Stage 5  ·  2.Pro (Men)  ·  Tapah, Malaysia"
                let meta: String
                /// "10:11 – 13:35", in Central European time
                let time: String
                let isLive: Bool
                let isFinished: Bool
                /// The race the screen was opened from.
                let isHighlighted: Bool
                let channels: [Channel]
                let accessibilityLabel: String
            }

            struct Section: Identifiable, Equatable {
                var id: String { title }
                let title: String
                let caption: String
                let races: [Race]
            }

            /// The opened race, pinned above the day's sections (and left out of them); only on that race's day.
            enum Featured: Equatable {
                case race(Race)
                /// "Le Tour de Langkawi · Stage 5 isn't in this day's TV listings."
                case notListed(String)
            }

            enum Content: Equatable {
                case loading
                case loaded(
                    heading: String,
                    updated: String?,
                    featured: Featured?,
                    sections: [Section]
                )
                case failed
            }

            let days: [Day]
            let content: Content

            /// Stand-ins drawn redacted until the first page is in.
            static var placeholders: ViewState { ViewState(
                days: (0..<6).map {
                    Day(
                        id: "placeholder-\($0)",
                        weekday: "DAY",
                        number: "0",
                        count: "0 races",
                        isSelected: $0 == 0
                    )
                },
                content: .loaded(
                    heading: "Weekday, 0 Month 0000",
                    updated: "Coverage updated now",
                    featured: nil,
                    sections: [
                        Section(
                            title: "Road", // l10n:ignore
                            caption: "0 races with live coverage", // l10n:ignore
                            races: (0..<2).map {
                                Race(
                                    id: "placeholder-\($0)",
                                    title: "Race name placeholder", // l10n:ignore
                                    meta: "Category  ·  Location placeholder",
                                    time: "00:00 – 00:00",
                                    isLive: false,
                                    isFinished: false,
                                    isHighlighted: false,
                                    channels: [
                                        Channel(
                                            name: "Channel name",
                                            regions: "XX",
                                            time: nil
                                        )
                                    ],
                                    accessibilityLabel: L10n.tr("Loading")
                                )
                            }
                        )
                    ]
                )
            )
            }
        }
    }
}
