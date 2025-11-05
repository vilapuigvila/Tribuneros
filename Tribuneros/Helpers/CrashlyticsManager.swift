//
//  CrashlyticsManager.swift
//  Tribuneros
//
//  Created by albert vila on 5/10/25.
//

import Foundation
import FirebaseCore
import FirebaseCrashlytics

struct CrashlyticsManager {
    
    static let shared = CrashlyticsManager()

    private static var _isConfigured: Bool = false

    private init() {}
    
    func configure() {
        guard !Self._isConfigured else { return }
        Self._isConfigured = true
        FirebaseApp.configure()
    }


    /// Records a non-fatal error to Crashlytics.
    /// - Parameters:
    ///   - error: The non-fatal error wrapper.
    ///   - domain: A domain string to help categorize the error in Crashlytics.
    static func reportNonFatal(error: CrashlyticsNonFatalError, domain: String) {
        report(error, domain: domain)
    }

    /// Records a non-fatal error to Crashlytics.
    /// - Parameters:
    ///   - error: The non-fatal error wrapper.
    ///   - domain: A domain string to help categorize the error in Crashlytics.
    static func report(_ error: CrashlyticsNonFatalError, domain: String) {
        Crashlytics.crashlytics().record(error: error.asNSError(domain: domain))
    }

    /// Convenience helper to record a non-fatal message without manually
    /// constructing a `CrashlyticsNonFatalError`.
    static func recordMessage(_ message: String,
                              domain: String,
                              file: String = #fileID,
                              function: String = #function,
                              line: UInt = #line,
                              code: Int = 0) {
        let error = CrashlyticsNonFatalError(message, file, function, line, code)
        Crashlytics.crashlytics().record(error: error.asNSError(domain: domain))
    }
}

/// Non-fatal error captured by Crashlytics with rich context.
struct CrashlyticsNonFatalError: LocalizedError {
    let message: String
    let file: String
    let function: String
    let line: UInt
    let code: Int

    init(_ message: String, _ file: String, _ function: String, _ line: UInt, _ code: Int = 0) {
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.code = code
    }

    var errorDescription: String? { message }

    var userInfo: [String: Any] {
        [
            CrashlyticsNonFatalError.descriptionKey: message,
            CrashlyticsNonFatalError.fileKey: file,
            CrashlyticsNonFatalError.functionKey: function,
            CrashlyticsNonFatalError.lineKey: Int(line)
        ]
    }

    func asNSError(domain: String) -> NSError {
        NSError(domain: domain, code: code, userInfo: userInfo)
    }
}

extension CrashlyticsNonFatalError {
    // Use standard and clearly-namespaced keys.
    fileprivate static let descriptionKey = NSLocalizedDescriptionKey
    fileprivate static let fileKey = "file"
    fileprivate static let functionKey = "function"
    fileprivate static let lineKey = "line"
}

/// Assert-like helper that reports a non-fatal issue to Crashlytics when `condition` is false.
/// If the environment variable `ASSERT_NON_FATAL_CRASHLYTICS` is present, an assertionFailure
/// will also be triggered (primarily useful during local development/CI).
func nonFatalCrashlytics(_ condition: @autoclosure () -> Bool,
                         _ message: @autoclosure () -> String,
                         domain: CrashlyticsDomain = .tribuneru,
                         file: StaticString = #fileID,
                         function: StaticString = #function,
                         line: UInt = #line,
                         code: UInt? = 0) {
    let passed = condition()
    if passed { return }

    if ProcessInfo.processInfo.environment["ASSERT_NON_FATAL_CRASHLYTICS"] != nil {
        // We already know the condition failed, so call assertionFailure directly.
        assertionFailure(message())
    }

    CrashlyticsManager.reportNonFatal(
        error: CrashlyticsNonFatalError(message(), "\(file)", "\(function)", line, Int(code ?? 0)),
        domain: domain.rawValue
    )
}

/// Namespaces the crash reporting domain for easier categorization in Crashlytics.
enum CrashlyticsDomain: String {
    case tribuneru
}

