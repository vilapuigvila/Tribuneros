//
//  HomeRaces.MockPreview.swift
//  Tribuneros
//
//  Standalone mock data + an interactive preview for the Today Races (Home)
//  screen, with no network call and no dependency on Requester/Interactor.
//  Kept in its own file on purpose so it never collides with whoever is
//  touching HomeRaces.MainView.swift / the card views / Colors.swift while
//  the redesign lands — this file only reads the public Representable/
//  ViewState/MainView contracts.
//

import SwiftUI

// MARK: - Mock data -

extension HomeRaces.Representable {
    /// A fully populated Home screen: every section has data, so every
    /// card shape (next to finish, results with a 3-rider podium)
    /// renders at once without touching the network.
    ///
    /// Spoiler mode starts ON (results visible) — `false` is the real app's
    /// own default for a first-time user (matches a fresh `HomeRacesDomain`),
    /// but that's the wrong default for a review mock: it would hide two of
    /// the four sections behind a tap, and while something else is driving
    /// `HomeRaces.MainView` with a fixed `.mockFull` (rather than through
    /// `HomeRacesMockHarness`, where the toggle is wired up) that tap is a
    /// no-op — so hidden-by-default would mean permanently hidden. Use
    /// `mockFull(spoilerModeOn: false)` to deliberately check that state.
    static var mockFull: HomeRaces.Representable {
        mockFull(spoilerModeOn: true)
    }

    /// Same data, both spoiler toggles set explicitly.
    static func mockFull(spoilerModeOn: Bool) -> HomeRaces.Representable {
        .init(
            sections: .init(
                title: "",
                spoilerMode: .init(
                    isSpoilerModeResultsToday: spoilerModeOn,
                    isSpoilerModeResultsYesterday: spoilerModeOn
                ),
                nextToFinish: RaceNext.mockFullList,
                racesFinished: RaceFinished.mockToday,
                yesterdayResults: RaceFinished.mockYesterday
            )
        )
    }
}

extension HomeRaces.Representable.RaceNext {
    static var mockFullList: [HomeRaces.Representable.RaceNext] {
        [
            .init(eta: "16:42", duration: "2h", name: "CRO Race - S1", category: "ME", raceType: "2.1", distance: "", urlPath: nil, flagCode: "hr", isLive: true),
            .init(eta: "17:20", duration: "2h", name: "Chrono des Nations", category: "ME", raceType: "1.1", distance: "", urlPath: nil, flagCode: "fr", isLive: false),
            .init(eta: "18:05", duration: "3h", name: "Coppa Bernocchi", category: "ME", raceType: "1.1", distance: "", urlPath: nil, flagCode: "it", isLive: true),
            .init(eta: "21:35", duration: "7h", name: "GP de Montréal", category: "ME", raceType: "1.UWT", distance: "", urlPath: nil, flagCode: "ca", isLive: false)
        ]
    }
}

extension HomeRaces.Representable.RaceFinished {
    static var mockToday: [HomeRaces.Representable.RaceFinished] {
        [
            .init(
                race: "Settimana Coppi e Bartali",
                raceDetails: "Stage 3",
                winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg"),
                podium: [
                    .init(position: "1", flag: nil, countryCode: "it", name: "GANNA Filippo", team: "INEOS Grenadiers", time: "3:41:26"),
                    .init(position: "2", flag: nil, countryCode: "it", name: "MILAN Jonathan", team: "Lidl-Trek", time: "+0:04"),
                    .init(position: "3", flag: nil, countryCode: "it", name: "ULISSI Diego", team: "UAE Team Emirates", time: "+0:09")
                ],
                isCancel: false
            ),
            .init(
                race: "Classic Brugge–De Panne",
                raceDetails: "One-day race",
                winnerImgURL: nil,
                podium: [
                    .init(position: "1", flag: nil, countryCode: "be", name: "PHILIPSEN Jasper", team: "Alpecin-Deceuninck", time: "4:22:18"),
                    .init(position: "2", flag: nil, countryCode: "be", name: "MERLIER Tim", team: "Soudal Quick-Step", time: "s.t."),
                    .init(position: "3", flag: nil, countryCode: "nl", name: "KOOIJ Olav", team: "Team Visma | Lease a Bike", time: "s.t.")
                ],
                isCancel: false
            )
        ]
    }

