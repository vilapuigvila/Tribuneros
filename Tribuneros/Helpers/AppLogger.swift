//
//  AppLogger.swift
//  Tribuneros
//

import Foundation
import os

/// Debug-only system log (Console.app: subsystem = bundle id, one category per area). Release compiles every call away.
struct AppLogger {
    static let network = AppLogger(category: "Network")
    static let navigation = AppLogger(category: "Navigation")
    static let images = AppLogger(category: "Images")
    static let preferences = AppLogger(category: "Preferences")

    let category: String

    func debug(_ message: @autoclosure () -> String) {
        write(.debug, message())
    }

    func log(_ message: @autoclosure () -> String) {
        write(.default, message())
    }

    func error(_ message: @autoclosure () -> String) {
        write(.error, message())
    }

    /// Final destination of each line; replaced in tests to capture output.
    static var output: (_ category: String, _ level: OSLogType, _ message: String) -> Void = { category, level, message in
        Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.pskmoons.Tribuneros",
            category: category
        ).log(level: level, "\(message, privacy: .public)")
    }

    // In Release the body is empty, so the message closure never runs.
    private func write(_ level: OSLogType, _ message: @autoclosure () -> String) {
#if DEBUG
        Self.output(category, level, message())
#endif
    }
}
