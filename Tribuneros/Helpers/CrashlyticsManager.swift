//
//  CrashlyticsManager.swift
//  Tribuneros
//
//  Created by albert vila on 5/10/25.
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

public protocol CrashlyticsBackend {
    func log(_ message: String)
    func record(error: NSError)
    func setUserID(_ userID: String)
    func setCustomValue(_ value: Any?, forKey key: String)
    func setCrashlyticsCollectionEnabled(_ enabled: Bool)
}

public final class CrashlyticsManager {
    public struct Configuration {
        public var isEnabled: Bool
        public var defaultDomain: CrashlyticsDomain
        public var assertionEnvironmentVariable: String
        public var crashlyticsCollectionEnabled: Bool?
        public var configureSDKIfNeeded: () -> Void
        public var backend: CrashlyticsBackend

        public init(
            isEnabled: Bool = true,
            defaultDomain: CrashlyticsDomain = .default,
            assertionEnvironmentVariable: String = "ASSERT_NON_FATAL_CRASHLYTICS",
            crashlyticsCollectionEnabled: Bool? = nil,
            configureSDKIfNeeded: (() -> Void)? = nil,
            backend: CrashlyticsBackend? = nil
        ) {
            self.isEnabled = isEnabled
            self.defaultDomain = defaultDomain
            self.assertionEnvironmentVariable = assertionEnvironmentVariable
            self.crashlyticsCollectionEnabled = crashlyticsCollectionEnabled
            self.configureSDKIfNeeded = configureSDKIfNeeded ?? Self.defaultConfigureSDKIfNeeded
            self.backend = backend ?? Self.defaultBackend
        }

        private static var defaultConfigureSDKIfNeeded: () -> Void {
            {
                #if canImport(FirebaseCore)
                if FirebaseApp.app() == nil {
                    FirebaseApp.configure()
                }
                #endif
            }
        }

        private static var defaultBackend: CrashlyticsBackend {
            #if canImport(FirebaseCrashlytics)
            FirebaseCrashlyticsBackend()
            #else
            NoopCrashlyticsBackend()
            #endif
        }
    }

    public static let shared = CrashlyticsManager()

    private static let configurationLock = NSLock()
    private static var isConfigured: Bool = false

    public private(set) var configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func setConfiguration(_ configuration: Configuration) {
        self.configuration = configuration
    }

    public func configure() {
        Self.configurationLock.lock()
        defer { Self.configurationLock.unlock() }

        guard configuration.isEnabled else { return }
        guard !Self.isConfigured else { return }
        Self.isConfigured = true

        configuration.configureSDKIfNeeded()
        if let crashlyticsCollectionEnabled = configuration.crashlyticsCollectionEnabled {
            configuration.backend.setCrashlyticsCollectionEnabled(crashlyticsCollectionEnabled)
        }
    }

    public func log(_ message: String) {
        guard configuration.isEnabled else { return }
        configuration.backend.log(message)
    }

    public func setUserID(_ userID: String?) {
        guard configuration.isEnabled else { return }
        configuration.backend.setUserID(userID ?? "")
    }

    public func setCustomValue(_ value: Any?, forKey key: String) {
        guard configuration.isEnabled else { return }
        configuration.backend.setCustomValue(value, forKey: key)
    }

    public func reportNonFatal(error: CrashlyticsNonFatalError, domain: CrashlyticsDomain? = nil) {
        report(error, domain: domain)
    }

    public func report(_ error: CrashlyticsNonFatalError, domain: CrashlyticsDomain? = nil) {
        guard configuration.isEnabled else { return }
        let resolvedDomain = domain ?? configuration.defaultDomain
        configuration.backend.record(error: error.asNSError(domain: resolvedDomain.rawValue))
    }

    public static func reportNonFatal(error: CrashlyticsNonFatalError, domain: String) {
        shared.reportNonFatal(error: error, domain: CrashlyticsDomain(domain))
    }

    public static func report(_ error: CrashlyticsNonFatalError, domain: String) {
        shared.report(error, domain: CrashlyticsDomain(domain))
    }
}

/// Non-fatal error captured by Crashlytics with rich context.
public struct CrashlyticsNonFatalError: LocalizedError {
    public let message: String
    public let file: String
    public let function: String
    public let line: UInt
    public let code: Int

    public init(_ message: String, _ file: String, _ function: String, _ line: UInt, _ code: Int = 0) {
        self.message = message
        self.file = file
        self.function = function
        self.line = line
        self.code = code
    }

    public init(
        _ message: String,
        file: StaticString = #fileID,
        function: StaticString = #function,
        line: UInt = #line,
        code: Int = 0
    ) {
        self.message = message
        self.file = "\(file)"
        self.function = "\(function)"
        self.line = line
        self.code = code
    }

    public var errorDescription: String? { message }

    public var userInfo: [String: Any] {
        [
            CrashlyticsNonFatalError.descriptionKey: message,
            CrashlyticsNonFatalError.fileKey: file,
            CrashlyticsNonFatalError.functionKey: function,
            CrashlyticsNonFatalError.lineKey: Int(line)
        ]
    }

    public func asNSError(domain: String) -> NSError {
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
public func nonFatalCrashlytics(
    _ condition: @autoclosure () -> Bool,
    _ message: @autoclosure () -> String,
    domain: CrashlyticsDomain? = nil,
    file: StaticString = #fileID,
    function: StaticString = #function,
    line: UInt = #line,
    code: Int = 0
) {
    let passed = condition()
    if passed { return }

    let assertionEnvironmentVariable = CrashlyticsManager.shared.configuration.assertionEnvironmentVariable
    if ProcessInfo.processInfo.environment[assertionEnvironmentVariable] != nil {
        // We already know the condition failed, so call assertionFailure directly.
        assertionFailure(message())
    }

    CrashlyticsManager.shared.reportNonFatal(
        error: CrashlyticsNonFatalError(message(), file: file, function: function, line: line, code: code),
        domain: domain
    )
}

/// Namespaces the crash reporting domain for easier categorization in Crashlytics.
public struct CrashlyticsDomain: Hashable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

public extension CrashlyticsDomain {
    static let `default`: CrashlyticsDomain = .init(
        rawValue: Bundle.main.bundleIdentifier ?? "crashlytics.manager.spm"
    )
}

private struct NoopCrashlyticsBackend: CrashlyticsBackend {
    func log(_ message: String) {}
    func record(error: NSError) {}
    func setUserID(_ userID: String) {}
    func setCustomValue(_ value: Any?, forKey key: String) {}
    func setCrashlyticsCollectionEnabled(_ enabled: Bool) {}
}

#if canImport(FirebaseCrashlytics)
private struct FirebaseCrashlyticsBackend: CrashlyticsBackend {
    private let crashlytics = Crashlytics.crashlytics()

    func log(_ message: String) {
        crashlytics.log(message)
    }

    func record(error: NSError) {
        crashlytics.record(error: error)
    }

    func setUserID(_ userID: String) {
        crashlytics.setUserID(userID)
    }

    func setCustomValue(_ value: Any?, forKey key: String) {
        crashlytics.setCustomValue(value, forKey: key)
    }

    func setCrashlyticsCollectionEnabled(_ enabled: Bool) {
        crashlytics.setCrashlyticsCollectionEnabled(enabled)
    }
}
#endif
