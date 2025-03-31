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
            NavigationView {
                HomeRacesView(
                    viewModel: HomeRacesViewModel(interactor: HomeRacesInteractorImpl())
                )
                .navigationTitle("PRO CYCLING STATS")
            }
            .tabItem {
                Image(systemName: "figure.indoor.cycle")
                Text("Today Races")
            }
            HateZoneView(url: URL(string: "http://ciclismo2005.com")!)
                .tabItem {
                    Image(systemName: "wrongwaysign.fill")
                    Text("Hate Zone")
                }
        }
        .onAppear {
            print(#function)
        }
    }
}

#Preview {
    TabBarView()
}

