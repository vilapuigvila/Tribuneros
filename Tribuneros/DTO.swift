//
//  DTO.swift
//  Tribuneros
//
//  Created by albert vila on 25/4/25.
//

import Foundation

enum DTO {
    struct Home: Codable, Equatable {
        let nextToFinish: [NextToFinishResult]
        let today: [TodayResult]
        let yesterdayResults: [TodayResult]
        let tomorrowRaces: [TomorrowRace]
        let liveStats: [LiveStatsRace]
        /// Set only when the page is an expired cached copy (offline or a failed fetch): when it was fetched.
        var staleCopySavedAt: Date? = nil
        var previews: [Preview] = []
    }

    struct LiveStatsRace: Codable, Equatable {
        let status: String        // "live"
        let isLive: Bool          // span.status class list contains "live"
        let raceName: String
        let ridersCount: Int?     // nil when the span isn't a number
        let racePath: String      // relative href, stored verbatim
        let url: URL?             // baseURL + racePath
    }
    
    struct NextToFinishResult: Codable, Equatable {
        let eta: String
        let duration: String
        let name: String
        let category: String
        let raceType: String
        let distance: String
        let urlPath: String
        let flagCode: String
        
        static func parse(cells: [[String]]) -> [NextToFinishResult] {
            // New "Next to finish" row layout has 6 <td> (icon, ETA, duration, race, Cat, Class)
            // plus the appended url and flag code, so 8 entries at indices 0...7 — there is no
            // distance column any more, so that field is fed "".
            cells.compactMap { row in
                guard row.count >= 8 else {
                    nonFatalCrashlytics(false, "NextToFinishResult row has \(row.count) cells, expected at least 8")
                    return nil
                }
                return NextToFinishResult(
                    eta: row[1],
                    duration: row[2],
                    name: row[3],
                    category: row[4],
                    raceType: row[5],
                    distance: "",
                    urlPath: row[6],
                    flagCode: row[7])
            }
        }
    }
    
    struct TodayResult: Codable, Equatable {
        struct Winner: Codable, Equatable {
            let position: String
            let flag: URL?
            let countryCode: String?
            let name: String
            let team: String
            let time: String
        }
        struct AdditionalDetails: Codable, Equatable {
            let tag: String
            let url: URL?
        }
        let raceName: String
        let raceDetails: String
        let raceURL: URL?
        let winner: URL?
        let podium: [Winner]
        let additionalDetails: [AdditionalDetails]
    }
    
    struct TomorrowRace: Codable, Equatable {
        let startTime: String
        let raceName: String
        let relativeUrl: URL?
        let eta: String
    }
}

extension DTO {
    struct RaceDetailInfo: Codable, Equatable {
        let title: String
        let date: String
        let startTime: String
        let classification: String
        let category: String
        let distance: String
        let departure: String
        let arrival: String
        let verticalMeters: String
        let profileURL: URL?
    }
    
    struct StageProfile: Codable, Equatable, CustomStringConvertible {
        var description: String {
            return "Type: \(type) - url: \(url)"
        }
        
        enum ProfileImageType: String, Codable, CustomStringConvertible {
            var description: String {
                switch self {
                case .profile: return "Profile"
                case .map: return "Map"
                case .climb: return "Climb"
                case .finishProfile: return "Finish profile"
                case .none: return "none"
                case .localCircut: return "Local circuit"
                }
            }
            
            case profile = "Profile"
            case climb = "Climb"
            case map = "Map"
            case finishProfile = "Finish profile"
            case localCircut = "Local circuit"
            case none
            
            init(rawValue: String) {
                switch rawValue {
                case "Profile": self = .profile
                case "Map": self = .map
                case "Climb": self = .climb
                case "Finish profile": self = .finishProfile
                case "Local circuit": self = .localCircut
                default:
                    nonFatalCrashlytics(false, "new StageProfile.ProfileImageType case: \(rawValue)", domain: .default)
                    self = .none
                    
                }
            }
        }
        let type: ProfileImageType
        let url: String
    }

