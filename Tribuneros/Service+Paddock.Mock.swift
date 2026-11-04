//
//  Service+Paddock.Mock.swift
//  Tribuneros
//

#if DEBUG
import Foundation

enum PaddockMock {
    private static let base = "https://www.procyclingstats.com/rider/"

    private static func rider(
        _ name: String,
        slug: String,
        country: String
    ) -> DTO.RiderLink {
        DTO.RiderLink(
            name: name,
            url: URL(string: base + slug),
            countryCode: country
        )
    }

    /// One transfer (dated yesterday), one program update and five birthdays (three on the card, all five in the sheet).
    static func paddock(now: Date = Date()) -> DTO.Paddock {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM"
        let yesterday = Calendar.current.date(
            byAdding: .day,
            value: -1,
            to: now
        ) ?? now
        return DTO.Paddock(
            transfers: [
                DTO.Transfer(
                    date: formatter.string(from: yesterday),
                    rider: rider("MOCK Transfer Rider", slug: "mock-transfer-rider", country: "it"),
                    teamName: "Ineos Grenadiers"
                )
            ],
            programUpdates: [
                DTO.ProgramUpdate(
                    timeAgo: "2h",
                    rider: rider("MOCK Program Rider", slug: "mock-program-rider", country: "si"),
                    changes: [
                        .init(isAdded: true, raceName: "Il Lombardia"),
                        .init(isAdded: false, raceName: "Tre Valli Varesine")
                    ]
                )
            ],
            birthdays: [
                DTO.Birthday(rider: rider("MOCK Birthday One", slug: "mock-birthday-one", country: "dk"), age: "31"),
                DTO.Birthday(rider: rider("MOCK Birthday Two", slug: "mock-birthday-two", country: "be"), age: "28"),
                DTO.Birthday(rider: rider("MOCK Birthday Three", slug: "mock-birthday-three", country: "es"), age: "24"),
                DTO.Birthday(rider: rider("MOCK Birthday Four", slug: "mock-birthday-four", country: "fr"), age: "35"),
                DTO.Birthday(rider: rider("MOCK Birthday Five", slug: "mock-birthday-five", country: "nl"), age: "22")
            ]
        )
    }

    static let pressLinks: [DTO.PressLink] = [
        DTO.PressLink(name: "Cycling News", url: URL(string: "https://www.cyclingnews.com")!),
        DTO.PressLink(name: "Escape Collective", url: URL(string: "https://escapecollective.com")!),
        DTO.PressLink(name: "Joan Seguidor", url: URL(string: "https://joanseguidor.com")!),
        DTO.PressLink(name: "Ciclismo 2005", url: URL(string: "https://ciclismo2005.com")!)
    ]

    /// Any rider URL gets a page named after its slug.
    static func riderPage(url: URL) -> DTO.PCSRiderPage {
        let name = url.lastPathComponent
            .split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
        return DTO.PCSRiderPage(
            name: name,
            imageURL: nil,
            team: "Mock Racing Team",
            facts: [
                .init(label: "Date of birth", value: "1 January 1998"),
                .init(label: "Nationality", value: "Mockland"),
                .init(label: "Weight", value: "66 kg"),
                .init(label: "Height", value: "1.78 m")
            ],
            specialties: [
                .init(title: "Oneday", points: 4210),
                .init(title: "GC", points: 3150),
                .init(title: "TT", points: 1820),
                .init(title: "Sprint", points: 540),
                .init(title: "Climber", points: 2980),
                .init(title: "Hills", points: 3360)
            ],
            keyStats: [
                .init(value: "42", title: "Wins", detail: "GC (6) Oneday races (12) ITT (3)"),
                .init(value: "5", title: "Grand tours", detail: "tour (2) giro (2) vuelta (1)"),
                .init(value: "9", title: "Classics", detail: nil)
            ],
            topResults: [
                .init(count: "3x", kind: "GC", race: "Mock Tour", years: "’22, ’24, ’26"),
                .init(count: "8x", kind: "stage", race: "Mock Tour", years: "’21, ’22, ’24, ’26"),
                .init(count: "2x", kind: nil, race: "Mock Classic", years: "’23, ’25")
            ],
            teams: [
                .init(season: "2027", team: "Mock Racing Team", level: "WT"),
                .init(season: "2026", team: "Mock Racing Team", level: "WT"),
                .init(season: "2025", team: "Mock Pro Cycling", level: "PRT"),
                .init(season: "2024", team: "Mock Development", level: "CT")
            ],
            program: [
                .init(date: "02.07", race: "Mock Tour", countryCode: "fr"),
                .init(date: "04.09", race: "Mock Vuelta", countryCode: "es")
            ],
            rankingBySeason: [
                .init(season: "2026", points: "3715", rank: "1"),
                .init(season: "2025", points: "4921", rank: "2"),
                .init(season: "2024", points: "4588", rank: "1")
            ],
            seasonResults: mockSeasonResults
        )
    }

