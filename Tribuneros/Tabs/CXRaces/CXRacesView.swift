//
//  CXRacesView.swift
//  Tribuneros
//
//  Created by albert vila on 5/1/26.
//

import SwiftUI

struct CXRacesRacesView: View {
    @ObservedObject var viewModel: CXRaces.ViewModel<CXRaces.InteractorImpl>
    
    var body: some View {
        CXRaces.MainView(state: viewModel.stateView) {
            switch $0 {
            case .didAppeared:
                guard viewModel.isRequiredRequestData else {
                    return
                }
                viewModel.action(.didAppeared)
            default:
                viewModel.action($0)
            }
        }
        .navigationDestination(for: Router.Destination.self) { destination in
            let _ = print("avvp [Navigation] - \(destination)")
            switch destination {
            case .cxZone(.allRaces):
                CXAllRacesView(events: viewModel.stateView.result.calendarEvents)
                    .navigationTitle("All races")
            default:
                EmptyView()
            }
        }
        .navigationTitle("CX ZONE")
    }
}

private struct CXAllRacesView: View {
    let events: [DTO.CXCalendarEvent]
    
    var body: some View {
        List {
            ForEach(events.indices, id: \.self) { idx in
                let event = events[idx]
                HStack(spacing: 12) {
                    TribuneruText(content: event.date, style: .size12WeightRegular)
                        .frame(width: 84, alignment: .leading)
                    
                    CachedImageView(imageUrl: event.flagURL)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        TribuneruText(content: event.race, style: .size12WeightRegular)
                        TribuneruText(content: event.winnerName, style: .size10WeightRegular, color: .gray)
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.black)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.black)
        .preferredColorScheme(.dark)
    }
}
