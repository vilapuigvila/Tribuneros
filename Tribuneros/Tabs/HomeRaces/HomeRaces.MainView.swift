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
        @State private var resultsSelection: ResultsSelection = .today
        
        let state: HomeRaces.ViewState
        let action: (HomeRaces.Action) -> Void
        
        var body: some View {
            Group {
                switch state {
                case .idle:
                    VStack(spacing: 12) {
                        TribuneruText(
                            content: "Races",
                            style: .size20WeightBold
                        )
                        TribuneruText(
                            content: "Pulling latest data…",
                            style: .size14WeightRegular,
                            color: .white.opacity(0.7)
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tribuneru(.black))
                case .loading:
                    VStack {
                        LoaderView(
                            title: "Loading races…",
                            subtitle: "Fetching latest data"
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tribuneru(.black))
                case .loaded(let representable):
                    ScrollView {
                        VStack(spacing: 16) {
                            dashboardSummary(representable)
                            nextToFinishCarousel(representable)
                            resultsSection(representable)
                            tomorrowTimeline(representable)
                            Color.clear
                                .frame(height: safeAreaInsets.bottom + 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                    .background(Color.tribuneru(.black))
                    
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
        
        // MARK: - Dashboard sections

        private func dashboardSummary(_ representable: Representable) -> some View {
            DashboardCard {
                VStack(alignment: .leading, spacing: 12) {
                    TribuneruText(
                        content: "Today",
                        style: .size14WeightSemiBold,
                        color: .white.opacity(0.8)
                    )
                    HStack(spacing: 10) {
                        summaryPill(
                            symbol: "flag.checkered",
                            title: "Next",
                            value: "\(representable.sections.nextToFinish.count)"
                        )
                        summaryPill(
                            symbol: "list.bullet.rectangle",
                            title: "Finished",
                            value: "\(representable.sections.racesFinished.count)"
                        )
                        summaryPill(
                            symbol: "calendar",
                            title: "Tomorrow",
                            value: "\(representable.sections.tomorrowRaces.count)"
                        )
                    }
                }
            }
        }

        private func summaryPill(symbol: String, title: String, value: String) -> some View {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(Color.tribuneru(.green(brightness: 0.85, saturation: 0.8)))
                VStack(alignment: .leading, spacing: 1) {
                    TribuneruText(
                        content: title,
                        style: .size10WeightRegular,
                        color: .white.opacity(0.65)
                    )
                    TribuneruText(
                        content: value,
                        style: .size16WeightBold
                    )
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tribuneru(.white(level: 0.08)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.tribuneru(.white(level: 0.14)), lineWidth: 1)
            )
            .cornerRadius(12)
        }

        private func nextToFinishCarousel(_ representable: Representable) -> some View {
            DashboardCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        title: "Next to finish",
                        subtitle: representable.sections.nextToFinish.isEmpty ? "No live races" : "Tap a race for details"
                    )
                    if representable.sections.nextToFinish.isEmpty {
                        emptyState(
                            title: "No live races",
                            subtitle: "Check back later"
                        )
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(representable.sections.nextToFinish.enumerated()), id: \.element.id) { index, race in
                                    Button {
                                        action(.navigate(.nextToFinishRace(index: index)))
                                    } label: {
                                        NextToFinishRaceCard(race: race)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                }
            }
        }

        private func resultsSection(_ representable: Representable) -> some View {
            let today = representable.sections.racesFinished
            let yesterday = representable.sections.yesterdayResults

            return DashboardCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        sectionHeader(
                            title: "Results",
                            subtitle: resultsSelection == .today ? "Today" : "Yesterday"
                        )
                        Spacer(minLength: 0)
                        spoilerToggle(
                            isOn: spoilersEnabled(representable)
                        )
                    }
                    resultsPicker

                    let races = resultsSelection == .today ? today : yesterday
                    if races.isEmpty {
                        emptyState(
                            title: "No results yet",
                            subtitle: "Races still in progress"
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(races.prefix(3))) { race in
                                RaceResultCard(
                                    race: race,
                                    spoilersEnabled: spoilersEnabled(representable)
                                )
                            }
                        }
                    }
                }
            }
        }

        private var resultsPicker: some View {
            HStack(spacing: 8) {
                pickerButton(title: "Today", selection: .today)
                pickerButton(title: "Yesterday", selection: .yesterday)
                Spacer(minLength: 0)
            }
        }

        private func pickerButton(title: String, selection: ResultsSelection) -> some View {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    resultsSelection = selection
                }
            } label: {
                TribuneruText(
                    content: title,
                    style: .size12WeightRegular,
                    color: resultsSelection == selection ? .black : .white.opacity(0.85)
                )
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            resultsSelection == selection
                                ? Color.tribuneru(.green(brightness: 0.9, saturation: 0.8))
                                : Color.tribuneru(.white(level: 0.10))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.tribuneru(.white(level: 0.16)), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }

        private func spoilersEnabled(_ representable: Representable) -> Bool {
            switch resultsSelection {
            case .today:
                representable.sections.spoilerMode.isSpoilerModeResultsToday
            case .yesterday:
                representable.sections.spoilerMode.isSpoilerModeResultsYesterday
            }
        }

        private func spoilerToggle(isOn: Bool) -> some View {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                switch resultsSelection {
                case .today:
                    action(.spoilerModeResultToday)
                case .yesterday:
                    action(.spoilerModeResultYesterday)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isOn ? "eye" : "eye.slash")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                    TribuneruText(
                        content: isOn ? "Spoilers on" : "Spoilers off",
                        style: .size10WeightRegular,
                        color: isOn ? .black : .white.opacity(0.85)
                    )
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isOn
                                ? Color.tribuneru(.green(brightness: 0.9, saturation: 0.8))
                                : Color.tribuneru(.white(level: 0.10))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.tribuneru(.white(level: 0.16)), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }

        private func tomorrowTimeline(_ representable: Representable) -> some View {
            DashboardCard {
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(
                        title: "Tomorrow",
                        subtitle: representable.sections.tomorrowRaces.isEmpty ? "No races scheduled" : "Schedule"
                    )
                    if representable.sections.tomorrowRaces.isEmpty {
                        emptyState(
                            title: "Nothing tomorrow",
                            subtitle: "Enjoy the rest day"
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(representable.sections.tomorrowRaces.prefix(5).enumerated()), id: \.element.id) { index, race in
                                TomorrowTimelineRow(
                                    race: race,
                                    showsConnector: index < min(representable.sections.tomorrowRaces.count, 5) - 1
                                )
                            }
                        }
                    }
                }
            }
        }

        private func sectionHeader(title: String, subtitle: String) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                TribuneruText(
                    content: title,
                    style: .size16WeightBold
                )
                TribuneruText(
                    content: subtitle,
                    style: .size12WeightRegular,
                    color: .white.opacity(0.7)
                )
            }
        }

        private func emptyState(title: String, subtitle: String) -> some View {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.tribuneru(.white(level: 0.7)))
                VStack(alignment: .leading, spacing: 2) {
                    TribuneruText(
                        content: title,
                        style: .size14WeightSemiBold
                    )
                    TribuneruText(
                        content: subtitle,
                        style: .size12WeightRegular,
                        color: .white.opacity(0.7)
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.tribuneru(.white(level: 0.07)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.tribuneru(.white(level: 0.12)), lineWidth: 1)
            )
            .cornerRadius(12)
        }

        private enum ResultsSelection: String, CaseIterable {
            case today
            case yesterday
        }
    }
}

