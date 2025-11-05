//
//  TribunerosApp.swift
//  Tribuneros
//
//  Created by albert vila on 18/2/25.
//

import SwiftUI
import SwiftData

@main
struct TribunerosApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            nonFatalCrashlytics(false, error.localizedDescription)
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
        CrashlyticsManager.shared.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            TabBarView()
        }
        .modelContainer(sharedModelContainer)
    }
}
