//
//  TabBarView.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import SwiftUI
import UIKit
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
    
    @State private var selectedTab: Tab = .home
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
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeRouter.navPath) {
                HomeRacesView(
                    viewModel: homeRacesViewModel
                )
            }
            .tag(Tab.home)
            
            // CX Zone -
            
            NavigationStack(path: $cxRouter.navPath) {
                CXRacesRacesView(viewModel: cxRacesViewModel)
            }
            .tag(Tab.cxZone)
            
            // Hate zone -
            
            HateZoneView(representable: Self.hateZoneRepresentable)
                .tag(Tab.hateZone)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(
                selectedTab: $selectedTab,
                cxZoneSymbolName: "bicycle",
                onTabTap: handleTabSelection
            )
        }
    }

    private func handleTabSelection(_ tab: Tab) {
        if selectedTab == tab {
            popToRoot(for: tab)
        } else {
            selectedTab = tab
        }
    }

    private func popToRoot(for tab: Tab) {
        switch tab {
        case .home:
            homeRouter.popToRoot()
        case .hateZone:
            break
        case .cxZone:
            cxRouter.popToRoot()
        }
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let cxZoneSymbolName: String
    let onTabTap: (Tab) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TribunerosDivider(height: 0.5, color: .white.opacity(0.1))
            
            HStack {
                TabBarButton(
                    title: "Today Races",
                    systemImage: "figure.indoor.cycle",
                    isSelected: selectedTab == .home
                ) {
                    onTabTap(.home)
                }
                
                Spacer(minLength: 0)
                
                TabBarButton(
                    title: "CX Zone",
                    systemImage: cxZoneSymbolName,
                    isSelected: selectedTab == .cxZone,
                    animateWhenSelected: true
                ) {
                    onTabTap(.cxZone)
                }
                
                Spacer(minLength: 0)
                
                TabBarButton(
                    title: "Hate Zone",
                    systemImage: "wrongwaysign.fill",
                    isSelected: selectedTab == .hateZone
                ) {
                    onTabTap(.hateZone)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.black.opacity(0.95))
        }
    }
}

private struct TabBarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let animateWhenSelected: Bool
    let action: () -> Void
    
    init(
        title: String,
        systemImage: String,
        isSelected: Bool,
        animateWhenSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.animateWhenSelected = animateWhenSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                icon
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .cyan : .gray)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isSelected ? .cyan : .gray)
                    .lineLimit(1)
            }
            .frame(minWidth: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var icon: some View {
        let image = Image(systemName: systemImage)
        if animateWhenSelected && isSelected {
            if #available(iOS 18.0, *) {
                image.symbolEffect(.bounce.down.byLayer, options: .repeat(.periodic(2, delay: 0.5)))
            } else {
                image
            }
        } else {
            image
        }
    }
}

#Preview("Tab bar view") {
    TabBarView()
}
