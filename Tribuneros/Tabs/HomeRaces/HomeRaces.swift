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
                return .init(sections: .init(title: "", nextToFinish: [], racesFinished: [], yesterdayResults: []))
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
        }
        struct RaceFinished: Identifiable {
            struct Winner: Identifiable {
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
            let winnerImgURL: URL?
            let podium: [Winner]
            let isCancel: Bool
        }
        struct RaceNext: Identifiable {
            let id = UUID()
            
            let eta: String
            let duration: String
            let name: String
            let category: String
            let raceType: String
            let distance: String
            let isSpoilerModeOn: Bool
        }
        let sections: Section
    }
    
    enum Action: Hashable, Sendable {
        case onAppear
        case onDisappear
        case request(date: Date)
        case selectedHomeStation(String)
    }
    
    enum ErrorView: Error {
        case missingStationCode
        case networkFailure
        
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

//#Preview {
//    HomeRaces.MainView()
//}
