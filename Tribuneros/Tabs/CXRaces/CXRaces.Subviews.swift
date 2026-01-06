//
//  CXRaces.Subviews.swift
//  Tribuneros
//
//  Created by albert vila on 6/1/26.
//

import Foundation
import SwiftUI

extension CXRaces {
    
    struct CXAllRacesView: View {
        let events: [DTO.CXCalendarEvent]
        
        var body: some View {
            ScrollViewReader { proxy in
                List {
                    ForEach(events.indices, id: \.self) { idx in
                        let event = events[idx]
                        HStack(spacing: 12) {
                            TribuneruText(content: event.date, style: .size12WeightRegular)
                                .frame(width: 84, alignment: .leading)
                            
                            CachedImageView(imageUrl: event.flagURL)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                TribuneruText(
                                    content: event.race,
                                    style: .size12WeightRegular
                                )
                                if !event.winnerName.isEmpty {
                                    TribuneruText(
                                        content: event.winnerName,
                                        style: .size10WeightRegular,
                                        color: .gray
                                    )
                                }
                            }
                        }
                        .id(idx)
                        .padding(.vertical, 6)
                        .listRowBackground(Color.gray.opacity(0.1))
                    }
                }
                .onAppear {
                    scrollToToday(proxy)
                }
                .onChange(of: events) {
                    scrollToToday(proxy)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(.black)
                .preferredColorScheme(.dark)
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                proxy.scrollTo(idx, anchor: .top)
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
            .init(date: dateString(calendar.date(byAdding: .day, value: -3, to: today) ?? today), race: "CX Event (Past)", raceClass: "C1", flagURL: nil, winnerName: "Winner A"),
            .init(date: dateString(calendar.date(byAdding: .day, value: -1, to: today) ?? today), race: "CX Event (Yesterday)", raceClass: "C1", flagURL: nil, winnerName: "Winner B"),
            .init(date: dateString(today), race: "CX Event (Today)", raceClass: "C1", flagURL: nil, winnerName: "Winner C"),
            .init(date: dateString(calendar.date(byAdding: .day, value: 1, to: today) ?? today), race: "CX Event (Tomorrow)", raceClass: "C1", flagURL: nil, winnerName: "Winner D"),
            .init(date: dateString(calendar.date(byAdding: .day, value: 7, to: today) ?? today), race: "CX Event (Next Week)", raceClass: "C1", flagURL: nil, winnerName: "")
        ]
    }
}

#Preview("CX All Races") {
    NavigationStack {
        CXRaces.CXAllRacesView(events: .mockCXRacesAllRaces)
            .navigationTitle("All races")
    }
}

#endif

