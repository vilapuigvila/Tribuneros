//
//  Requester+Cx.Mock.swift
//  Tribuneros
//

#if DEBUG
import Foundation

enum CxMock {
    private struct Rider {
        let slug: String
        let name: String
        let country: String
        let team: String
    }

    private static let riders = [
        Rider(slug: "mock-rider-one", name: "MOCK Rider One", country: "Netherlands", team: "Alpecin-Premier Tech"),
        Rider(slug: "mock-rider-two", name: "MOCK Rider Two", country: "Belgium", team: "Visma-Lease a Bike"),
        Rider(slug: "mock-rider-three", name: "MOCK Rider Three", country: "Belgium", team: "Baloise Trek Lions"),
        Rider(slug: "mock-rider-four", name: "MOCK Rider Four", country: "Belgium", team: "Pauwels Sauzen-Altez"),
        Rider(slug: "mock-rider-five", name: "MOCK Rider Five", country: "Belgium", team: "Crelan-Corendon"),
        Rider(slug: "mock-rider-six", name: "MOCK Rider Six", country: "Belgium", team: "Pauwels Sauzen-Altez"),
        Rider(slug: "mock-rider-seven", name: "MOCK Rider Seven", country: "Netherlands", team: "Baloise Trek Lions"),
        Rider(slug: "mock-rider-eight", name: "MOCK Rider Eight", country: "Netherlands", team: "Baloise Trek Lions"),
        Rider(slug: "mock-rider-nine", name: "MOCK Rider Nine", country: "Netherlands", team: "Ridley Racing Team"),
        Rider(slug: "mock-rider-ten", name: "MOCK Rider Ten", country: "Belgium", team: "Alpecin-Premier Tech")
    ]

    private static let site = "https://cyclocross24.com/"
    private static let gaverePath = "race/superprestige-gavere/"
    private static let molPath = "race/exact-cross-mol/"
    private static let kleebergPath = "race/kleeberg-cross-mechelen/"
    private static let koksijdePath = "race/world-cup-koksijde/"

    private static func url(_ path: String) -> URL? {
        URL(string: site + path)
    }

    private static func riderURL(_ index: Int) -> URL? {
        url("rider/\(riders[index].slug)/")
    }

    private static func date(
        daysFromNow: Int,
        format: String,
        now: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(
            from: Calendar.current.date(
                byAdding: .day,
                value: daysFromNow,
                to: now
            ) ?? now
        )
    }

