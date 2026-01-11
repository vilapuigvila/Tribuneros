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
    let action: (URL?) -> Void
    @State private var didAutoScrollToToday = false
    @State private var showTodayButton = false
    @State private var isScrolling = false
    @State private var scrollTimer: Timer?
    
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                List {
                    ForEach(events.indices, id: \.self) { idx in
                        let event = events[idx]
                        Button {
                            action(event.raceURL ?? event.resultsURL ?? event.websiteURL)
                        } label: {
                            HStack(spacing: 12) {
                                TribuneruText(content: event.date, style: .size14WeightRegular)
                                    .frame(width: 84, alignment: .leading)
                                
                                CachedImageView(
                                    imageUrl: event.flagURL,
                                    cornerRadius: 1
                                )
                                .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    TribuneruText(
                                        content: event.race,
                                        style: .size14WeightRegular
                                    )
                                    if event.isCancelled {
                                        TribuneruText(
                                            content: "Cancelled",
                                            style: .size12WeightRegular,
                                            color: .red
                                        )
                                    } else if !event.winnerName.isEmpty {
                                        TribuneruText(
                                            content: event.winnerName,
                                            style: .size12WeightRegular,
                                            color: .gray
                                        )
                                    }
                                }
                            }
                            .frame(height: UI.rowHeight)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .id(idx)
                        .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.gray.opacity(0.1))
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(.black)
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
                
                if showTodayButton {
                    Button(action: { scrollToToday(proxy) }) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.circle.fill")
                            TribuneruText(
                                content: "Today Races",
                                style: .size14WeightRegular
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(Color.tribuneru(.greenCardBackground))
                        .cornerRadius(8)
                        .background(Color.tribuneru(.black).opacity(0.95))
                        .cornerRadius(8)
                    }
                    .padding(16)
                    .padding(.bottom, 16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }
    
    private var todayIndex: Int? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        if let todayIdx = events.firstIndex(where: { event in
            guard let date = event.eventDate else { return false }
            return calendar.isDateInToday(date)
        }) {
            return todayIdx
        }
        
        return events.firstIndex { event in
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
