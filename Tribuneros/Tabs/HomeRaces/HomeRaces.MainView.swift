//
//  HomeRaces.MainView.swift
//  Tribuneros
//
//  Created by albert vila on 10/3/25.
//

import SwiftUI

struct HomeRacesView: View {
    @ObservedObject var viewModel: HomeRacesViewModel<HomeRacesInteractorImpl>
    
    var body: some View {
        HomeRaces.MainView(state: viewModel.stateView) {
            viewModel.action($0)
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            let _ = print("avvp [Navigation] - \(destination)")
            switch destination {
            case .nextToFinishRace(let index):
                if let urlPath = viewModel.stateView.result.sections.nextToFinish[index].urlPath {
                    NextToFinishRaceDetail(urlInfo: urlPath)
                } else {
                    EmptyView()
                }
//                .navigationTitle("NEXT TO FINISH")
            default:
                EmptyView()
            }
        }
        .navigationTitle("PRO CYCLING STATS")
    }
}

extension HomeRaces {
    
    struct MainView: View {
        @Environment(\.safeAreaInsets) private var safeAreaInsets
        @State private var retryCount = 0
//        @State private var didRequestOnAppear = false
        
        private let heightCardView: Double = 100
        private let spacingRows: Double = 20
        private let columns = [
            GridItem(.flexible(), spacing: 0)
        ]
        
        let state: HomeRaces.ViewState
        let action: (HomeRaces.Action) -> Void
        
        var body: some View {
            Group {
                switch state {
                case .idle:
                    Text("Hello, World!")
                case .loading:
                    VStack {
                        LoaderView(
                            title: "Loading races…",
                            subtitle: "Fetching latest data"
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tribuneru(.vaporPageBackground))
                case .loaded(let representable):
//                    NavigationStack {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: spacingRows) {

                                /// - LiveStats -
                                buildLiveStatsView(representable)

                                /// - Next to Finish -
                                buildNextToFinishView(representable)
                                
                                /// - Results today -
                                buildResultsTodayView(representable)
                                
                                /// - Results yesterday -
                                buildResultsYesterdayView(representable)
                                
                                /// - Tomorrow races -
                                buildTomorrowRaces(representable)
                                
                                Color.clear
                                    .frame(height: safeAreaInsets.bottom * 2 + safeAreaInsets.bottom)
                            }
                            .padding()
                    }
                    .background(Color.tribuneru(.vaporPageBackground))
                    
                case .error(let errorView):
                    VStack(spacing: 20) {
                        Spacer(minLength: safeAreaInsets.top + 20)
                        switch errorView {
                        case .emtpyData:
                            ErrorCardView.emptyData(
                                showTryAgainButton: retryCount < 3
                            ) {
                                retryCount += 1
                                action(.onAppear)
                            }
                        default:
                            ErrorCardView.generic(
                                message: "\(errorView)",
                                showTryAgainButton: retryCount < 3
                            ) {
                                retryCount += 1
                                action(.onAppear)
                            }
                        }
                        Spacer(minLength: safeAreaInsets.bottom + 20)
                    }
                    .padding(.horizontal)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                action(.onAppear)
            }
        }
        
        /// "No live race right now" is the normal state (most days), not an
        /// error like an empty "Next to finish"/"Results"/"Tomorrow" section —
        /// so unlike `buildNoResultsCardView`'s siblings below, an empty list
        /// here renders nothing at all rather than an `EmptyResultsCardView`.
        @ViewBuilder
        private func buildLiveStatsView(_ representable: Representable) -> some View {
            if !representable.sections.liveStats.isEmpty {
                VaporSectionPanel(panelColor: .tribuneru(.vaporPanelLive)) {
                    VaporSectionHeader(title: "LiveStats", showsLiveDot: true)
                } content: {
                    ForEach(representable.sections.liveStats) { race in
                        VaporLiveStatsCard(race: race)
                    }
                }
            }
        }

        private func buildTomorrowRaces(_ representable: Representable) -> some View {
            Group {
                if representable.sections.tomorrowRaces.isEmpty {
                    buildNoResultsCardView(
                        "Races tomorrow", info: "No Races", delaySlideInfo: 0,
                        panelColor: .tribuneru(.vaporPanelTomorrow)
                    )
                } else {
                    VaporSectionPanel(panelColor: .tribuneru(.vaporPanelTomorrow)) {
                        VaporSectionHeader(title: "Races tomorrow")
                    } content: {
                        ForEach(representable.sections.tomorrowRaces) { race in
                            VaporTomorrowCard(race: race)
                        }
                    }
                }
            }
        }

        private func buildNextToFinishView(_ representable: Representable) -> some View {
            Group {
                if representable.sections.nextToFinish.isEmpty {
                    buildNoResultsCardView(
                        "Next to fihish", info: "No info yet", delaySlideInfo: 2,
                        panelColor: .tribuneru(.vaporPanelRacing)
                    )
                } else {
                    VaporSectionPanel(panelColor: .tribuneru(.vaporPanelRacing)) {
                        VaporSectionHeader(title: "Next to finish", showsLiveDot: true)
                    } content: {
                        ForEach(Array(representable.sections.nextToFinish.enumerated()), id: \.element.id) { index, race in
                            VaporNextToFinishCard(race: race)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    action(.navigate(.nextToFinishRace(index: index)))
                                }
                        }
                    }
                }
            }
        }

