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
    /// A fully populated Home screen: all four sections have data, so every
    /// card shape (next to finish, results with a 3-rider podium, tomorrow)
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
                liveStats: [],
                nextToFinish: RaceNext.mockFullList,
                racesFinished: RaceFinished.mockToday,
                yesterdayResults: RaceFinished.mockYesterday,
                tomorrowRaces: RaceTomorrow.mockFullList
            )
        )
    }
}

extension HomeRaces.Representable.RaceNext {
    static var mockFullList: [HomeRaces.Representable.RaceNext] {
        [
            .init(eta: "16:58", duration: "6h 48m", name: "Milano–Sanremo", category: "UCI", raceType: "1.UWT", distance: "288", urlPath: nil, flagCode: "it"),
            .init(eta: "17:05", duration: "4h 21m", name: "Volta a Catalunya", category: "UCI", raceType: "2.UWT", distance: "142", urlPath: nil, flagCode: "es"),
            .init(eta: "17:20", duration: "4h 02m", name: "Gran Premio Industria", category: "UCI", raceType: "1.1", distance: "165", urlPath: nil, flagCode: "it"),
            .init(eta: "17:45", duration: "3h 24m", name: "Trofeo Alfredo Binda", category: "UCI", raceType: "1.WWT", distance: "132", urlPath: nil, flagCode: "it")
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
                    .init(position: "1", flag: nil, countryCode: "be", name: "MERLIER Tim", team: "Soudal Quick-Step", time: "4:02:18"),
                    .init(position: "-", flag: nil, countryCode: "", name: "", team: "", time: ""),
                    .init(position: "-", flag: nil, countryCode: "", name: "", team: "", time: "")
                ],
                isCancel: false
            ),
            .init(
                race: "Settimana Coppi e Bartali",
                raceDetails: "Stage 2",
                winnerImgURL: nil,
                podium: [
                    .init(position: "1", flag: nil, countryCode: "it", name: "MILAN Jonathan", team: "Lidl-Trek", time: "3:58:44"),
                    .init(position: "-", flag: nil, countryCode: "", name: "", team: "", time: ""),
                    .init(position: "-", flag: nil, countryCode: "", name: "", team: "", time: "")
                ],
                isCancel: false
            )
        ]
    }
}

extension HomeRaces.Representable.RaceTomorrow {
    static var mockFullList: [HomeRaces.Representable.RaceTomorrow] {
        [
            .init(start: "10:45", eta: "15:30", name: "Settimana Coppi e Bartali · Stage 4", url: nil),
            .init(start: "11:20", eta: "16:12", name: "Volta a Catalunya · Stage 8", url: nil),
            .init(start: "12:00", eta: "16:40", name: "Per Sempre Alfredo", url: nil)
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
            case .onAppear, .onDisappear, .navigate:
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
                    liveStats: representable.sections.liveStats,
                    nextToFinish: representable.sections.nextToFinish,
                    racesFinished: representable.sections.racesFinished,
                    yesterdayResults: representable.sections.yesterdayResults,
                    tomorrowRaces: representable.sections.tomorrowRaces
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
