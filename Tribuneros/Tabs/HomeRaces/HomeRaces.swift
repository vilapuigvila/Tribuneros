//
//  HomeRaces.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import SwiftUI

enum HomeRaces {
    
    enum ViewState {
        case idle
        case loading
        case loaded(Representable)
        case error(ErrorView)
        
        var result: Representable {
            guard case .loaded(let result) = self else {
                return .init(sections: .init(title: "", nextToFinish: [], racesFinished: [], yesterdayResults: [], historyResults: []))
            }
            return result
        }
    }

    struct Representable {
        struct Section: Identifiable {
            let id = UUID()
            let title: String
            let nextToFinish: [RaceNext]
            let racesFinished: [RaceFinished]
            let yesterdayResults: [RaceFinished]
            let historyResults: [RaceFinished]
            var previews: [RacePreview] = []
            var firstFinishExpected: String? = nil
        }
        /// A homepage "Previews" entry; the `racePreview` route's payload.
        struct RacePreview: Identifiable, Hashable, Sendable {
            let id = UUID()
            let countdown: String
            let name: String
            let url: URL?
        }
        /// Hashable because it is the `raceResultDetail` route's payload (and `Action.openRaceResult`'s).
        struct RaceFinished: Identifiable, Hashable, Sendable {
            struct Winner: Identifiable, Hashable, Sendable {
                let id = UUID()
                let position: String
                let flag: URL?
                let countryCode: String
                let name: String
                let team: String
                let time: String
            }
            let id = UUID()
            
            let race: String
            let raceDetails: String
            let winnerImgURL: URL?
            let podium: [Winner]
            let isCancel: Bool
            var raceURL: URL? = nil
            var visibility: ResultVisibility = .shown
            var raceCountryCode: String = ""
            var spoilerCover: SpoilerCover = .classic
        }
        struct RaceNext: Identifiable {
            let id = UUID()

            let eta: String
            let duration: String
            let name: String
            let category: String
            let raceType: String
            let distance: String
            let urlPath: String?
            let flagCode: String
            var isLive: Bool = false
            var finishDate: Date? = nil
            var startTime: String? = nil
        }
        let sections: Section
        var staleCopy: StaleCopy? = nil
        var showSpoilerHint = false

        /// Stand-ins shaped like a real page, drawn redacted while it loads.
        static let placeholders = Representable(
            sections: Section(
                title: "",
                nextToFinish: (1...2).map { _ in
                    RaceNext(
                        eta: "00:00",
                        duration: "0H",
                        name: "Race name placeholder",
                        category: "UCI",
                        raceType: "1.UWT",
                        distance: "000",
                        urlPath: nil,
                        flagCode: ""
                    )
                },
                racesFinished: placeholderResults,
                yesterdayResults: placeholderResults,
                historyResults: placeholderResults
            )
        )

        static let placeholderResults: [RaceFinished] = (1...4).map { _ in
            RaceFinished(
                race: "Race name placeholder",
                raceDetails: "",
                winnerImgURL: nil,
                podium: [
                    RaceFinished.Winner(
                        position: "1",
                        flag: nil,
                        countryCode: "",
                        name: "Rider name",
                        team: "",
                        time: "0:00:00"
                    )
                ],
                isCancel: false,
                visibility: .placeholder
            )
        }
    }
    
    /// How a result card shows its values: as they are, hidden behind the spoiler chip (title kept), or fully redacted.
    enum ResultVisibility {
        case shown
        case hidden
        case placeholder
    }

    /// The page shown is an expired cached copy: when it was fetched, and whether the device is offline.
    struct StaleCopy: Equatable {
        let savedAt: Date
        let isOffline: Bool
    }

    enum Action: Hashable, Sendable {
        case onAppear
        case onDisappear
        case toggleReveal(Representable.RaceFinished)
        case dismissSpoilerHint
        case navigate(Navigate)
        case openLink(URL)
        case openRaceResult(Representable.RaceFinished)
        case openRacePreview(Representable.RacePreview)
    }

    enum Navigate: Hashable, Sendable {
        enum Detail: Hashable, Sendable {
            case race(name: String?)
        }
        case nextToFinishRace(index: Int)
        /// A LIVE Today race: opens its live page (`LiveRaceDetailView`) instead of the race detail.
        case liveRace(index: Int)
        case todayRaces
        case todayResults
        case yesterdayResults
        case historyResults
        case tomorrowRaces
        case detail(Detail)
    }
    
    enum ErrorView: Error {
        case missingStationCode
        case networkFailure
        case raceInfoFetchFailure
        case emtpyData

        /// What the error screen says for a failure: never the raw case name.
        var message: String {
            L10n.tr("Couldn’t load the races. Check your connection and try again.")
        }
        
        /*
        init(stationInteractorError: HomeStationInteractorImpl.ErrorReason) {
            switch stationInteractorError {
            case .missingCode:
                self = .missingStationCode
            default:
                self = .networkFailure
            }
        }*/
    }
}

extension HomeRaces.Representable.RaceFinished {
    /// The PCS results page identifies a race across Results today and yesterday; `id` changes every load.
    var revealKey: String {
        raceURL?.absoluteString ?? race
    }

    var winner: Winner? {
        podium.first.flatMap { $0.name.isEmpty ? nil : $0 }
    }
}

extension HomeRaces.Representable.RaceFinished.Winner {
    init(_ dto: DTO.TodayResult.Winner) {
        self.init(
            position: dto.position,
            flag: dto.flag,
            countryCode: dto.countryCode ?? "",
            name: dto.name,
            team: dto.team,
            time: dto.time
        )
    }
}
