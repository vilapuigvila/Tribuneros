//
//  AppLanguage.swift
//  Tribuneros
//

import Foundation

/// The languages the app ships, plus `system` (follow the device's preferred languages).
/// Adding a language is one entry in `localizations`, a catalog translation and `knownRegions`.
enum AppLanguage {
    static let system = "system"
    static let fallback = "en"
    /// Bundled localizations, in the order the Language screen lists them.
    static let localizations = ["en", "ca"]
    /// Every value `UserSettings.appLanguage` may hold.
    static let supported = [system] + localizations

    /// Endonyms: each language is named in itself, so they are never translated.
    static func endonym(_ code: String) -> String? {
        switch code {
        case "en": "English"
        case "ca": "Català"
        default: nil
        }
    }

    /// The bundled localization to use for a stored choice. `system`, `nil` or an unknown
    /// value follow the device's preferred languages, falling back to English.
    static func resolve(
        stored: String?,
        preferred: [String] = Locale.preferredLanguages
    ) -> String {
        if let stored, localizations.contains(stored) {
            return stored
        }
        return Bundle.preferredLocalizations(
            from: localizations,
            forPreferences: preferred
        ).first.flatMap { localizations.contains($0) ? $0 : nil } ?? fallback
    }
}
