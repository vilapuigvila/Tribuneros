//
//  L10n.swift
//  Tribuneros
//

import Foundation

/// Looks up display text in `Localizable.xcstrings` for the language chosen in Settings,
/// not the device language. Keys are the English text; `TribuneruText.content` is verbatim,
/// so every display string goes through `L10n.tr` (scraped names never do).
///
///     L10n.tr("Races")
///     L10n.tr("in %@", duration)
///     L10n.tr("%lld races", count)   // plural variations in the catalog; pass Int
///
/// Keep the key a string literal: `scripts/l10n/check_localization.py` extracts it.
enum L10n {
    private struct State {
        let code: String
        let bundle: Bundle
        let locale: Locale
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var state = makeState(code: AppLanguage.fallback)
    nonisolated(unsafe) private static var formatters: [String: DateFormatter] = [:]

    /// The active localization code (`en`, `ca`).
    static var languageCode: String { current.code }
    /// Use it for every display formatter, `uppercased(with:)` and `formatted(...)` call.
    static var locale: Locale { current.locale }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let state = current
        let format = state.bundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
        guard !args.isEmpty else { return format }
        return String(
            format: format,
            locale: state.locale,
            arguments: args
        )
    }

    /// A display formatter for a date template ("dMMMMyyyy", "EEEEdMMMMyyyy", "HHmm"),
    /// cached per language. Parsers stay on `en_US_POSIX` and never use this.
    static func dateFormatter(template: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }
        let cacheKey = "\(state.code)|\(template)"
        if let formatter = formatters[cacheKey] {
            return formatter
        }
        let formatter = DateFormatter()
        formatter.locale = state.locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatters[cacheKey] = formatter
        return formatter
    }

    /// A relative formatter ("5 min ago" / "fa 5 min") in the active language.
    static func relativeFormatter(
        unitsStyle: RelativeDateTimeFormatter.UnitsStyle = .abbreviated
    ) -> RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = unitsStyle
        return formatter
    }

    /// Switches the language used by every later lookup. `code` must be a bundled localization.
    static func setLanguage(_ code: String) {
        let newState = makeState(code: code)
        lock.lock()
        state = newState
        formatters = [:]
        lock.unlock()
    }

    private static var current: State {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    private static func makeState(code: String) -> State {
        let bundle = Bundle.main
            .path(forResource: code, ofType: "lproj")
            .flatMap(Bundle.init(path:)) ?? .main
        return State(
            code: code,
            bundle: bundle,
            // The chosen language with the device's region, so date and number
            // conventions stay the user's own.
            locale: Locale(
                languageCode: Locale.LanguageCode(code),
                languageRegion: Locale.current.region
            )
        )
    }
}