// MARK: - Dashboard components

private struct DashboardCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tribuneru(.white(level: 0.06)))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.tribuneru(.white(level: 0.12)), lineWidth: 1)
            )
            .cornerRadius(16)
    }
}

private struct NextToFinishRaceCard: View {
    let race: HomeRaces.Representable.RaceNext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Group {
                    if let url = flagURL(race.flagCode) {
                        CachedImageView(imageUrl: url, cornerRadius: 100)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.tribuneru(.white(level: 0.12)))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundStyle(Color.tribuneru(.white(level: 0.7)))
                            )
                    }
                }

                TribuneruText(
                    content: race.name,
                    style: .size14WeightSemiBold,
                    lineLimit: 2
                )

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Chip(text: "ETA \(race.eta)")
                    Chip(text: "\(race.distance) km")
                }
                HStack(spacing: 6) {
                    Chip(text: race.category)
                    Chip(text: race.raceType)
                    Chip(text: race.duration)
                }
            }
        }
        .padding(12)
        .frame(width: 270, alignment: .leading)
        .background(Color.tribuneru(.white(level: 0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.tribuneru(.white(level: 0.12)), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private func flagURL(_ code: String) -> URL? {
        guard !code.isEmpty else { return nil }
        return URL(string: "https://flagcdn.com/w40/\(code).png")
    }

    private struct Chip: View {
        let text: String

        var body: some View {
            TribuneruText(
                content: text,
                style: .size10WeightRegular,
                color: .white.opacity(0.85)
            )
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.tribuneru(.white(level: 0.10)))
            .cornerRadius(8)
        }
    }
}

private struct RaceResultCard: View {
    let race: HomeRaces.Representable.RaceFinished
    let spoilersEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if spoilersEnabled {
                        CachedImageView(imageUrl: race.winnerImgURL, cornerRadius: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.tribuneru(.white(level: 0.12)))
                            .overlay(
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                                    .foregroundStyle(Color.tribuneru(.white(level: 0.7)))
                            )
                    }
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    TribuneruText(
                        content: race.race,
                        style: .size14WeightSemiBold,
                        lineLimit: 2
                    )
                    TribuneruText(
                        content: race.raceDetails,
                        style: .size12WeightRegular,
                        color: .white.opacity(0.7),
                        lineLimit: 2
                    )
                }

                Spacer(minLength: 0)
            }

            VStack(spacing: 6) {
                ForEach(Array(race.podium.prefix(3).enumerated()), id: \.element.id) { index, winner in
                    PodiumRow(
                        position: "\(index + 1)",
                        countryCode: winner.countryCode,
                        name: winner.name,
                        time: winner.time,
                        spoilersEnabled: spoilersEnabled
                    )
                }
            }
        }
        .padding(12)
        .background(Color.tribuneru(.white(level: 0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.tribuneru(.white(level: 0.12)), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    private struct PodiumRow: View {
        let position: String
        let countryCode: String
        let name: String
        let time: String
        let spoilersEnabled: Bool

        var body: some View {
            HStack(spacing: 8) {
                TribuneruText(
                    content: position,
                    style: .size14WeightSemiBold,
                    color: .white.opacity(0.85)
                )
                if spoilersEnabled, let url = flagURL(countryCode) {
                    CachedImageView(imageUrl: url, cornerRadius: 2)
                        .frame(width: 18, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }

                if spoilersEnabled {
                    TribuneruText(
                        content: name,
                        style: .size14WeightRegular,
                        color: .white.opacity(0.9)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    TribuneruText(
                        content: time,
                        style: .size12WeightRegular,
                        color: .white.opacity(0.7)
                    )
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.tribuneru(.white(level: 0.12)))
                        .frame(height: 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TribuneruText(
                        content: "hidden",
                        style: .size12WeightRegular,
                        color: .white.opacity(0.55)
                    )
                }
            }
            .padding(.vertical, 10)
        }

        private func flagURL(_ code: String) -> URL? {
            guard !code.isEmpty else { return nil }
            return URL(string: "https://flagcdn.com/w40/\(code).png")
        }
    }
}

private struct TomorrowTimelineRow: View {
    let race: HomeRaces.Representable.RaceTomorrow
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.tribuneru(.green(brightness: 0.85, saturation: 0.8)))
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
                if showsConnector {
                    Rectangle()
                        .fill(Color.tribuneru(.white(level: 0.18)))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 10) {
                    TribuneruText(
                        content: race.start,
                        style: .size14LightMonospaced,
                        color: .white.opacity(0.9)
                    )
                    TribuneruText(
                        content: race.name,
                        style: .size14WeightSemiBold,
                        lineLimit: 2
                    )
                    Spacer(minLength: 0)
                }
                if !race.eta.isEmpty {
                    TribuneruText(
                        content: "ETA \(race.eta)",
                        style: .size10WeightRegular,
                        color: Color.tribuneru(.green(brightness: 0.85, saturation: 0.8))
                    )
                }
            }
        }
        .padding(10)
        .background(Color.tribuneru(.white(level: 0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.tribuneru(.white(level: 0.12)), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Previews -

#Preview("Loaded") {
    let nextToFinish: [HomeRaces.Representable.RaceNext] = [
        HomeRaces.Representable.RaceNext(
            eta: "14:00",
            duration: "2H",
            name: "Strade Bianche",
            category: "UCI",
            raceType: "2.UWT",
            distance: "215",
            urlPath: nil,
            flagCode: "it"
        ),
        HomeRaces.Representable.RaceNext(
            eta: "14:15",
            duration: "1:45H",
            name: "Strade Bianche Donne",
            category: "UCI",
            raceType: "2.WWT",
            distance: "136",
            urlPath: nil,
            flagCode: "it"
        ),
        HomeRaces.Representable.RaceNext(
            eta: "16:30",
            duration: "4H",
            name: "Paris-Nice",
            category: "UCI",
            raceType: "2.UWT",
            distance: "187",
            urlPath: nil,
            flagCode: "fr"
        ),
        HomeRaces.Representable.RaceNext(
            eta: "17:05",
            duration: "3:50H",
            name: "Tirreno-Adriatico",
            category: "UCI",
            raceType: "2.UWT",
            distance: "203",
            urlPath: nil,
            flagCode: "it"
        )
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
                HomeRaces.Representable.RaceFinished.Winner(position: "1", flag: nil, countryCode: "be", name: "Wout van Aert", team: "Visma | Lease a Bike", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "2", flag: nil, countryCode: "be", name: "Remco Evenepoel", team: "Soudal Quick-Step", time: "24:12"),
                HomeRaces.Representable.RaceFinished.Winner(position: "3", flag: nil, countryCode: "it", name: "Filippo Ganna", team: "Ineos Grenadiers", time: "24:12")
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
        HomeRaces.Representable.RaceTomorrow(
            start: "11:10",
            eta: "15:45",
            name: "Brugge-De Panne",
            url: nil
        ),
        HomeRaces.Representable.RaceTomorrow(
            start: "12:10",
            eta: "16:45",
            name: "Milano-Torino",
            url: nil
        ),
        HomeRaces.Representable.RaceTomorrow(
            start: "13:10",
            eta: "17:05",
            name: "Nokere Koerse",
            url: nil
        )
    ]
    let repre = HomeRaces.Representable(
        sections: HomeRaces.Representable.Section(
            title: "",
            spoilerMode: .init(
                isSpoilerModeResultsToday: true,
                isSpoilerModeResultsYesterday: true
            ),
            nextToFinish: nextToFinish,
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
