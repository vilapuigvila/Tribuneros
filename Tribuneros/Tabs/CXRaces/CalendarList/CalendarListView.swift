//
//  CalendarListView.swift
//  Tribuneros
//
//  Created by albert vila on 7/1/26.
//

import Foundation
import SwiftUI
    
struct CXAllRacesView: View {
    private enum UI {
        static let rowHeight: CGFloat = 84
        static let autoScrollDelay: TimeInterval = 0.5
        static let showButtonDelay: TimeInterval = 0.5
    }
    
    let events: [DTO.CXCalendarEvent]
    let action: (DTO.CXCalendarEvent) -> Void
    /// `nil` shows every race.
    @State private var selectedSeries: CXRaces.RaceSeries?
    @State private var searchText = ""
    @State private var didAutoScrollToToday = false
    @State private var showTodayButton = false
    @State private var isScrolling = false
    @State private var scrollTimer: Timer?
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    seriesFilterBar
                    List {
                        ForEach(filteredEvents.indices, id: \.self) { idx in
                            let event = filteredEvents[idx]
                            Button {
                                action(event)
                            } label: {
                                HStack(spacing: 12) {
                                    TribuneruText(
                                        content: event.date,
                                        style: .vaporMeta,
                                        color: .tribuneru(.vaporTextSecondary)
                                    )
                                    .frame(width: 84, alignment: .leading)

                                    VaporFlagView(url: event.flagURL)

                                    VStack(alignment: .leading, spacing: 2) {
                                        TribuneruText(
                                            content: event.race,
                                            style: .vaporRaceNameNext,
                                            color: .tribuneru(.vaporTextPrimary),
                                            lineLimit: 2
                                        )
                                        if event.isCancelled {
                                            TribuneruText(
                                                content: L10n.tr("Cancelled"),
                                                style: .vaporMeta,
                                                color: .tribuneru(.vaporNegative)
                                            )
                                        } else if !event.winnerName.isEmpty {
                                            TribuneruText(
                                                content: event.winnerName,
                                                style: .vaporMeta,
                                                color: .tribuneru(.vaporTextSecondary)
                                            )
                                        }
                                    }

                                    Spacer(minLength: 0)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.tribuneru(.vaporTextSecondary))
                                }
                                .frame(height: UI.rowHeight)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(idx)
                            .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(Color.tribuneru(.vaporCardSurface))
                        }
                    }
                    .onAppear {
                        guard !didAutoScrollToToday else { return }
                        scrollToToday(proxy)
                    }
                    .onChange(of: events) {
                        guard !didAutoScrollToToday else { return }
                        scrollToToday(proxy)
                    }
                    .onChange(of: selectedSeries) {
                        scrollToToday(proxy)
                    }
                    .overlay {
                        if filteredEvents.isEmpty && !events.isEmpty {
                            TribuneruText(
                                content: searchText.isEmpty
                                    ? L10n.tr("No races in this series.")
                                    : L10n.tr("No races match “%@”.", searchText),
                                style: .vaporMeta,
                                color: .tribuneru(.vaporTextSecondary),
                                lineLimit: 2
                            )
                            .padding(24)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.tribuneru(.vaporPageBackground))
                    .environment(\.defaultMinListRowHeight, UI.rowHeight)
                    .preferredColorScheme(.dark)
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { _ in
                                isScrolling = true
                                showTodayButton = false
                                scrollTimer?.invalidate()
                            }
                            .onEnded { _ in
                                startShowButtonTimer()
                            }
                    )
                }
                .background(Color.tribuneru(.vaporPageBackground))
                
                if showTodayButton {
                    Button(action: { scrollToToday(proxy) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.circle.fill")
                                .foregroundStyle(Color.tribuneru(.vaporPageBackground))
                            TribuneruText(
                                content: L10n.tr("Today Races"),
                                style: .vaporRaceNameNext,
                                color: .tribuneru(.vaporPageBackground)
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.tribuneru(.vaporAccent))
                        .cornerRadius(8)
                    }
                    .clipShape(Capsule())
                    .padding(16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.tr("Race, country, winner...")
        )
    }
    
    /// Events matching the search text, before the series filter.
    private var searchedEvents: [DTO.CXCalendarEvent] {
        events.filter { CXRaces.calendarEvent($0, matches: searchText) }
    }

    private var filteredEvents: [DTO.CXCalendarEvent] {
        guard let selectedSeries else { return searchedEvents }
        return searchedEvents.filter { $0.series == selectedSeries }
    }

    /// Chips are those of the whole season, so they don't jump around while typing; their
    /// counts follow the search.
    private var seasonSeries: [CXRaces.RaceSeries] {
        let present = Set(events.map(\.series))
        return CXRaces.RaceSeries.allCases.filter { present.contains($0) }
    }

    private var seriesCounts: [CXRaces.RaceSeries: Int] {
        Dictionary(grouping: searchedEvents, by: \.series).mapValues(\.count)
    }

    private var seriesFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                CXSeriesFilterChip(
                    title: L10n.tr("All"),
                    count: searchedEvents.count,
                    isSelected: selectedSeries == nil
                ) {
                    selectedSeries = nil
                }
                // Only the series present in this season's calendar get a chip.
                let counts = seriesCounts
                ForEach(seasonSeries) { series in
                    CXSeriesFilterChip(
                        title: series.title,
                        count: counts[series] ?? 0,
                        isSelected: selectedSeries == series
                    ) {
                        selectedSeries = selectedSeries == series ? nil : series
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var todayIndex: Int? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        if let todayIdx = filteredEvents.firstIndex(where: { event in
            guard let date = event.eventDate else { return false }
            return calendar.isDateInToday(date)
        }) {
            return todayIdx
        }
        
        return filteredEvents.firstIndex { event in
            guard let date = event.eventDate else { return false }
            return date >= startOfToday
        }
    }
    
    private func scrollToToday(_ proxy: ScrollViewProxy) {
        guard let idx = todayIndex else { return }
        
        didAutoScrollToToday = true
        DispatchQueue.main.asyncAfter(deadline: .now() + UI.autoScrollDelay) {
            var transaction = Transaction()
            transaction.animation = .easeInOut(duration: 0.45)
            withTransaction(transaction) {
                proxy.scrollTo(idx, anchor: .top)
            }
        }
    }
    
    private func startShowButtonTimer() {
        scrollTimer?.invalidate()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: UI.showButtonDelay, repeats: false) { _ in
            withAnimation {
                isScrolling = false
                showTodayButton = todayIndex != nil
            }
        }
    }
}

