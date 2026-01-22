//
//  TribunerosApp.swift
//  Tribuneros
//
//  Created by albert vila on 18/2/25.
//

import SwiftUI
import SwiftData
import Alfy

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
        CachedURLSession.configure(cacheControlBehavior: .ignoreServer)
    }
    
    var body: some Scene {
        WindowGroup {
            TabBarView()
        }
        .modelContainer(sharedModelContainer)
    }
}

extension CrashlyticsDomain {
    static let races = CrashlyticsDomain("races")
    static let cyclocross = CrashlyticsDomain("cyclocross")
}

struct CrashlyticsHelper {
    static func send(
        _ condition: @autoclosure () -> Bool,
        _ message: @autoclosure () -> String,
        domain: CrashlyticsDomain,
    ) {
        nonFatalCrashlytics(condition(), message(), domain: domain)
    }
}
