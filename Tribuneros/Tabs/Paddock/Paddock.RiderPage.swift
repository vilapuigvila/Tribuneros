//
//  Paddock.RiderPage.swift
//  Tribuneros
//
//  What the Paddock rider screen shows from the rider's PCS page, beyond the profile facts:
//  specialties, key statistics, top results, program, teams, PCS ranking per season and the
//  current season's results (a preview, with the whole table on `SeasonResultsView`).
//  Each section is empty, and so hidden, when the page didn't carry it.
//

import Foundation

extension Paddock {

    /// One row of the current-season table; stage rows sit under their race.
    struct SeasonResultRow: Hashable, Identifiable {
        /// Index in the page's table.
        let id: Int
        let date: String
        let result: String
        let race: String
        let raceClass: String?
        let distance: String?
        let points: String?
        let isStage: Bool
    }

    /// The route payload of the "Season results" screen: the rows the rider screen already holds.
    struct SeasonResultsContext: Hashable {
        let riderName: String
        let rows: [SeasonResultRow]
    }

    struct RiderSections: Equatable {
        struct Specialty: Equatable {
            let title: String
            let points: Int
            /// Points over the rider's best specialty, 0...1.
            let fraction: Double
        }

        struct KeyStat: Equatable {
            let value: String
            let title: String
            let detail: String?
        }

        struct TopResult: Equatable {
            let count: String
            let kind: String?
            let race: String
            let years: String?
        }

        struct ProgramRace: Equatable {
            let date: String
            let race: String
            let countryCode: String?
        }

        struct Team: Equatable {
            let season: String
            let team: String
            let level: String?
        }

        struct Ranking: Equatable {
            let season: String
            let points: String
            let rank: String
        }

        /// The results preview shows this many race rows.
        static let previewLimit = 10

        var specialties: [Specialty] = []
        var keyStats: [KeyStat] = []
        var topResults: [TopResult] = []
        var program: [ProgramRace] = []
        var teams: [Team] = []
        var ranking: [Ranking] = []
        /// The first race rows (stages left out), for the preview card.
        var seasonPreview: [SeasonResultRow] = []
        /// Every row, for the "Season results" screen.
        var seasonResults: [SeasonResultRow] = []

        static let empty = RiderSections()

        init() {}

        init(page: DTO.PCSRiderPage?) {
            guard let page else { return }
            let best = page.specialties.map(\.points).max() ?? 0
            specialties = page.specialties.map {
                Specialty(
                    title: $0.title,
                    points: $0.points,
                    fraction: best > 0 ? Double($0.points) / Double(best) : 0
                )
            }
            keyStats = page.keyStats.map {
                KeyStat(
                    value: $0.value,
                    title: $0.title,
                    detail: $0.detail
                )
            }
            topResults = page.topResults.map {
                TopResult(
                    count: $0.count,
                    kind: $0.kind,
                    race: $0.race,
                    years: $0.years
                )
            }
            program = page.program.map {
                ProgramRace(
                    date: $0.date,
                    race: $0.race,
                    countryCode: $0.countryCode
                )
            }
            teams = page.teams.map {
                Team(
                    season: $0.season,
                    team: $0.team,
                    level: $0.level
                )
            }
            ranking = page.rankingBySeason.map {
                Ranking(
                    season: $0.season,
                    points: $0.points,
                    rank: $0.rank
                )
            }
            seasonResults = page.seasonResults.enumerated().map { index, row in
                SeasonResultRow(
                    id: index,
                    date: row.date,
                    result: row.result,
                    race: row.race,
                    raceClass: row.raceClass,
                    distance: row.distance,
                    points: row.pcsPoints,
                    isStage: row.isStage
                )
            }
            seasonPreview = Array(
                seasonResults
                    .filter { !$0.isStage }
                    .prefix(Self.previewLimit)
            )
        }
    }
}
