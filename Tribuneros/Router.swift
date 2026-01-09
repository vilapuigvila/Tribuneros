//
//  Router.swift
//  Tribuneros
//
//  Created by albert vila on 23/4/25.
//

import Foundation
import SwiftUI

final class Router: ObservableObject {
    
    enum Destination: Hashable {
        enum Detail: Hashable {
            case race(urlInfo: String)
        }
        enum CXZone: Hashable {
            case allRaces
            case latestResults
            case standings
        }
        
        case nextToFinishRace(index: Int)
        case detail(Detail)
        case cxZone(CXZone)
    }
    
    @Published var navPath = NavigationPath()
    
    func routeTo(_ destination: Destination) {
        navPath.append(destination)
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
