//
//  NetworkLog.swift
//  Tribuneros
//

import Foundation
import os

/// Debug-only `[NETWORK]` lines for the requests that don't go through Alfy; same prefix as Alfy's own.
enum NetworkLog {
    enum Source: String {
        case server
        case cache
    }

    /// The unified log cuts a message at about 1 KB, so a body goes out in chunks under this size.
    static let chunkBytes = 800

    /// Summary, then the body as pretty JSON over numbered `.debug` lines; `object == nil` logs `missing`.
    static func json(
        _ url: String,
        source: Source,
        object: @autoclosure () -> Any?,
        duration: TimeInterval
    ) {
        #if DEBUG
        for (level, line) in jsonLines(
            url,
            source: source,
            object: object(),
            duration: duration
        ) {
            switch level {
            case .debug: AppLogger.network.debug(line)
            case .error: AppLogger.network.error(line)
            default: AppLogger.network.log(line)
            }
        }
        #endif
    }

    /// One summary line for an HTML page; `.error` for status ≥ 400.
    static func page(
        _ url: URL?,
        status: Int?,
        bytes: Int,
        duration: TimeInterval
    ) {
        #if DEBUG
        let isFailure = (status ?? 0) >= 400
        let line = "[NETWORK] - \(url?.absoluteString ?? "-") - status \(status.map(String.init) ?? "-") · \(size(bytes)) · \(milliseconds(duration))"
        if isFailure {
            AppLogger.network.error(line)
        } else {
            AppLogger.network.log(line)
        }
        #endif
    }

    static func failure(
        _ url: String,
        error: Error,
        duration: TimeInterval
    ) {
        #if DEBUG
        AppLogger.network.error("[NETWORK] - \(url) - failed: \(error.localizedDescription) · \(milliseconds(duration))")
        #endif
    }

    /// Pure, for tests: the lines `json` writes.
    static func jsonLines(
        _ url: String,
        source: Source,
        object: Any?,
        duration: TimeInterval
    ) -> [(OSLogType, String)] {
        let prefix = "[NETWORK] - \(url) - "
        guard let object else {
            return [(.default, "\(prefix)\(source.rawValue) · missing · \(milliseconds(duration))")]
        }
        let pretty = prettyJSON(object)
        let bytes = compactJSON(object).utf8.count
        var lines: [(OSLogType, String)] = [
            (.default, "\(prefix)\(source.rawValue) · \(size(bytes)) · \(milliseconds(duration))")
        ]
        let parts = chunks(pretty)
        for (index, part) in parts.enumerated() {
            lines.append((.debug, "\(prefix)(\(index + 1)/\(parts.count)) \(part)"))
        }
        return lines
    }

    /// Packs whole lines into pieces of at most `limit` UTF-8 bytes; a longer single line is split by characters.
    static func chunks(
        _ text: String,
        limit: Int = chunkBytes
    ) -> [String] {
        var result: [String] = []
        var current = ""
        var currentBytes = 0
        func flush() {
            if !current.isEmpty {
                result.append(current)
                current = ""
                currentBytes = 0
            }
        }
        for line in text.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            var pieces: [String] = []
            if line.utf8.count > limit {
                var piece = ""
                for character in line {
                    if piece.utf8.count + character.utf8.count > limit {
                        pieces.append(piece)
                        piece = ""
                    }
                    piece.append(character)
                }
                pieces.append(piece)
            } else {
                pieces = [String(line)]
            }
            for piece in pieces {
                let added = piece.utf8.count + (current.isEmpty ? 0 : 1)
                if currentBytes + added > limit {
                    flush()
                }
                current += (current.isEmpty ? "" : "\n") + piece
                currentBytes = current.utf8.count
            }
        }
        flush()
        return result
    }

    private static func prettyJSON(_ object: Any) -> String {
        serialize(
            object,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func compactJSON(_ object: Any) -> String {
        serialize(
            object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func serialize(
        _ object: Any,
        options: JSONSerialization.WritingOptions
    ) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(
                  withJSONObject: object,
                  options: options
              )
        else {
            return "\(object)"
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .file
        )
    }

    private static func milliseconds(_ duration: TimeInterval) -> String {
        "\(Int(duration * 1000)) ms"
    }
}
