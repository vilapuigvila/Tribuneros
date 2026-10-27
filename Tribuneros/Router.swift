//
//  Router.swift
//  Tribuneros
//
//  Created by albert vila on 23/4/25.
//

import Foundation
import SwiftUI
import UIKit

final class Router: ObservableObject {
    
    enum Destination: Hashable {
        enum Detail: Hashable {
            case race(urlInfo: String)
        }
        enum CXZone: Hashable {
            case allRaces(series: CXRaces.RaceSeries?)
            case latestResults
            /// `category` is the tab it opens on (a category title); `nil` opens the first.
            case raceDetail(DTO.CX24Homepage.Race, category: String? = nil)
            case eventDetail(DTO.CXCalendarEvent)
            case riderDetail(CXRaces.RiderContext)
            /// `from` is the race detail the winner screen was opened from, so opening that same
            /// race again pops back instead of pushing a duplicate.
            /// `nil` when opened from a rider screen, where there's no race to go back to.
            case winnerDetail(CXRaces.Winner, from: DTO.CXCalendarEvent?)
            case standings
            /// Every Men Elite row of a race's results (`results` as the event detail loaded them).
            case fullResults(DTO.CXCalendarEvent, results: [DTO.CX24Homepage.CategoryResult])
            /// A rider's whole results table, grouped by season.
            case riderResults(CXRaces.RiderRef)
            /// A full ranking or series standings table, with its category chips.
            case ranking(CXRaces.RankingContext)
        }

        case nextToFinishRace(index: Int)
        case todayRaces
        case yesterdayResults
        case historyResults
        case racePreviews
        case raceResultDetail(HomeRaces.Representable.RaceFinished)
        case racePreview(HomeRaces.Representable.RacePreview)
        /// A LIVE Today race's PCS live page (`LiveRaceDetailView`).
        case liveRace(HomeRaces.LiveRace.Context)
        case detail(Detail)
        case cxZone(CXZone)
        case paddockRider(Paddock.RiderContext)
        /// A press site's native headlines screen.
        case paddockPress(Paddock.PressItem)
        /// A rider's whole current-season table.
        case paddockSeasonResults(Paddock.SeasonResultsContext)
        case settingsAcknowledgements
        case web(URL)
        /// A news page: like `web`, but opens in Safari Reader when the page supports it.
        case article(URL)
    }

    @Published var navPath = NavigationPath()
    /// The web page shown full screen over this tab (see `View.webPage(_:)`).
    @Published var webPage: WebPage?
    /// Hands a link to the system (Safari, or the app that claims it, e.g. YouTube); swapped in tests.
    var openExternally: (URL) -> Void = { url in
        Task { @MainActor in
            UIApplication.shared.open(url)
        }
    }

    // NavigationPath can't be inspected: a same-destination push is a double tap only while the path is still the length it was right after that push.
    private(set) var lastPushed: Destination?
    private var countAfterLastPush = 0

    func routeTo(_ destination: Destination) {
        switch destination {
        case .web(let url):
            webPage = WebPage(url: url)
        case .article(let url):
            webPage = WebPage(
                url: url,
                prefersReader: true
            )
        default:
            if destination == lastPushed, navPath.count == countAfterLastPush { return }
            navPath.append(destination)
            lastPushed = destination
            countAfterLastPush = navPath.count
        }
    }
    
    /// Leaves the app for `url`, unlike `.web`, which shows it in an in-app Safari sheet.
    func openInSystem(_ url: URL) {
        openExternally(url)
    }

    func popToPrevious() {
        navPath.removeLast()
    }
    
    func popScreens(_ amount: Int) {
        navPath.removeLast(amount)
    }
    
    func popToRoot() {
        navPath = NavigationPath()
    }
}

struct RouterV2 {
    
}
