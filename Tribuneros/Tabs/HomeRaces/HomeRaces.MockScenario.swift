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
        /// No races today, so the resting card shrinks, plus three homepage previews.
        case previews
        /// `live` races still to finish, before any result today: the empty podium with its expected time.
        case pending

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
            revealedRaces: Set<String> = []
        ) -> HomeRacesDomain {
            let races = nextToFinish(now: now)
            var domain = HomeRacesDomain(
                nextToFinishRaces: races,
                todayRaces: self == .empty || self == .pending ? [] : Self.resultsToday,
                yesterdayResults: self == .empty ? [] : Self.resultsYesterday,
                historyResults: self == .history ? Self.resultsHistory : [],
                tomorrowRaces: [],
                liveStatsRaces: liveStats(for: races),
                error: nil,
                loading: false,
                staleCopy: self == .stale ? HomeRaces.StaleCopy(
                    savedAt: now.addingTimeInterval(-3 * 3600),
                    isOffline: true
                ) : nil,
                revealedRaces: revealedRaces
            )
            if self == .previews || self == .live {
                domain.previews = Self.mockPreviews
            }
            return domain
        }

        private func nextToFinish(now: Date) -> [DTO.NextToFinishResult] {
            let cro = race("CRO Race - S1", in: 134, category: "ME", raceType: "2.1", flag: "hr", path: "race/cro-race/2026/stage-1", now: now)
            let chrono = race("Chrono des Nations", in: 172, category: "ME", raceType: "1.1", flag: "fr", path: "race/chrono-des-nations/2026/result", now: now)
            let coppa = race("Coppa Bernocchi", in: 217, category: "ME", raceType: "1.1", flag: "it", path: "race/coppa-bernocchi/2026/result", now: now)
            let montreal = race("GP de Montréal", in: 427, category: "ME", raceType: "1.UWT", flag: "ca", path: "race/gp-de-montreal/2026/result", now: now)
            switch self {
            case .live, .stale, .history, .pending: return [montreal, coppa, cro, chrono]
            case .later: return [montreal, chrono]
            case .one: return [cro]
            case .empty, .previews: return []
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
            let minutes = Self.fittingToday(minutes, now: now)
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

        /// Late in the day, squeezes the finishes so the latest one (427 min) still lands before
        /// midnight, locally and on the Where to watch calendar; otherwise flows fail after ~17:00.
        private static func fittingToday(
            _ minutes: Int,
            now: Date
        ) -> Int {
            let latest = 427
            let minutesLeft = [Calendar.current.timeZone, HomeRaces.WhereToWatch.scheduleTimeZone]
                .map { timeZone -> Int in
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = timeZone
                    let midnight = calendar.nextDate(
                        after: now,
                        matching: DateComponents(hour: 0, minute: 0),
                        matchingPolicy: .nextTime
                    ) ?? now
                    return Int(midnight.timeIntervalSince(now) / 60)
                }
                .min() ?? latest
            let room = minutesLeft - 5
            guard room < latest else { return minutes }
            return max(1, minutes * max(room, 0) / latest)
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

        private static let previewBase = "https://www.procyclingstats.com/race/"

        private static var mockPreviews: [DTO.Preview] {
            [
                DTO.Preview(
                    countdown: "2h",
                    name: "MOCK Tour de Langkawi - S6",
                    url: URL(string: previewBase + "tour-de-langkawi/2026/stage-6/live")
                ),
                DTO.Preview(
                    countdown: "5h",
                    name: "MOCK Gran Piemonte",
                    url: URL(string: previewBase + "gran-piemonte/2026/result/live")
                ),
                DTO.Preview(
                    countdown: "9h",
                    name: "MOCK Paris-Bourges",
                    url: URL(string: previewBase + "paris-bourges/2026/result/live")
                )
            ]
        }

        /// A fixed pre-race page for any mock preview URL; `nil` for any other URL.
        static func previewPage(for url: URL) -> DTO.PreviewPage? {
            guard mockPreviews.contains(where: { $0.url == url }) else {
                return nil
            }
            return DTO.PreviewPage(
                stage: "MOCK Stage 6",
                from: "MOCK Kuala Kubu Bharu",
                to: "MOCK Ipoh",
                distance: "154.5 km",
                start: "02/10 09:12",
                startCET: "03:12",
                keypoints: [
                    DTO.PreviewPage.Keypoint(km: "42.0", type: "Sprint", name: "MOCK Sprint Town"),
                    DTO.PreviewPage.Keypoint(km: "88.5", type: "KOM", name: "MOCK Climb Pass"),
                    DTO.PreviewPage.Keypoint(km: "154.5", type: "Finish", name: "MOCK Finish Line")
                ],
                facts: [
                    DTO.PreviewPage.Fact(
                        text: "MOCK fact: the peloton expects a bunch sprint.",
                        header: [],
                        rows: []
                    ),
                    DTO.PreviewPage.Fact(
                        text: "MOCK favourites for the stage",
                        header: ["Rider", "Odds"],
                        rows: [["MOCK Rider One", "2.5"], ["MOCK Rider Two", "4.0"]]
                    ),
                    DTO.PreviewPage.Fact(
                        text: "MOCK fact: the last time here was in 2024.",
                        header: [],
                        rows: []
                    )
                ]
            )
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
