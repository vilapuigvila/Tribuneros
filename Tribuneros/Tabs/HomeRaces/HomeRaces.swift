//
//  HomeRaces.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import SwiftUI

public protocol DecoupledView {
    associatedtype Representable: Sendable
    associatedtype Action: Sendable
    var representable: Representable { get }
    var action: (Action) -> Void { get }
    
    init(representable: Representable, action: @escaping (Action) -> Void)
}

//enum LoadingRepresentable<R: Sendable> {
//    case idle
//    case loading
//    case loaded(R)
//    case error(ErrorRepresentable)
//}

typealias LoadingRepresentable<R> = RawLoadingRepresentable<R, ErrorRepresentable>

enum RawLoadingRepresentable<R: Sendable, E: Sendable> {
    case idle
    case loading
    case loaded(R)
    case error(E)
}

enum LoadingAction<A: Sendable>: Sendable {
    case content(A)
    case retry
}

struct LoadingViewContainer<R: DecoupledView & View>: View {

    let representable: LoadingRepresentable<R.Representable>
    let action: (LoadingAction<R.Action>) -> Void
    
    var body: some View {
        Group {
            switch representable {
            case .idle:
                Text("Hello, World!")
            case .loading:
                ProgressView()
            case .loaded(let representable):
                R(representable: representable) { action(.content($0)) }
            case .error(let errorView):
                VStack {
                    Text(errorView.title)
                        .onTapGesture {
                            action(.retry)
                        }
                }
            }
        }
        .onAppear {
//            action(.onAppear)
        }
    }
}


public struct ErrorRepresentable: Equatable {
    public let title: String
    public let subtitle: String
    public let buttonTitle: String
}


enum HomeRaces {
    
    enum ViewState {
        case idle
        case loading
        case loaded(Representable)
        case error(ErrorView)
        
        var result: Representable {
            guard case .loaded(let result) = self else {
                return .init(sections: .init(title: "", spoilerMode: .empty, nextToFinish: [], racesFinished: [], yesterdayResults: [], tomorrowRaces: []))
            }
            return result
        }
    }
    
    struct Representable {
        struct Section: Identifiable {
            let id = UUID()
            let title: String
            let spoilerMode: SpoilerMode
            let nextToFinish: [RaceNext]
            let racesFinished: [RaceFinished]
            let yesterdayResults: [RaceFinished]
            let tomorrowRaces: [RaceTomorrow]
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
            let raceDetails: String
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
        }
        struct RaceTomorrow: Identifiable {
            let id = UUID()
            
            let start: String
            let eta: String
            let name: String
            let url: URL?
        }
        let sections: Section
    }
    
    struct SpoilerMode: Identifiable {
        let id = UUID()
        let isSpoilerModeResultsToday: Bool
        let isSpoilerModeResultsYesterday: Bool
        
        static var empty: Self {
            .init(isSpoilerModeResultsToday: false, isSpoilerModeResultsYesterday: false)
        }
    }
    
    enum Action: Hashable, Sendable {
        case onAppear
        case onDisappear
        case request(date: Date)
        case selectedHomeStation(String)
        case spoilerModeResultToday
        case spoilerModeResultYesterday
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

struct DemoContentView: View, DecoupledView {
    struct Representable: Sendable {
        let title: String
        let username: String
    }
    enum Action: Sendable {
        case edit
        case delete
    }
    
    let representable: Representable
    let action: (Action) -> Void
    
    var body: some View {
        VStack {
            Text(representable.title)
            Text(representable.username)
            
            Button("Edit") {
                action(.edit)
            }
            Button("Delete") {
                action(.delete)
            }
        }
    }
}

extension DemoContentView.Representable {
    static var mock: Self {
        .init(title: "Title", username: "Username")
    }
}

struct DemoView: View {
    let representable: LoadingRepresentable<DemoContentView.Representable>
    let action: (LoadingAction<DemoContentView.Action>) -> Void
    
    var body: some View {
        LoadingViewContainer<DemoContentView>(representable: representable, action: action)
    }
}

//#Preview {
//    let representable = LoadingRepresentable<DemoContentView.Representable>.loaded(.mock)
//    
//    LoadingViewContainer<DemoContentView>(representable: representable) { action in
//        
//    }
//}

#Preview {
    let representable = LoadingRepresentable<DemoContentView.Representable>.loaded(.mock)
    
    DemoView(representable: representable) { action in
        
    }
}