    /// A PCS race result page (`race/<slug>/<year>/result`, `/stage-3`, `/stage-3-gc`, `/gc`):
    /// the top of its first results table, plus the route when the page lists it.
    /// Times are as PCS prints them: the leader's time, then gaps ("0:12", or ",," for same time).
    struct RaceResultPage: Equatable, Sendable {
        struct Row: Equatable, Sendable {
            let position: String
            let name: String
            let team: String
            let time: String
        }

        let stage: String?
        let from: String?
        let to: String?
        let distance: String?
        let rows: [Row]
    }
}

// MARK: - Race previews -

extension DTO {
    /// A homepage "Previews" entry: the countdown ("5h") and the race's LiveStats page.
    struct Preview: Codable, Equatable, Hashable, Sendable {
        let countdown: String
        let name: String
        let url: URL?
    }

    /// The pre-race state of a race's LiveStats page. Every part is best-effort.
    struct PreviewPage: Equatable, Sendable {
        struct Keypoint: Equatable, Sendable {
            let km: String
            let type: String
            let name: String
        }

        /// One `li.event` text, with the small table under it when PCS has one.
        struct Fact: Equatable, Sendable {
            let text: String
            let header: [String]
            let rows: [[String]]
        }

        let stage: String?
        let from: String?
        let to: String?
        let distance: String?
        /// "02/10 09:12" in the race's time zone.
        let start: String?
        /// "03:12"
        let startCET: String?
        let keypoints: [Keypoint]
        let facts: [Fact]
    }
}

// MARK: - Paddock -

extension DTO {
    struct Paddock: Equatable, Sendable {
        let transfers: [Transfer]
        let programUpdates: [ProgramUpdate]
        let birthdays: [Birthday]
    }

    struct PressLink: Equatable, Sendable {
        let name: String?
        let url: URL
    }

    struct RiderLink: Equatable, Sendable {
        let name: String
        let url: URL?
        let countryCode: String
    }

    struct Transfer: Equatable, Sendable {
        let date: String          // "20/09", no year
        let rider: RiderLink
        let teamName: String
    }

    struct ProgramUpdate: Equatable, Sendable {
        struct Change: Equatable, Sendable {
            let isAdded: Bool
            let raceName: String
        }

        let timeAgo: String       // "15m", "16h"
        let rider: RiderLink
        let changes: [Change]
    }

    struct Birthday: Equatable, Sendable {
        let rider: RiderLink
        let age: String
    }

    /// A PCS rider page (`rider/<slug>`), parsed best-effort for Paddock's rider screen.
    /// Facts share the CX rider page's label/value type so the same profile panel renders both.
    struct PCSRiderPage: Equatable, Sendable {
        let name: String
        let imageURL: URL?
        let team: String?
        let facts: [CXRiderPage.Fact]
    }
}

// MARK: - CX -

extension DTO {
    struct CX24Homepage: Equatable, Sendable, Decodable {
        struct Section: Equatable, Sendable, Hashable, Decodable {
            let title: String
            let races: [Race]
        }

        struct Race: Equatable, Sendable, Hashable, Decodable {
            let title: String
            let country: String
            let countryFlagURL: URL?
            let date: String
            let location: String
            let raceURL: URL?
            let categories: [Category]
        }

        struct Category: Equatable, Sendable, Hashable, Decodable {
            let title: String
            let categoryURL: URL?
            let winnerImageURL: URL?
            let podium: [Podium]
        }

        struct Podium: Equatable, Sendable, Hashable, Decodable {
            let position: Int
            let rider: String
            let riderURL: URL?
            let country: String
            let countryFlagURL: URL?
            let time: String
        }
        
        struct CategoryResult: Equatable, Sendable, Hashable, Decodable {
            let position: String
            let rider: String
            let age: String
            let team: String
            let time: String
            let countryFlagURL: URL?
            let raceVideosURL: URL?
            /// Defaulted so existing call sites and previews keep compiling.
            var riderURL: URL? = nil
        }

        let sections: [Section]
    }

    struct CXStandings: Equatable, Sendable, Decodable {
        struct Leader: Equatable, Sendable, Hashable, Decodable {
            let position: Int
            let rider: String
            let riderURL: URL?
            let countryFlagURL: URL?
            let points: String
        }

        struct Category: Equatable, Sendable, Hashable, Decodable {
            let title: String
            let url: URL?
            let leaders: [Leader]
            let leaderImageURL: URL?
        }