    private static let mockSeasonResults: [DTO.PCSRiderPage.SeasonResult] = {
        var rows: [DTO.PCSRiderPage.SeasonResult] = [
            .init(date: "22.08 › 13.09", result: "", race: "Mock Vuelta", raceClass: "2.UWT", distance: nil, pcsPoints: nil, isStage: false)
        ]
        for stage in (1...8).reversed() {
            rows.append(
                .init(
                    date: String(format: "%02d.08", 21 + stage),
                    result: stage == 8 ? "DNF" : String(stage),
                    race: "Stage \(stage) - Mock Start › Mock Finish",
                    raceClass: nil,
                    distance: "161",
                    pcsPoints: stage % 2 == 0 ? "80" : nil,
                    isStage: true
                )
            )
        }
        rows += [
            .init(date: "10.08", result: "1", race: "Mock Classic", raceClass: "1.UWT", distance: "230", pcsPoints: "500", isStage: false),
            .init(date: "02.08", result: "3", race: "Mock Trophy", raceClass: "1.1", distance: "180.4", pcsPoints: "100", isStage: false),
            .init(date: "21.04", result: "2", race: "Mock Ardennes", raceClass: "1.UWT", distance: "259", pcsPoints: "400", isStage: false),
            .init(date: "02.03", result: "1", race: "Mock Strade", raceClass: "1.UWT", distance: "213", pcsPoints: "500", isStage: false),
            .init(date: "22.02", result: "4", race: "Mock Valenciana", raceClass: "1.Pro", distance: "190", pcsPoints: "60", isStage: false),
            .init(date: "15.02", result: "DNF", race: "Mock Algarve", raceClass: "2.Pro", distance: nil, pcsPoints: nil, isStage: false),
            .init(date: "30.01", result: "7", race: "Mock Down Under", raceClass: "2.UWT", distance: nil, pcsPoints: "40", isStage: false)
        ]
        return rows
    }()

    /// "Cycling News" and "Escape Collective" get eight headlines; every other site has no feed.
    static func pressFeed(for siteURL: URL) -> DTO.PressFeed? {
        let host = siteURL.host ?? ""
        let source: String
        if host.contains("cyclingnews") {
            source = "Cycling News"
        } else if host.contains("escapecollective") {
            source = "Escape Collective"
        } else {
            return nil
        }
        let now = Date()
        return DTO.PressFeed(
            articles: (1...8).map { index in
                DTO.PressFeed.Article(
                    title: "MOCK \(source) headline \(index)",
                    url: URL(string: "https://\(host)/mock-article-\(index)")!,
                    date: now.addingTimeInterval(-Double(index) * 5400),
                    imageURL: nil,
                    summary: index.isMultiple(of: 3)
                        ? nil
                        : "A short mock summary for headline \(index), as the feed would publish it."
                )
            }
        )
    }
}

extension PaddockMock {

    /// Six races shaped like races.php (next season, "dd.MM" dates, "-gc" / "-result" paths), so the preview shows three and "See all" the rest.
    static func races(now: Date = Date()) -> [DTO.PCSRace] {
        let year = Calendar.current.component(.year, from: now) + 1
        let rows: [(String, String, String, String, String)] = [
            ("tour-down-under", "Santos Tour Down Under", "19.01 - 24.01", "2.UWT", "au"),
            ("great-ocean-road-race", "Mapei Cadel Evans Great Ocean Road Race ME", "31.01", "1.UWT", "au"),
            ("uae-tour", "UAE Tour", "15.02 - 21.02", "2.UWT", "ae"),
            ("omloop-het-nieuwsblad", "Omloop Nieuwsblad ME", "27.02", "1.UWT", "be"),
            ("strade-bianche", "Strade Bianche", "06.03", "1.UWT", "it"),
            ("paris-nice", "Paris-Nice", "07.03 - 14.03", "2.UWT", "fr")
        ]
        return rows.map { slug, name, date, raceClass, country in
            DTO.PCSRace(
                path: "race/\(slug)-\(year)",
                name: name,
                dateText: date,
                raceClass: raceClass,
                countryCode: country
            )
        }
    }

