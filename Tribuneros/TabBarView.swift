//
//  TabBarView.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import SwiftUI
/*
final class AppContainer {
    let router = Router()
    let homeRacesInteractor = HomeRacesInteractorImpl()
    
    lazy var homeRacesViewModel = HomeRacesViewModel(
        interactor: homeRacesInteractor,
        router: router
    )
}*/

enum Tab {
    case home, hateZone, cxZone
}

struct TabBarView: View {
    
//    @State private var selectedTab: Tab = .home
//    @StateObject private var router: Router
//    private var homeRacesViewModel: HomeRacesViewModel<HomeRacesInteractorImpl>
    @StateObject private var homeRouter: Router
    @StateObject private var cxRouter: Router
    let homeRacesViewModel: HomeRacesViewModel<HomeRacesInteractorImpl>
    let cxRacesViewModel: CXRaces.ViewModel<CXRaces.InteractorImpl>
    
    
    static let hateZoneRepresentable: [HateZone.Representable] = [
        .init(title: "Ciclismo 2005", url: URL(string: "http://ciclismo2005.com")),
        .init(title: "Escape Collective", url: URL(string: "https://escapecollective.com")),
        .init(title: "Cycling News", url: URL(string: "https://www.cyclingnews.com")),
        .init(title: "Cycling Update", url: URL(string: "https://cyclinguptodate.com")),
        .init(title: "Ciclismo al dia", url: URL(string: "https://ciclismoaldia.es")),
        .init(title: "Joan Seguidor", url: URL(string: "https://joanseguidor.com"))
    ]
    
    init() {
        let homeRouter = Router()
        let cxRouter = Router()
        _homeRouter = StateObject(wrappedValue: homeRouter)
        _cxRouter = StateObject(wrappedValue: cxRouter)
        homeRacesViewModel = HomeRacesViewModel(
            interactor: HomeRacesInteractorImpl(),
            router: homeRouter
        )
        cxRacesViewModel = CXRaces.ViewModel(
            router: cxRouter,
            interactor: CXRaces.InteractorImpl()
        )
    }
    
    var body: some View {
        TabView {
            NavigationStack(path: $homeRouter.navPath) {
                HomeRacesView(
                    viewModel: homeRacesViewModel
                )
            }
            .tabItem {
                Image(systemName: "figure.indoor.cycle")
                Text("Today Races")
            }
            .tag(Tab.home)
            
            // CX Zone -
            
            NavigationStack(path: $cxRouter.navPath) {
                CXRacesRacesView(viewModel: cxRacesViewModel)
            }
            .tabItem {
                Image(systemName: "bicycle.sensor.tag.radiowaves.left.and.right.fill")
                Text("CX Zone")
            }
            .tag(Tab.cxZone)
            
            // Hate zone -
            
            HateZoneView(representable: Self.hateZoneRepresentable)
                .tabItem {
                    Image(systemName: "wrongwaysign.fill")
                    Text("Hate Zone")
                }
                .tag(Tab.hateZone)
        }
    }
    
    /*
    private func tabSelection() -> Binding<Tab> {
        Binding { //this is the get block
            self.selectedTab
        } set: { tappedTab in
            if tappedTab == self.selectedTab {
                //User tapped on the tab twice == Pop to root view
                if homeNavigationStack.isEmpty {
                    //User already on home view, scroll to top
                } else {
                    homeNavigationStack = []
                }
            }
            //Set the tab to the tabbed tab
            self.selectedTab = tappedTab
        }
    }*/
}

#Preview {
    TabBarView()
}
