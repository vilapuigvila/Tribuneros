//
//  Router.swift
//  Tribuneros
//
//  Created by albert vila on 23/4/25.
//

import Foundation
import SwiftUI

class Router: ObservableObject {
    
    enum Destination: Hashable {
        enum Detail: Hashable {
            case race(urlInfo: String)
        }
        case nextToFinish
        case detail(Detail)
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
