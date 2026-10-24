//
//  TabBarView.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import SwiftUI
import UIKit

enum Tab {
    case home, paddock, cxZone, tifosi, settings

    /// CX Zone from 19 October through 31 January (inclusive), Today Races otherwise.
    static func launchTab(
        on date: Date,
        calendar: Calendar = .current
    ) -> Tab {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return .home }
        let isCxSeason = month == 11 || month == 12 || month == 1 || (month == 10 && day >= 19)
        return isCxSeason ? .cxZone : .home
    }

    static var launchTabAtLaunch: Tab {
        #if DEBUG
        let override = launchDateOverride(
            environment: ProcessInfo.processInfo.environment,
            launchValue: UserDefaults.standard.string(forKey: "launchDate")
        )
        if let override { return launchTab(on: override) }
        if HomeRaces.MockScenario.current != nil { return .home }
        #endif
        return launchTab(on: Date())
    }

    #if DEBUG
    static func launchDateOverride(
        environment: [String: String],
        launchValue: String?,
        calendar: Calendar = .current
    ) -> Date? {
        guard let value = environment["LAUNCH_DATE"] ?? launchValue else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
    #endif
}

struct TabBarView: View {

    /// Owned by `LocalizedRoot`, so it survives a language change.
    @Binding var selectedTab: Tab
    /// The bar hides while typing; as a bottom inset it would otherwise ride up on the keyboard.
    @State private var isKeyboardVisible = false
    @State private var tabBarHeight: CGFloat = 0
    @StateObject private var homeRouter: Router
    @StateObject private var cxRouter: Router
    @StateObject private var paddockRouter: Router
    @StateObject private var tifosiRouter: Router
    @StateObject private var settingsRouter: Router

    // StateObject, not let: `LocalizedRoot` re-inits this view on every tab change, and fresh view models would never load.
    @StateObject private var homeRacesViewModel: HomeRacesViewModel<HomeRacesInteractorImpl>
    @StateObject private var cxRacesViewModel: CXRaces.ViewModel<CXRaces.InteractorImpl>
    @StateObject private var paddockViewModel: Paddock.ViewModel<Paddock.InteractorImpl>
    @StateObject private var tifosiViewModel: Tifosi.ViewModel<Tifosi.InteractorImpl>
    @StateObject private var settingsViewModel: Settings.ViewModel<Settings.InteractorImpl>

    init(selectedTab: Binding<Tab>) {
        _selectedTab = selectedTab
        let homeRouter = Router()
        let cxRouter = Router()
        let paddockRouter = Router()
        let tifosiRouter = Router()
        let settingsRouter = Router()
        _homeRouter = StateObject(wrappedValue: homeRouter)
        _cxRouter = StateObject(wrappedValue: cxRouter)
        _paddockRouter = StateObject(wrappedValue: paddockRouter)
        _tifosiRouter = StateObject(wrappedValue: tifosiRouter)
        _settingsRouter = StateObject(wrappedValue: settingsRouter)
        _homeRacesViewModel = StateObject(
            wrappedValue: HomeRacesViewModel(
                interactor: HomeRacesInteractorImpl(),
                router: homeRouter
            )
        )
        _cxRacesViewModel = StateObject(
            wrappedValue: CXRaces.ViewModel(
                router: cxRouter,
                interactor: CXRaces.InteractorImpl()
            )
        )
        _paddockViewModel = StateObject(
            wrappedValue: Paddock.ViewModel(
                router: paddockRouter,
                interactor: Paddock.InteractorImpl()
            )
        )
        _tifosiViewModel = StateObject(
            wrappedValue: Tifosi.ViewModel(
                router: tifosiRouter,
                interactor: Tifosi.InteractorImpl()
            )
        )
        _settingsViewModel = StateObject(
            wrappedValue: Settings.ViewModel(
                router: settingsRouter,
                interactor: Settings.InteractorImpl()
            )
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
            .tag(Tab.cxZone)
            
            // Paddock -

            NavigationStack(path: $paddockRouter.navPath) {
                PaddockView(viewModel: paddockViewModel)
            }
            .webPage($paddockRouter.webPage)
            .tag(Tab.paddock)

            // Tifosi -

            NavigationStack(path: $tifosiRouter.navPath) {
                TifosiView(viewModel: tifosiViewModel)
            }
            .tag(Tab.tifosi)

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
                    onTabTap: handleTabSelection
                )
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { tabBarHeight = $0 }
            }
        }
        .environment(\.tabBarHeight, tabBarHeight)
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
        case .tifosi:
            tifosiRouter.popToRoot()
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

extension EnvironmentValues {
    /// Height of `CustomTabBar` above the device's bottom inset; the tab pages' safe area doesn't include it.
    @Entry var tabBarHeight: CGFloat = 0
}

private struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    let onTabTap: (Tab) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            TribunerosDivider(height: 0.5, color: .tribuneru(.vaporTextPrimary).opacity(0.10))

            HStack {
                TabBarButton(
                    title: L10n.tr("Road"),
                    imageName: "TabRoad",
                    isSelected: selectedTab == .home
                ) {
                    onTabTap(.home)
                }
                .accessibilityIdentifier("tab.home")
                
                Spacer(minLength: 0)
                
                TabBarButton(
                    title: L10n.tr("CX Zone"),
                    imageName: "TabCXZone",
                    selectedColor: .mudAccent,
                    isSelected: selectedTab == .cxZone
                ) {
                    onTabTap(.cxZone)
                }
                
                Spacer(minLength: 0)
                
                TabBarButton(
                    title: L10n.tr("Paddock"),
                    imageName: "TabPaddock",
                    selectedColor: .kitAccent,
                    isSelected: selectedTab == .paddock
                ) {
                    onTabTap(.paddock)
                }

                Spacer(minLength: 0)

                TabBarButton(
                    title: L10n.tr("Tifosi"),
                    imageName: "TabTifosi",
                    selectedColor: .tifosiAccent,
                    isSelected: selectedTab == .tifosi
                ) {
                    onTabTap(.tifosi)
                }

                Spacer(minLength: 0)

                TabBarButton(
                    title: L10n.tr("Settings"),
                    imageName: "TabSettings",
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
    let imageName: String
    var selectedColor: Color.Palette = .vaporAccent
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color.Palette { isSelected ? selectedColor : .vaporTextSecondary }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: 24,
                        height: 24
                    )
                    .foregroundColor(.tribuneru(tint))
                TribuneruText(
                    content: title,
                    style: .vaporTabLabel,
                    color: .tribuneru(tint),
                    lineLimit: 1
                )
            }
            .frame(minWidth: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Tab bar view") {
    TabBarView(selectedTab: .constant(.home))
}
