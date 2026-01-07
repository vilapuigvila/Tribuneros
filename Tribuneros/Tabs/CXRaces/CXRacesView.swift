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