private struct CXSeriesFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                TribuneruText(
                    content: title.uppercased(with: L10n.locale),
                    style: .vaporSpoilerChip,
                    color: isSelected ? .tribuneru(.vaporPageBackground) : .tribuneru(.vaporTextPrimary),
                    lineLimit: 1
                )
                TribuneruText(
                    content: "\(count)",
                    style: .vaporMonoMeta,
                    color: isSelected ? .tribuneru(.vaporPageBackground) : .tribuneru(.vaporTextSecondary),
                    lineLimit: 1
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                ? Color.tribuneru(.vaporAccent)
                : Color.tribuneru(.vaporCardSurface)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG

extension Array where Element == DTO.CXCalendarEvent {
    static var mockCXRacesAllRaces: [DTO.CXCalendarEvent] {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        
        let today = Date()
        let calendar = Calendar.current
        
        func dateString(_ date: Date) -> String {
            formatter.string(from: date)
        }
        
        return [
            .init(
                date: dateString(calendar.date(byAdding: .day, value: -3, to: today) ?? today),
                race: "Superprestige Ruddervoorde",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                winnerName: "VANTHOURENHOUT Michael",
                isCancelled: false,
                raceID: 17552,
                raceSlug: "ruddervoorde",
                raceURL: URL(string: "https://cyclocross24.com/race/ruddervoorde/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17552/"),
                videoURL: URL(string: "https://cyclocross24.com/race/17552/#video"),
                websiteURL: URL(string: "https://www.superprestigecyclocross.be"),
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: -3, to: today) ?? today),
                race: "Superprestige Ruddervoorde",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                winnerName: "VANTHOURENHOUT Michael",
                isCancelled: false,
                raceID: 17552,
                raceSlug: "ruddervoorde",
                raceURL: URL(string: "https://cyclocross24.com/race/ruddervoorde/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17552/"),
                videoURL: URL(string: "https://cyclocross24.com/race/17552/#video"),
                websiteURL: URL(string: "https://www.superprestigecyclocross.be"),
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: -3, to: today) ?? today),
                race: "Superprestige Ruddervoorde",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                winnerName: "VANTHOURENHOUT Michael",
                isCancelled: false,
                raceID: 17552,
                raceSlug: "ruddervoorde",
                raceURL: URL(string: "https://cyclocross24.com/race/ruddervoorde/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17552/"),
                videoURL: URL(string: "https://cyclocross24.com/race/17552/#video"),
                websiteURL: URL(string: "https://www.superprestigecyclocross.be"),
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: -3, to: today) ?? today),
                race: "Superprestige Ruddervoorde",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                winnerName: "VANTHOURENHOUT Michael",
                isCancelled: false,
                raceID: 17552,
                raceSlug: "ruddervoorde",
                raceURL: URL(string: "https://cyclocross24.com/race/ruddervoorde/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17552/"),
                videoURL: URL(string: "https://cyclocross24.com/race/17552/#video"),
                websiteURL: URL(string: "https://www.superprestigecyclocross.be"),
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: -3, to: today) ?? today),
                race: "Superprestige Ruddervoorde",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                winnerName: "VANTHOURENHOUT Michael",
                isCancelled: false,
                raceID: 17552,
                raceSlug: "ruddervoorde",
                raceURL: URL(string: "https://cyclocross24.com/race/ruddervoorde/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17552/"),
                videoURL: URL(string: "https://cyclocross24.com/race/17552/#video"),
                websiteURL: URL(string: "https://www.superprestigecyclocross.be"),
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: -3, to: today) ?? today),
                race: "Superprestige Ruddervoorde",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                winnerName: "VANTHOURENHOUT Michael",
                isCancelled: false,
                raceID: 17552,
                raceSlug: "ruddervoorde",
                raceURL: URL(string: "https://cyclocross24.com/race/ruddervoorde/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17552/"),
                videoURL: URL(string: "https://cyclocross24.com/race/17552/#video"),
                websiteURL: URL(string: "https://www.superprestigecyclocross.be"),
                raceCountry: "Belgium",
                winnerURL: URL(string: "https://cyclocross24.com/rider/michael-vanthourenhout/"),
                winnerCountry: "Belgium",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png")
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: -1, to: today) ?? today),
                race: "Swiss Cyclocross Cup #2 - Schneisingen",
                raceClass: "C2",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Switzerland.png"),
                winnerName: "DEBORD Romain",
                isCancelled: false,
                raceID: 17556,
                raceSlug: "schneisingen",
                raceURL: URL(string: "https://cyclocross24.com/race/schneisingen/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17556/"),
                videoURL: URL(string: "https://cyclocross24.com/race/17556/#video"),
                websiteURL: URL(string: "https://swiss-cyclocross.ch/swiss-cyclocross-cup/"),
                raceCountry: "Switzerland",
                winnerURL: URL(string: "https://cyclocross24.com/rider/romain-debord/"),
                winnerCountry: "France",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/France.png")
            ),
            .init(
                date: dateString(today),
                race: "UCI World Cup Antwerpen",
                raceClass: "CDM",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Belgium.png"),
                winnerName: "",
                isCancelled: false,
                raceID: 17920,
                raceSlug: "antwerpen",
                raceURL: URL(string: "https://cyclocross24.com/race/antwerpen/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17920/"),
                videoURL: nil,
                websiteURL: URL(string: "https://www.ucicyclocrossworldcup.com"),
                raceCountry: "Belgium",
                winnerURL: nil,
                winnerCountry: nil,
                winnerFlagURL: nil
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: 1, to: today) ?? today),
                race: "Trek USCX #3 - Rochester Cyclocross",
                raceClass: "C1",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/United%20States.png"),
                winnerName: "BRUNNER Eric",
                isCancelled: false,
                raceID: 17416,
                raceSlug: "rochester-cyclocross",
                raceURL: URL(string: "https://cyclocross24.com/race/rochester-cyclocross/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17416/"),
                videoURL: nil,
                websiteURL: URL(string: "https://rochestercyclocross.com"),
                raceCountry: "United States",
                winnerURL: URL(string: "https://cyclocross24.com/rider/eric-brunner/"),
                winnerCountry: "United States",
                winnerFlagURL: URL(string: "https://cyclocross24.com/images/flag/32/United%20States.png")
            ),
            .init(
                date: dateString(calendar.date(byAdding: .day, value: 7, to: today) ?? today),
                race: "Cross4Life Copenhagen",
                raceClass: "C2",
                flagURL: URL(string: "https://cyclocross24.com/images/flag/32/Denmark.png"),
                winnerName: "",
                isCancelled: true,
                raceID: 17614,
                raceSlug: "cross4life-copenhagen",
                raceURL: URL(string: "https://cyclocross24.com/race/cross4life-copenhagen/"),
                resultsURL: URL(string: "https://cyclocross24.com/race/17614/"),
                videoURL: nil,
                websiteURL: URL(string: "https://crossforlife.dk"),
                raceCountry: "Denmark",
                winnerURL: nil,
                winnerCountry: nil,
                winnerFlagURL: nil
            )
        ]
    }
}

#Preview("CX All Races") {
    NavigationStack {
        CXAllRacesView(events: .mockCXRacesAllRaces) { _ in }
            .navigationTitle("All races")
    }
}

#endif