    /// Six Women's WorldTour races shaped like races.php?circuit=24.
    static func womenRaces(now: Date = Date()) -> [DTO.PCSRace] {
        let year = Calendar.current.component(.year, from: now) + 1
        let rows: [(String, String, String, String, String)] = [
            ("santos-women-s-tour", "Santos Women's Tour Down Under", "22.01 - 24.01", "2.WWT", "au"),
            ("cadel-evans-great-ocean-we", "Mapei Cadel Evans Great Ocean Road Race WE", "30.01", "1.WWT", "au"),
            ("uae-tour-women", "UAE Tour Women", "03.02 - 06.02", "2.WWT", "ae"),
            ("omloop-het-nieuwsblad-we", "Omloop Nieuwsblad WE", "27.02", "1.WWT", "be"),
            ("strade-bianche-donne", "Strade Bianche Donne", "06.03", "1.WWT", "it"),
            ("trofeo-alfredo-binda", "Trofeo Alfredo Binda - Comune di Cittiglio", "14.03", "1.WWT", "it")
        ]
        return rows.map { slug, name, date, raceClass, country in
            DTO.PCSRace(
                path: "race/\(slug)-\(year)",
                name: name,
                dateText: date,
                raceClass: raceClass,
                countryCode: country
            )
        }
    }

    /// Every mock team gets a women's and a devo team, named after its own slug.
    static func teamPage(path: String) -> DTO.PCSTeamPage {
        let slug = path.replacingOccurrences(of: "team/", with: "")
        return DTO.PCSTeamPage(
            name: "Mock Team",
            classCode: "WT",
            season: 2027,
            kpis: DTO.PCSTeamKPIs(
                victories: 21,
                points: 6223,
                pcsRank: 11,
                uciRank: 12,
                incoming: 12,
                outgoing: 11
            ),
            info: DTO.PCSTeamInfo(
                status: "WT",
                abbreviation: "MCK",
                licenseCountry: "Belgium",
                bike: "Mock Bikes",
                jerseyURL: Service.pcsAbsoluteURL("images/shirts/mock-\(slug).png")
            ),
            links: [
                DTO.PCSTeamLink(
                    kind: "SITE",
                    url: URL(string: "https://example.com/\(slug)")!
                ),
                DTO.PCSTeamLink(
                    kind: "INSTAGRAM",
                    url: URL(string: "https://www.instagram.com/\(slug)")!
                )
            ],
            riders: [
                DTO.PCSTeamRider(
                    path: "rider/mock-leader",
                    name: "LEADER Mock",
                    countryCode: "be",
                    rank: 6,
                    points: 1985,
                    photoURL: Service.pcsAbsoluteURL("images/riders/mock-leader.jpg")
                ),
                DTO.PCSTeamRider(
                    path: "rider/mock-sprinter",
                    name: "SPRINTER Mock",
                    countryCode: "nl",
                    rank: 10,
                    points: 1494,
                    photoURL: nil
                )
            ],
            victories: [
                DTO.PCSTeamVictory(
                    racePath: "race/mock-tour-2027-stage-1",
                    raceName: "Mock Tour | Stage 1",
                    raceClass: "2.UWT",
                    countryCode: "be",
                    riderPath: "rider/mock-leader",
                    riderName: "LEADER Mock"
                )
            ],
            topResults: [
                DTO.PCSTeamResult(
                    position: 1,
                    racePath: "race/mock-classic-2027-result",
                    raceName: "Mock Classic",
                    raceClass: "1.UWT",
                    countryCode: "be",
                    riderPath: "rider/mock-sprinter",
                    riderName: "SPRINTER Mock",
                    points: 225
                )
            ],
            staff: [
                DTO.PCSTeamStaff(
                    path: "staff/mock-manager",
                    name: "Mock Manager",
                    function: "General manager",
                    countryCode: "be"
                )
            ],
            relatedTeams: [
                DTO.PCSRelatedTeam(
                    path: "team/\(slug)-women",
                    name: "Mock Women Team",
                    classCode: "WTW",
                    relation: "women's team"
                ),
                DTO.PCSRelatedTeam(
                    path: "team/\(slug)-development",
                    name: "Mock Development Team",
                    classCode: "CT",
                    relation: "devo"
                )
            ]
        )
    }

    static func teams() -> [DTO.PCSTeam] {
        let rows: [(String, String, String, String)] = [
            ("uae-team-emirates-xrg", "UAE Team Emirates - XRG", "UCI WorldTeams", "ae"),
            ("visma-lease-a-bike", "Visma | Lease a Bike", "UCI WorldTeams", "nl"),
            ("soudal-quick-step", "Soudal Quick-Step", "UCI WorldTeams", "be"),
            ("tudor-pro-cycling-team", "Tudor Pro Cycling Team", "UCI ProTeams", "ch"),
            ("team-flanders-baloise", "Team Flanders - Baloise", "UCI ProTeams", "be")
        ]
        return rows.map { slug, name, division, country in
            DTO.PCSTeam(
                path: "team/\(slug)-2027",
                name: name,
                division: division,
                countryCode: country
            )
        }
    }
}
#endif
