//
//  TabBarView.swift
//  Tribuneros
//
//  Created by albert vila on 19/2/25.
//

import SwiftUI

struct TabBarView: View {
    
    init() {
    }
    
    var body: some View {
        TabView {
            HomeRacesView(
                viewModel: HomeRacesViewModel(interactor: HomeRacesInteractorImpl())
            )
            .tabItem {
                Image(systemName: "figure.indoor.cycle")
                Text("Today Races")
            }
            /*
            StationsListView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Stations")
                }*/
        }
        .onAppear {
            print(#function)
        }
    }
}
/*
#Preview {
    TabBarView()
}*/

