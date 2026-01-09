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
            cells.compactMap {
                NextToFinishResult(
                    eta: $0[1],
                    duration: $0[2],
                    name: $0[3],
                    category: $0[4],
                    raceType: $0[5],
                    distance: $0[6],
                    urlPath: $0[7],
                    flagCode: $0[8])
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
                    nonFatalCrashlytics(false, "new StageProfile.ProfileImageType case: \(rawValue)", domain: .tribuneru)
                    self = .none
                    
                }
            }
        }
        let type: ProfileImageType
        let url: String
    }
}

// MARK: - CX -

extension DTO {
    struct CX24Homepage: Equatable, Sendable {
        struct Section: Equatable, Sendable {
            let title: String
            let races: [Race]
        }

        struct Race: Equatable, Sendable {
            let title: String
            let country: String
            let countryFlagURL: URL?
            let date: String
            let location: String
            let raceURL: URL?
            let categories: [Category]
        }

        struct Category: Equatable, Sendable {
            let title: String
            let categoryURL: URL?
            let winnerImageURL: URL?
            let podium: [Podium]
        }

        struct Podium: Equatable, Sendable {
            let position: Int
            let rider: String
            let riderURL: URL?
            let country: String
            let countryFlagURL: URL?
            let time: String
        }

        let sections: [Section]
    }

    struct CXStandings: Equatable, Sendable {
        struct Leader: Equatable, Sendable, Hashable {
            let position: Int
            let rider: String
            let riderURL: URL?
            let countryFlagURL: URL?
            let points: String
        }

        struct Category: Equatable, Sendable, Hashable {
            let title: String
            let url: URL?
            let leaders: [Leader]
            let leaderImageURL: URL?
        }

        struct Item: Equatable, Sendable, Hashable {
            let title: String
            let url: URL?
            let logoURL: URL?
            let categories: [Category]
        }

        let items: [Item]
    }
    
    struct CXCalendarEvent: Equatable, Sendable {
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
}
