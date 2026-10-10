//
//  TabBarView.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import SwiftUI
import UIKit

enum Tab {
    case home, paddock, cxZone, settings
}

struct TabBarView: View {

    /// Owned by `LocalizedRoot`, so it survives a language change.
    @Binding var selectedTab: Tab
    /// The bar hides while typing; as a bottom inset it would otherwise ride up on the keyboard.
    @State private var isKeyboardVisible = false
    @StateObject private var homeRouter: Router
    @StateObject private var cxRouter: Router
    @StateObject private var paddockRouter: Router
    @StateObject private var settingsRouter: Router

    let homeRacesViewModel: HomeRacesViewModel<HomeRacesInteractorImpl>
    let cxRacesViewModel: CXRaces.ViewModel<CXRaces.InteractorImpl>
    let paddockViewModel: Paddock.ViewModel<Paddock.InteractorImpl>
    let settingsViewModel: Settings.ViewModel<Settings.InteractorImpl>

    init(selectedTab: Binding<Tab>) {
        _selectedTab = selectedTab
        let homeRouter = Router()
        let cxRouter = Router()
        let paddockRouter = Router()
        let settingsRouter = Router()
        _homeRouter = StateObject(wrappedValue: homeRouter)
        _cxRouter = StateObject(wrappedValue: cxRouter)
        _paddockRouter = StateObject(wrappedValue: paddockRouter)
        _settingsRouter = StateObject(wrappedValue: settingsRouter)
        homeRacesViewModel = HomeRacesViewModel(
            interactor: HomeRacesInteractorImpl(),
            router: homeRouter
        )
        cxRacesViewModel = CXRaces.ViewModel(
            router: cxRouter,
            interactor: CXRaces.InteractorImpl()
        )
        paddockViewModel = Paddock.ViewModel(
            router: paddockRouter,
            interactor: Paddock.InteractorImpl()
        )
        settingsViewModel = Settings.ViewModel(
            router: settingsRouter,
            interactor: Settings.InteractorImpl()
        )
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeRouter.navPath) {
                HomeRacesView(
                    viewModel: homeRacesViewModel
                )
            }
            .webPage($homeRouter.webPage)
            .tag(Tab.home)
            
            // CX Zone -
            
            NavigationStack(path: $cxRouter.navPath) {
                CXRacesRacesView(viewModel: cxRacesViewModel)
            }
            .webPage($cxRouter.webPage)
            .tag(Tab.cxZone)
            
            // Paddock -

            NavigationStack(path: $paddockRouter.navPath) {
                PaddockView(viewModel: paddockViewModel)
            }
            .webPage($paddockRouter.webPage)
            .tag(Tab.paddock)

            // Settings -

            NavigationStack(path: $settingsRouter.navPath) {
                SettingsView(viewModel: settingsViewModel)
            }
            .webPage($settingsRouter.webPage)
            .tag(Tab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    cxZoneSymbolName: "bicycle",
                    onTabTap: handleTabSelection
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }
    }

    private func handleTabSelection(_ tab: Tab) {
        if selectedTab == tab {
            if tab == .home {
                refreshHomeRacesIfNeeded()
            }
            if tab == .paddock {
                paddockViewModel.action(.didRequestRefresh)
            }
            popToRoot(for: tab)
        } else {
            selectedTab = tab
        }
    }

    private func popToRoot(for tab: Tab) {
        switch tab {
        case .home:
            homeRouter.popToRoot()
        case .paddock:
            paddockRouter.popToRoot()
        case .cxZone:
            cxRouter.popToRoot()
        case .settings:
            settingsRouter.popToRoot()
        }
    }

    private func refreshHomeRacesIfNeeded() {
        if case .loading = homeRacesViewModel.stateView {
            return
        }
        homeRacesViewModel.action(.onAppear)
    }
}

private struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let cxZoneSymbolName: String
    let onTabTap: (Tab) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TribunerosDivider(height: 0.5, color: .tribuneru(.vaporTextPrimary).opacity(0.10))

            HStack {
                TabBarButton(
                    title: L10n.tr("Today Races"),
                    systemImage: "figure.indoor.cycle",
                    isSelected: selectedTab == .home
                ) {
                    onTabTap(.home)
                }
                
                Spacer(minLength: 0)
                
                TabBarButton(
                    title: L10n.tr("CX Zone"),
                    systemImage: cxZoneSymbolName,
                    isSelected: selectedTab == .cxZone,
                    animateWhenSelected: true
                ) {
                    onTabTap(.cxZone)
                }
                
                Spacer(minLength: 0)
                
                TabBarButton(
                    title: L10n.tr("Paddock"),
                    systemImage: "megaphone.fill",
                    isSelected: selectedTab == .paddock
                ) {
                    onTabTap(.paddock)
                }

                Spacer(minLength: 0)

                TabBarButton(
                    title: L10n.tr("Settings"),
                    systemImage: "gearshape",
                    isSelected: selectedTab == .settings
                ) {
                    onTabTap(.settings)
                }
                .accessibilityIdentifier("tab.settings")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.tribuneru(.vaporPageBackground).opacity(0.95))
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
                    .foregroundColor(isSelected ? .tribuneru(.vaporAccent) : .tribuneru(.vaporTextSecondary))
                TribuneruText(
                    content: title,
                    style: .vaporTabLabel,
                    color: isSelected ? .tribuneru(.vaporAccent) : .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            .frame(minWidth: 64)
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
    TabBarView(selectedTab: .constant(.home))
}