        private func buildResultsTodayView(_ representable: Representable) -> some View {
            Group {
                if representable.sections.racesFinished.isEmpty {
                    buildNoResultsCardView(
                        "Results today", info: "No Info yet", delaySlideInfo: 4,
                        panelColor: .tribuneru(.vaporPanelToday)
                    )
                } else {
                    VaporSectionPanel(
                        panelColor: .tribuneru(.vaporPanelToday),
                        contentHidden: !representable.sections.spoilerMode.isSpoilerModeResultsToday
                    ) {
                        VaporSectionHeader(title: "Results today") {
                            VaporSpoilerChip(
                                isSpoilerModeOn: representable.sections.spoilerMode.isSpoilerModeResultsToday
                            ) {
                                action(.spoilerModeResultToday)
                            }
                        }
                    } content: {
                        ForEach(representable.sections.racesFinished) { race in
                            VaporResultCard(race: race)
                        }
                    }
                }
            }
        }

        @ViewBuilder
        private func buildResultsYesterdayView(_ representable: Representable) -> some View {
            if representable.sections.yesterdayResults.isEmpty {
                buildNoResultsCardView(
                    "Results yesterday", info: "No Races", delaySlideInfo: 6,
                    panelColor: .tribuneru(.vaporPanelYesterday)
                )
            } else {
                VaporSectionPanel(
                    panelColor: .tribuneru(.vaporPanelYesterday),
                    contentHidden: !representable.sections.spoilerMode.isSpoilerModeResultsYesterday
                ) {
                    VaporSectionHeader(title: "Results yesterday") {
                        VaporSpoilerChip(
                            isSpoilerModeOn: representable.sections.spoilerMode.isSpoilerModeResultsYesterday
                        ) {
                            action(.spoilerModeResultYesterday)
                        }
                    }
                } content: {
                    ForEach(representable.sections.yesterdayResults) { race in
                        VaporResultCard(race: race)
                    }
                }
            }
        }

        private func buildNoResultsCardView(_ race: String, info: String, delaySlideInfo: Double, panelColor: Color) -> some View {
            EmptyResultsCardView(title: "\(race)", info: info, delaySlideInfo: delaySlideInfo)
                .frame(height: heightCardView)
                .frame(maxWidth: .infinity)
                .background(panelColor)
                .cornerRadius(20)
        }
    }
}

// MARK: - Previews -

#Preview("Loaded") {
    let nextToFinish: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Home", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: ""),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Strade Bianche Donne", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: ""),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "paris Nice", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: ""),
        HomeRaces.Representable.RaceNext(eta: "14:00", duration: "2H", name: "Tirreno", category: "UCI", raceType: "2.UWT", distance: "215", urlPath: nil, flagCode: "")
    ]
    let todayFinished: [HomeRaces.Representable.RaceFinished] = [
        HomeRaces.Representable.RaceFinished(
            race: "Paris-Nice",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "it", name: "Pipo Ganna", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "be", name: "Pipo Ganna", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "uk", name: "Pipo Ganna", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno",
            raceDetails: "General classification",
            winnerImgURL: nil,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Matthieu", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "ir", name: "Ben Healy", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "nl", name: "Adam Yates", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Paris-Roubaix",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "au", name: "Wout van", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "", name: "Remco enve", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "", name: "Pipo Ganna", team: "Ineos", time: "24:12")
            ],
            isCancel: false
        )
    ]
    let yesterdayResults: [HomeRaces.Representable.RaceFinished] = [
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno Adriatico etapa 2",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "it", name: "Joshua Tarlin", team: "Visma lease a bike", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "be", name: "Pipo Ganna", team: "Soudal Quick step", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "uk", name: "Primoz Roglic", team: "Lidl Trek", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "Tirreno Adriatico",
            raceDetails: "Stage 4",
            winnerImgURL: nil,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "nl", name: "Visma | Lease a bike", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "au", name: "Team Jayco Alula", team: "", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "de", name: "Red Bull - Bora - Hansgrohe", team: "", time: "24:12")
            ],
            isCancel: false
        ),
        HomeRaces.Representable.RaceFinished(
            race: "A traves de Flandes",
            raceDetails: "General classification",
            winnerImgURL: URL(string: "https://www.procyclingstats.com/images/riders/bp/ee/filippo-ganna-2025.jpg")!,
            podium: [
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "be", name: "Victor Campenaerts", team: "Visma | Lease a bike", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "no", name: "Tobias Foss", team: "Ineos", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "fr", name: "Julien Alaphilipe", team: "Tudor", time: "24:12")
            ],
            isCancel: false
        )
    ]
    let tomorrowRaces = [
        HomeRaces.Representable.RaceTomorrow(start: "12:00", eta: "", name: "Bruge-Le Panne", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "12:04", eta: "", name: "Bruge-Le Panne", url: nil),
        HomeRaces.Representable.RaceTomorrow(start: "12:30", eta: "", name: "Bruge-Le Panne", url: nil)
    ]
    let repre = HomeRaces.Representable(
        sections: HomeRaces.Representable.Section(
            title: "",
            spoilerMode: .empty,
            liveStats: [],
            nextToFinish: [], // nextToFinish,
            racesFinished: todayFinished,
            yesterdayResults: yesterdayResults,
            tomorrowRaces: tomorrowRaces
        )
    )
    HomeRaces.MainView(state: .loaded(repre)) { _ in
        
    }
}


#Preview("Loading") {
    HomeRaces.MainView(state: .loading) { _ in  }
}