    static var mockYesterday: [HomeRaces.Representable.RaceFinished] {
        [
            .init(
                race: "Milano–Torino",
                raceDetails: "One-day race",
                winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg"),
                podium: [
                    .init(position: "1", flag: nil, countryCode: "be", name: "MERLIER Tim", team: "Soudal Quick-Step", time: "4:02:18")
                ],
                isCancel: false
            ),
            .init(
                race: "Settimana Coppi e Bartali",
                raceDetails: "Stage 2",
                winnerImgURL: nil,
                podium: [
                    .init(position: "1", flag: nil, countryCode: "it", name: "MILAN Jonathan", team: "Lidl-Trek", time: "3:58:44")
                ],
                isCancel: false
            )
        ]
    }
}

// MARK: - Interactive preview harness -

/// Wraps `HomeRaces.MainView` with just enough local `@State` to make the
/// spoiler toggles and the loading/error states actually tappable/selectable
/// in a Preview or a Simulator run — no ViewModel, no Interactor, no network.
/// `HomeRacesView` is hardcoded to `HomeRacesViewModel<HomeRacesInteractorImpl>`,
/// so this harness talks to `HomeRaces.MainView` directly instead (the same
/// decoupled state/action contract the ViewModel itself renders through).
private struct HomeRacesMockHarness: View {
    @State private var viewState: HomeRaces.ViewState
    @State private var isSpoilerModeResultsToday: Bool
    @State private var isSpoilerModeResultsYesterday: Bool

    init(initialState: HomeRaces.ViewState = .loaded(.mockFull)) {
        _viewState = State(initialValue: initialState)
        if case .loaded(let representable) = initialState {
            _isSpoilerModeResultsToday = State(initialValue: representable.sections.spoilerMode.isSpoilerModeResultsToday)
            _isSpoilerModeResultsYesterday = State(initialValue: representable.sections.spoilerMode.isSpoilerModeResultsYesterday)
        } else {
            _isSpoilerModeResultsToday = State(initialValue: false)
            _isSpoilerModeResultsYesterday = State(initialValue: false)
        }
    }

    var body: some View {
        HomeRaces.MainView(state: viewState) { action in
            switch action {
            case .spoilerModeResultToday:
                isSpoilerModeResultsToday.toggle()
                rebuild()
            case .spoilerModeResultYesterday:
                isSpoilerModeResultsYesterday.toggle()
                rebuild()
            case .onAppear, .onDisappear, .navigate, .openLink:
                break
            }
        }
    }

    private func rebuild() {
        guard case .loaded(let representable) = viewState else { return }
        viewState = .loaded(
            HomeRaces.Representable(
                sections: .init(
                    title: representable.sections.title,
                    spoilerMode: .init(
                        isSpoilerModeResultsToday: isSpoilerModeResultsToday,
                        isSpoilerModeResultsYesterday: isSpoilerModeResultsYesterday
                    ),
                    nextToFinish: representable.sections.nextToFinish,
                    racesFinished: representable.sections.racesFinished,
                    yesterdayResults: representable.sections.yesterdayResults
                )
            )
        )
    }
}

// MARK: - Previews -

#Preview("Home — mock, spoiler off") {
    HomeRacesMockHarness(initialState: .loaded(.mockFull(spoilerModeOn: false)))
}

#Preview("Home — mock, spoiler on") {
    HomeRacesMockHarness(initialState: .loaded(.mockFull(spoilerModeOn: true)))
}

#Preview("Home — loading") {
    HomeRacesMockHarness(initialState: .loading)
}

#Preview("Home — empty") {
    HomeRacesMockHarness(initialState: .error(.emtpyData))
}