        struct Item: Equatable, Sendable, Hashable, Decodable {
            let title: String
            let url: URL?
            let logoURL: URL?
            let categories: [Category]
        }

        let items: [Item]
    }
    
    struct CXCalendarEvent: Equatable, Sendable, Hashable, Decodable {
        let date: String
        let race: String
        let raceClass: String
        let flagURL: URL?
        let winnerName: String

        let isCancelled: Bool
        let raceID: Int?
        let raceSlug: String?
        let raceURL: URL?
        let resultsURL: URL?
        let videoURL: URL?

        let websiteURL: URL?

        let raceCountry: String?
        let winnerURL: URL?
        let winnerCountry: String?
        let winnerFlagURL: URL?
    }

    /// What the on-device scrape of a race's cyclocross24 page (`/race/<slug>/`) yields.
    /// Every field is optional/empty-able: the page is parsed best-effort.
    struct CXRacePage: Equatable, Sendable, Decodable {
        struct PastWinner: Equatable, Sendable, Hashable, Decodable {
            let year: String
            let rider: String
            let riderURL: URL?
            let countryFlagURL: URL?
            let resultsURL: URL?
        }

        let title: String
        let summary: String
        let pastWinners: [PastWinner]
    }

    /// Everything the CX calendar-event detail screen loads on demand, on top of the
    /// `CXCalendarEvent` it was opened with. Each part is fetched independently, so any of
    /// them can come back empty without failing the others.
    struct CXEventDetail: Equatable, Sendable {
        let page: CXRacePage?
        let results: [CX24Homepage.CategoryResult]
        let videoURL: URL?

        static var empty: CXEventDetail {
            .init(page: nil, results: [], videoURL: nil)
        }
    }

    /// What the winner screen loads on demand: the rider page, and the winner's results row
    /// when the caller didn't already have it.
    struct CXWinnerDetail: Equatable, Sendable {
        let page: CXRiderPage?
        let result: CX24Homepage.CategoryResult?
    }

    /// A rider's cyclocross24 page (`/rider/<slug>/`), parsed by the `cxDetail` Cloud Function.
    struct CXRiderPage: Equatable, Sendable, Decodable {
        struct Fact: Equatable, Sendable, Hashable, Decodable {
            let label: String
            let value: String
        }

        struct Result: Equatable, Sendable, Hashable, Decodable {
            let date: String
            let race: String
            let position: String
            let raceURL: URL?
        }

        let name: String
        let avatarURL: URL?
        let facts: [Fact]
        let results: [Result]
    }
}

// MARK: - Course du Jour -

extension DTO {
    /// One day of coursedujour.com's TV schedule.
    struct CourseDuJourPage: Equatable, Sendable {
        /// A tab of the page's day strip.
        struct Day: Equatable, Hashable, Identifiable, Sendable {
            /// "2026-10-02"
            let date: String
            /// 0 is the site's today, -1 yesterday.
            let offset: Int
            let raceCount: Int
            var id: String { date }
        }

        struct Broadcaster: Equatable, Hashable, Identifiable, Sendable {
            let name: String
            /// "FI, SE"
            let regions: String
            let url: URL?
            let start: Date?
            let end: Date?
            var id: String { name }
        }

        struct Race: Equatable, Hashable, Identifiable, Sendable {
            let name: String
            /// "Stage 5"
            let stage: String?
            /// "2.Pro (Men)"
            let category: String
            let location: String
            let start: Date?
            let end: Date?
            let broadcasters: [Broadcaster]
            var id: String { [name, stage ?? "", start.map { "\($0.timeIntervalSince1970)" } ?? ""].joined(separator: "|") }
        }

        /// A discipline block: "Road", "CX", "Gravel".
        struct Section: Equatable, Hashable, Identifiable, Sendable {
            let discipline: String
            /// "1 race with live coverage", "no live coverage today"
            let caption: String
            let races: [Race]
            var id: String { discipline }
        }

        /// "2026-10-01"
        let date: String
        /// "Thursday, 1 October 2026"
        let heading: String
        /// When the site last refreshed its broadcast data.
        let updatedAt: Date?
        let days: [Day]
        let sections: [Section]
    }
}
