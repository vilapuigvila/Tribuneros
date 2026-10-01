//
//  HomeRaces.MockScenario.swift
//  Tribuneros
//

#if DEBUG
import Foundation

extension HomeRaces {
    enum MockScenario: String {
        case live
        case later
        case one
        case empty
        /// `live` data served as a 3-hour-old cached copy while offline.
        case stale
        /// `live` data plus five History rows (three in the preview, all behind "See all").
        case history

        /// The one mock switch: every mock in the app asks this, and nil means real data.
        static var current: MockScenario? {
            resolve(
                environment: ProcessInfo.processInfo.environment,
                launchValue: UserDefaults.standard.string(forKey: "mockScenario")
            )
        }

        /// `MOCK_SCENARIO` wins over the `mockScenario` launch argument; an unknown value is nil.
        static func resolve(
            environment: [String: String],
            launchValue: String?
        ) -> MockScenario? {
            (environment["MOCK_SCENARIO"] ?? launchValue).flatMap(MockScenario.init(rawValue:))
        }

        func domain(
            now: Date = Date(),
            isOnSpoilerModeResultsToday: Bool,
            isOnSpoilerModeResultsYesterday: Bool
        ) -> HomeRacesDomain {
            let races = nextToFinish(now: now)
            return HomeRacesDomain(
                nextToFinishRaces: races,
                todayRaces: Self.resultsToday,
                yesterdayResults: Self.resultsYesterday,
                historyResults: self == .history ? Self.resultsHistory : [],
                tomorrowRaces: [],
                liveStatsRaces: liveStats(for: races),
                isOnSpoilerModeResultsToday: isOnSpoilerModeResultsToday,
                isOnSpoilerModeResultsYesterday: isOnSpoilerModeResultsYesterday,
                error: nil,
                loading: false,
                staleCopy: self == .stale ? HomeRaces.StaleCopy(
                    savedAt: now.addingTimeInterval(-3 * 3600),
                    isOffline: true
                ) : nil
            )
        }

        private func nextToFinish(now: Date) -> [DTO.NextToFinishResult] {
            let cro = race("CRO Race - S1", in: 134, category: "ME", raceType: "2.1", flag: "hr", path: "race/cro-race/2026/stage-1", now: now)
            let chrono = race("Chrono des Nations", in: 172, category: "ME", raceType: "1.1", flag: "fr", path: "race/chrono-des-nations/2026/result", now: now)
            let coppa = race("Coppa Bernocchi", in: 217, category: "ME", raceType: "1.1", flag: "it", path: "race/coppa-bernocchi/2026/result", now: now)
            let montreal = race("GP de Montréal", in: 427, category: "ME", raceType: "1.UWT", flag: "ca", path: "race/gp-de-montreal/2026/result", now: now)
            switch self {
            case .live, .stale, .history: return [montreal, coppa, cro, chrono]
            case .later: return [montreal, chrono]
            case .one: return [cro]
            case .empty: return []
            }
        }

        private func liveStats(for races: [DTO.NextToFinishResult]) -> [DTO.LiveStatsRace] {
            guard self == .live || self == .stale || self == .one || self == .history else { return [] }
            let liveNames: Set<String> = self == .one ? ["CRO Race - S1"] : ["CRO Race - S1", "Coppa Bernocchi"]
            return races
                .filter { liveNames.contains($0.name) }
                .map { race in
                    DTO.LiveStatsRace(
                        status: "live",
                        isLive: true,
                        raceName: race.name,
                        ridersCount: 141,
                        racePath: race.urlPath.replacingOccurrences(of: "https://www.procyclingstats.com/", with: "") + "/live",
                        url: nil
                    )
                }
        }

        private func race(
            _ name: String,
            in minutes: Int,
            category: String,
            raceType: String,
            flag: String,
            path: String,
            now: Date
        ) -> DTO.NextToFinishResult {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "HH:mm"
            return DTO.NextToFinishResult(
                eta: formatter.string(from: now.addingTimeInterval(TimeInterval(minutes * 60))),
                duration: "\(minutes / 60)h",
                name: name,
                category: category,
                raceType: raceType,
                distance: "",
                urlPath: "https://www.procyclingstats.com/\(path)",
                flagCode: flag
            )
        }

