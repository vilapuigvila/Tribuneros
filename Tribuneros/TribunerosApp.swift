//
//  TribunerosApp.swift
//  Tribuneros
//
//  Created by albert vila on 18/2/25.
//

import SwiftUI
import SwiftData

import FirebaseCore
import FirebaseCrashlytics

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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    init() {
      FirebaseApp.configure()
//        let randomWords = ["alf", "vila", "123", "456", "hola", "mundo", "adios"]
        nonFatalCrashlytics(false, "alffffffff", domain: .tribuneru)
//        fatalError(["alf", "vila", "123", "456"].randomElement() ?? "not random")
    }
    
    var body: some Scene {
        WindowGroup {
            TabBarView()
        }
        .modelContainer(sharedModelContainer)
    }
}

struct CrashlyticsManager {
    static func reportNonFatal(error: CrashlyticsNonFatalError, domain: String) {
        report(error, domain: domain)
    }

    static func report(_ error: CrashlyticsNonFatalError, domain: String) {
        Crashlytics.crashlytics().record(error: error.asNSError(domain: domain))
    }
}

enum CrashlyticsNonFatalError: Error {
    case generic(_ message: String, _ file: String, _ line: UInt, _ code: UInt)

    var userInfo: [String: Any] {
        switch self {
        case .generic(let message, let file, let line, _):
            return [CrashlyticsNonFatalError.LocalizedDescription: message,
                    CrashlyticsNonFatalError.LocalizedFile: file,
                    CrashlyticsNonFatalError.LocalizedLine: Int(line)]
        }
    }
    var code: UInt {
        switch self {
        case .generic(_, _, _, let code): return code
        }
    }

    func asNSError(domain: String) -> NSError {
        return NSError(domain: domain, code: 0, userInfo: userInfo)
    }
}

extension CrashlyticsNonFatalError {
    private static let LocalizedDescription = "description"
    private static let LocalizedFile = "file"
    private static let LocalizedLine = "line"
}

func nonFatalCrashlytics(_ condition: @autoclosure () -> Bool,
                       _ message: @autoclosure () -> String,
                       domain: CrashlyticsDomain = .tribuneru,
                       file: StaticString = #file,
                       line: UInt = #line,
                       code: UInt? = UInt(0)
) {
    #if DEBUG
    guard !condition() else {
        return
    }
//    assert(condition(), message())
    guard !condition() else {
        return
    }
    CrashlyticsManager.reportNonFatal(
        error: .generic(message(),
        "\(file)",
        line, code ?? UInt(0)),
        domain: domain.rawValue
    )
    #endif
}
enum CrashlyticsDomain: String {
    case tribuneru
}