    private static func words(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    // MARK: - Firestore documents -

    /// Two finished races from yesterday, each with a Men Elite podium.
    static func homepage(now: Date = Date()) -> DTO.CX24Homepage {
        func race(
            _ title: String,
            location: String,
            path: String,
            resultsID: Int
        ) -> DTO.CX24Homepage.Race {
            .init(
                title: title,
                country: "Belgium",
                countryFlagURL: nil,
                date: date(daysFromNow: -1, format: "d MMMM yyyy", now: now),
                location: location,
                raceURL: url(path),
                categories: [
                    .init(
                        title: "Men Elite",
                        categoryURL: url("race/\(resultsID)/"),
                        // A missing local file: the winner photo fails without a network request.
                        winnerImageURL: URL(fileURLWithPath: "/mock/cx-winner-missing.jpg"),
                        podium: [
                            podium(1, 0, "58:12"),
                            podium(2, 1, "+0:14"),
                            podium(3, 2, "+0:31")
                        ]
                    )
                ]
            )
        }
        return .init(
            sections: [
                .init(
                    title: "Latest Cyclocross Results",
                    races: [
                        race(
                            "Superprestige Gavere (C1)",
                            location: "Gavere, Belgium",
                            path: gaverePath,
                            resultsID: 17001
                        ),
                        race(
                            "Exact Cross Mol (C2)",
                            location: "Mol, Belgium",
                            path: molPath,
                            resultsID: 17002
                        )
                    ]
                )
            ]
        )
    }

    private static func podium(
        _ position: Int,
        _ index: Int,
        _ time: String
    ) -> DTO.CX24Homepage.Podium {
        .init(
            position: position,
            rider: riders[index].name,
            riderURL: riderURL(index),
            country: riders[index].country,
            countryFlagURL: nil,
            time: time
        )
    }

    private static func leaders(_ points: [Int]) -> [DTO.CXStandings.Leader] {
        points.enumerated().map { index, points in
            .init(
                position: index + 1,
                rider: riders[index].name,
                riderURL: riderURL(index),
                countryFlagURL: nil,
                points: "\(points)"
            )
        }
    }

    private static func standing(
        _ title: String,
        series: String,
        men: [Int],
        women: [Int]
    ) -> DTO.CXStandings.Item {
        .init(
            title: title,
            url: url("standings/\(series)/"),
            logoURL: nil,
            categories: [
                .init(
                    title: "Men Elite",
                    url: url("standings/\(series)/men-elite/"),
                    leaders: leaders(men),
                    leaderImageURL: nil
                ),
                .init(
                    title: "Women Elite",
                    url: url("standings/\(series)/women-elite/"),
                    leaders: leaders(women),
                    leaderImageURL: nil
                )
            ]
        )
    }

    static let standings = DTO.CXStandings(
        items: [
            .init(
                title: "UCI Ranking",
                url: url("uciranking/"),
                logoURL: nil,
                categories: [
                    .init(
                        title: "Men Elite",
                        url: url("uciranking/2025-2026/ME/"),
                        leaders: (0..<3).map { index in
                            .init(
                                position: index + 1,
                                rider: riders[index].name,
                                riderURL: riderURL(index),
                                countryFlagURL: nil,
                                points: "\(3_200 - index * 450) pts"
                            )
                        },
                        leaderImageURL: nil
                    )
                ]
            ),
            standing("UCI World Cup", series: "world-cup", men: [240, 198, 176], women: [215, 197, 150]),
            standing("Superprestige", series: "superprestige", men: [58, 55, 49], women: [56, 54, 40])
        ]
    )

    /// A race finished ten days ago, the two from the latest results, and three upcoming ones.
    static func calendar(now: Date = Date()) -> [DTO.CXCalendarEvent] {
        func event(
            _ race: String,
            raceClass: String,
            path: String,
            id: Int,
            daysFromNow: Int,
            winner: Int? = nil,
            country: String = "Belgium"
        ) -> DTO.CXCalendarEvent {
            let rider = winner.map { riders[$0] }
            return .init(
                date: date(daysFromNow: daysFromNow, format: "dd-MM-yyyy", now: now),
                race: race,
                raceClass: raceClass,
                flagURL: nil,
                winnerName: rider?.name ?? "",
                isCancelled: false,
                raceID: id,
                raceSlug: path.split(separator: "/").last.map(String.init),
                raceURL: url(path),
                resultsURL: url("race/\(id)/"),
                videoURL: nil,
                websiteURL: nil,
                raceCountry: country,
                winnerURL: winner.flatMap(riderURL),
                winnerCountry: rider?.country,
                winnerFlagURL: nil
            )
        }
        let others = (0..<120).map { index in
            event(
                "Mock Open \(index + 1)",
                raceClass: "C2",
                path: "race/mock-open-\(index + 1)/",
                id: 19_000 + index,
                daysFromNow: index < 10 ? index - 40 : (index - 9),
                winner: index < 10 ? index % 3 : nil,
                country: "Netherlands"
            )
        }
        return others + [
            event("Kleeberg Cross Mechelen", raceClass: "C2", path: kleebergPath, id: 18001, daysFromNow: -10, winner: 0),
            event("Superprestige Gavere", raceClass: "C1", path: gaverePath, id: 17001, daysFromNow: -1, winner: 0),
            event("Exact Cross Mol", raceClass: "C2", path: molPath, id: 17002, daysFromNow: -1, winner: 1),
            event("Exact Cross Essen", raceClass: "C2", path: "race/exact-cross-essen/", id: 18002, daysFromNow: 14),
            event("X2O Badkamers Trofee Baal", raceClass: "C2", path: "race/x2o-trofee-baal/", id: 18003, daysFromNow: 21),
            event("World Cup Koksijde", raceClass: "CDM", path: koksijdePath, id: 18004, daysFromNow: 30),
            event("World Cup Zonhoven", raceClass: "CDM", path: "race/world-cup-zonhoven/", id: 18005, daysFromNow: -20, winner: 2),
            event("World Cup Namur", raceClass: "CDM", path: "race/world-cup-namur/", id: 18006, daysFromNow: 45),
            event("World Cup Hoogerheide", raceClass: "CDM", path: "race/world-cup-hoogerheide/", id: 18007, daysFromNow: 60),
            event("Superprestige Niel", raceClass: "C1", path: "race/superprestige-niel/", id: 18008, daysFromNow: 7),
            event("Superprestige Merksplas", raceClass: "C1", path: "race/superprestige-merksplas/", id: 18009, daysFromNow: 28)
        ]
    }

    // MARK: - Detail pages -

    /// Every rider slug gets a page; unknown ones are named after the slug.
    static func riderPage(id: String) -> DTO.CXRiderPage {
        let rider = riders.first { $0.slug == id }
        return .init(
            name: rider?.name ?? words(id),
            avatarURL: nil,
            facts: [
                .init(label: "Nationality", value: rider?.country ?? "Belgium"),
                .init(label: "Team", value: rider?.team ?? "Mock Racing Team"),
                .init(label: "Date of birth", value: "19 January 1995"),
                .init(label: "Weight", value: "75 kg")
            ],
            results: [
                .init(date: "01-02-2026", race: "Kleeberg Cross Mechelen", position: "2", raceURL: url(kleebergPath)),
                .init(date: "25-01-2026", race: "Superprestige Gavere", position: "1", raceURL: url(gaverePath))
            ] + olderResults
        )
    }

    /// 23 more rows after the two above, newest first: the rest of 2025–26, then 2024–25.
    private static let olderResults: [DTO.CXRiderPage.Result] = {
        let days = [18, 11, 4]
        let thisSeason = [(1, 2026), (12, 2025), (11, 2025), (10, 2025)].flatMap { month, year in
            days.map { (day: $0, month: month, year: year) }
        }.dropFirst(2)
        let lastSeason = [(2, 2025), (1, 2025), (12, 2024), (11, 2024), (10, 2024)].flatMap { month, year in
            days.map { (day: $0, month: month, year: year) }
        }.prefix(13)
        return (Array(thisSeason) + Array(lastSeason)).enumerated().map { index, date in
            .init(
                date: String(format: "%02d-%02d-%04d", date.day, date.month, date.year),
                race: "Mock Open \(index + 1)",
                position: "\(index % 7 + 1)",
                raceURL: url("race/mock-open-\(index + 1)/")
            )
        }
    }()

    /// Every race slug gets the same three past winners, the newest from last year.
    static func racePage(id: String, now: Date = Date()) -> DTO.CXRacePage {
        let year = Calendar.current.component(.year, from: now)
        return .init(
            title: words(id),
            summary: "A cyclocross classic on a fast, technical course that rewards bike handling.",
            pastWinners: (0..<3).map { offset in
                .init(
                    year: "\(year - 1 - offset)",
                    rider: riders[offset].name,
                    riderURL: riderURL(offset),
                    countryFlagURL: nil,
                    resultsURL: url("race/\(17_100 + offset)/")
                )
            },
            tvChannels: id == "no-tv" ? [] : [
                .init(name: "Sporza", logoURL: nil, url: url("tv/sporza")), // l10n:ignore
                .init(name: "Eurosport*", logoURL: nil, url: url("tv/eurosport")), // l10n:ignore
                .init(name: "HBO Max", logoURL: nil, url: url("tv/hbomax")) // l10n:ignore
            ]
        )
    }

    /// Every results page is the same Men Elite top ten, led by the first rider.
    static let results: [DTO.CX24Homepage.CategoryResult] = riders.enumerated().map { index, rider in
        .init(
            position: "\(index + 1)",
            rider: rider.name,
            age: "\(24 + index)",
            team: rider.team,
            time: index == 0 ? "58:12" : "+0:\(10 + index * 7)",
            countryFlagURL: nil,
            raceVideosURL: nil,
            riderURL: riderURL(index)
        )
    }

    /// What `getCxDetail` serves per kind; the caller casts it to the type it asked for.
    static func detail(
        _ kind: Service.CxDetailKind,
        id: String
    ) -> Any {
        switch kind {
        case .rider: riderPage(id: id)
        case .race: racePage(id: id)
        case .results: Service.ResultsDocument(results: results)
        case .standing: standingPage(id: id)
        }
    }

    /// Any valid id gets three categories and 30 rows; the id's last segment picks the category.
    static func standingPage(id: String) -> DTO.CXStandingPage {
        let segments = id.split(separator: "~").map(String.init)
        let isUCI = segments.first == "uciranking"
        let codes = isUCI ? ["ME", "WE", "MU23"] : ["men-elite", "women-elite", "men-u23"]
        let titles = ["Men Elite", "Women Elite", "Men U23"]
        let selectedIndex = segments.last.flatMap { codes.firstIndex(of: $0) } ?? 0
        let middle = segments.dropFirst().filter { !codes.contains($0) }
        let base = segments[0] + "/" + (middle.first ?? (isUCI ? "2025-2026" : "superprestige")) + "/"
        return .init(
            title: isUCI ? "UCI Ranking" : words(middle.first ?? "superprestige"),
            categories: zip(titles, codes).map { title, code in
                .init(title: title, url: url(base + code + "/"))
            },
            selectedIndex: selectedIndex,
            rows: (0..<30).map { index in
                let rider = index < riders.count ? riders[index] : nil
                let slug = rider?.slug ?? "mock-rider-\(index + 1)"
                return .init(
                    position: index + 1,
                    rider: rider?.name ?? "MOCK Rider \(index + 1)",
                    riderURL: url("rider/\(slug)/"),
                    countryFlagURL: nil,
                    team: rider?.team ?? "Mock Racing Team",
                    points: "\(isUCI ? 3_200 - index * 85 : 120 - index * 3)"
                )
            }
        )
    }

    static let videoURL = URL(string: "https://www.example.com/mock-race-video")
}
#endif