        private static var resultsToday: [DTO.TodayResult] {
            [
                result(
                    "Giro della Toscana (1.1)",
                    "Pontedera - Pontedera (186.2km)",
                    slug: "giro-della-toscana",
                    winner: ("it", "MOCK Rider One", "4:32:18")
                ),
                result(
                    "Tour de Langkawi (2.Pro)",
                    "Stage 3 | Kuala Kubu Bharu - Ipoh (154km)",
                    slug: "tour-de-langkawi",
                    winner: ("nl", "MOCK Rider Two", "3:41:05")
                ),
                result(
                    "Grand Prix de Wallonie (1.Pro)",
                    "Namur - Citadelle de Namur (196km)",
                    slug: "grand-prix-de-wallonie",
                    winner: ("be", "MOCK Rider Three", "4:18:44")
                )
            ]
        }

        private static var resultsYesterday: [DTO.TodayResult] {
            [
                result(
                    "Tour de Langkawi (2.Pro)",
                    "Stage 2 | Kuantan - Pekan (168km)",
                    slug: "tour-de-langkawi-s2",
                    winner: ("be", "MOCK Rider Four", "4:02:47")
                ),
                result(
                    "Gran Piemonte (1.Pro)",
                    "Novara - Borgomanero (179km)",
                    slug: "gran-piemonte",
                    winner: ("it", "MOCK Rider Five", "4:11:52")
                ),
                result(
                    "Paris-Bourges (1.1)",
                    "Vierzon - Bourges (191km)",
                    slug: "paris-bourges",
                    winner: ("fr", "MOCK Rider Six", "4:20:09")
                ),
                result(
                    "Tre Valli Varesine (1.Pro)",
                    "Busto Arsizio - Varese (198km)",
                    slug: "tre-valli-varesine",
                    winner: ("it", "MOCK Rider Seven", "4:29:31")
                )
            ]
        }

        private static var resultsHistory: [DTO.TodayResult] {
            [
                result(
                    "Tre Valli Varesine (1.Pro)",
                    "Busto Arsizio - Varese (198km)",
                    slug: "tre-valli-varesine-history",
                    winner: ("it", "MOCK Rider Eight", "4:29:31")
                ),
                result(
                    "Il Lombardia (1.UWT)",
                    "Bergamo - Como (238km)",
                    slug: "il-lombardia",
                    winner: ("si", "MOCK Rider Nine", "5:41:12")
                ),
                result(
                    "Milano-Torino (1.Pro)",
                    "Mortara - Superga (179km)",
                    slug: "milano-torino",
                    winner: ("be", "MOCK Rider Ten", "4:07:50")
                ),
                result(
                    "Gran Premio Bruno Beghelli (1.Pro)",
                    "Monteveglio - Bologna (197km)",
                    slug: "gran-premio-bruno-beghelli",
                    winner: ("it", "MOCK Rider Eleven", "4:15:03")
                ),
                result(
                    "Memorial Marco Pantani (1.1)",
                    "Cesenatico - Cesenatico (190km)",
                    slug: "memorial-marco-pantani",
                    winner: ("co", "MOCK Rider Twelve", "4:22:40")
                )
            ]
        }

        /// The result page behind a mock race: its winner, then stand-ins; `nil` for any other URL.
        static func raceResultPage(for url: URL) -> DTO.RaceResultPage? {
            let races = resultsToday + resultsYesterday + resultsHistory
            guard let winner = races.first(where: { $0.raceURL == url })?.podium.first else {
                return nil
            }
            let leader = DTO.RaceResultPage.Row(
                position: "1",
                name: winner.name,
                team: "MOCK Team",
                time: winner.time
            )
            let chasers = (2...Service.raceResultRowLimit).map { position in
                DTO.RaceResultPage.Row(
                    position: "\(position)",
                    name: "MOCK Chaser \(position)",
                    team: "MOCK Team",
                    time: position < 4 ? ",," : String(format: "0:%02d", position * 3)
                )
            }
            return DTO.RaceResultPage(
                stage: nil,
                from: nil,
                to: nil,
                distance: nil,
                rows: [leader] + chasers
            )
        }

        private static func result(
            _ name: String,
            _ details: String,
            slug: String,
            winner: (flag: String, name: String, time: String)
        ) -> DTO.TodayResult {
            DTO.TodayResult(
                raceName: name,
                raceDetails: details,
                raceURL: URL(string: "https://www.procyclingstats.com/race/\(slug)/2026/result"),
                winner: nil,
                podium: [
                    DTO.TodayResult.Winner(
                        position: "1",
                        flag: URL(string: "https://www.procyclingstats.com/images/flags/\(winner.flag).png"),
                        countryCode: winner.flag,
                        name: winner.name,
                        team: "",
                        time: winner.time
                    )
                ],
                additionalDetails: []
            )
        }
    }
}
#endif
