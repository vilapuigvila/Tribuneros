//
//  HomeRaces.RacePreview.swift
//  Tribuneros
//
//  The race preview screen (`RacePreviewDetailView`), opened from a homepage Preview while
//  Results today is empty: the race's pre-race info from its PCS LiveStats page, namely the start
//  time, the key points (climbs and sprints) and the fact cards.
//

import Foundation

extension HomeRaces {
    enum RacePreview {

        enum Action: Sendable {
            case onAppear
            case openOnPCS
        }

        struct ViewState: Equatable {
            struct Keypoint: Identifiable, Equatable {
                var id: String { km + name }
                let km: String
                let type: String
                let name: String
            }

            struct Fact: Identifiable, Equatable {
                let id: Int
                let text: String
                let header: [String]
                let rows: [[String]]
            }

            struct Content: Equatable {
                let start: String?
                let keypoints: [Keypoint]
                let facts: [Fact]

                /// Stand-ins drawn redacted while the page loads.
                static let placeholders = Content(
                    start: "00/00 00:00 (00:00 CET)",
                    keypoints: (1...4).map {
                        Keypoint(
                            km: "0\($0)",
                            type: "climb",
                            name: "Keypoint name placeholder"
                        )
                    },
                    facts: (1...2).map {
                        Fact(
                            id: $0,
                            text: "Fact text placeholder that runs over two lines",
                            header: [],
                            rows: []
                        )
                    }
                )
            }

            enum Body: Equatable {
                case loading
                case loaded(Content)
                case unavailable(String)
            }

            let title: String
            let subtitle: String
            let body: Body
            let pcsURL: URL?
        }
    }
}
