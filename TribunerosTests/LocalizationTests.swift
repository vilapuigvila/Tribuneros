//
//  LocalizationTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class AppLanguageTests: XCTestCase {
    func testSystemFollowsThePreferredLanguages() {
        XCTAssertEqual(AppLanguage.resolve(stored: "system", preferred: ["ca-ES", "en"]), "ca")
        XCTAssertEqual(AppLanguage.resolve(stored: "system", preferred: ["en-GB", "ca"]), "en")
        XCTAssertEqual(AppLanguage.resolve(stored: "system", preferred: ["eu-ES", "es"]), "eu")
        XCTAssertEqual(AppLanguage.resolve(stored: "system", preferred: ["es-ES", "en"]), "es")
        XCTAssertEqual(AppLanguage.resolve(stored: "system", preferred: ["es-MX"]), "es")
    }

    func testSystemFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.resolve(stored: "system", preferred: ["fr-FR", "de"]), "en")
    }

    func testAnExplicitChoiceWins() {
        XCTAssertEqual(AppLanguage.resolve(stored: "en", preferred: ["ca-ES"]), "en")
        XCTAssertEqual(AppLanguage.resolve(stored: "ca", preferred: ["en-US"]), "ca")
        XCTAssertEqual(AppLanguage.resolve(stored: "eu", preferred: ["ca-ES"]), "eu")
        XCTAssertEqual(AppLanguage.resolve(stored: "es", preferred: ["ca-ES"]), "es")
    }

    func testMissingOrUnknownStoredValueFollowsTheSystem() {
        XCTAssertEqual(AppLanguage.resolve(stored: nil, preferred: ["ca"]), "ca")
        XCTAssertEqual(AppLanguage.resolve(stored: "xx", preferred: ["en"]), "en")
    }

    func testEndonyms() {
        XCTAssertEqual(AppLanguage.endonym("en"), "English")
        XCTAssertEqual(AppLanguage.endonym("ca"), "Català")
        XCTAssertEqual(AppLanguage.endonym("eu"), "Euskara")
        XCTAssertEqual(AppLanguage.endonym("es"), "Castellano")
        XCTAssertNil(AppLanguage.endonym("system"))
    }
}

final class L10nTests: XCTestCase {
    override func tearDown() {
        L10n.setLanguage("en")
        super.tearDown()
    }

    func testTheAppBundlesCatalanBasqueAndCastellano() {
        for code in ["ca", "eu", "es"] {
            XCTAssertTrue(Bundle.main.localizations.contains(code))
            XCTAssertNotNil(Bundle.main.path(forResource: code, ofType: "lproj"))
        }
    }

    func testEnglishReturnsTheKey() {
        L10n.setLanguage("en")
        XCTAssertEqual(L10n.tr("Settings"), "Settings")
    }

    func testCatalanTranslates() {
        L10n.setLanguage("ca")
        XCTAssertEqual(L10n.languageCode, "ca")
        XCTAssertEqual(L10n.tr("Settings"), "Configuració")
        XCTAssertEqual(L10n.tr("Road"), "Carretera")
    }

    func testBasqueTranslates() {
        L10n.setLanguage("eu")
        XCTAssertEqual(L10n.languageCode, "eu")
        XCTAssertEqual(L10n.tr("Settings"), "Ezarpenak")
        XCTAssertEqual(L10n.tr("Road"), "Errepidea")
        XCTAssertEqual(L10n.tr("%lld races", 3), "3 lasterketa")
    }

    func testCastellanoTranslates() {
        L10n.setLanguage("es")
        XCTAssertEqual(L10n.languageCode, "es")
        XCTAssertEqual(L10n.tr("Settings"), "Ajustes")
        XCTAssertEqual(L10n.tr("Road"), "Carretera")
        XCTAssertEqual(L10n.tr("%lld races", 1), "1 carrera")
        XCTAssertEqual(L10n.tr("%lld races", 3), "3 carreras")
    }

    func testAMissingKeyFallsBackToItself() {
        L10n.setLanguage("ca")
        XCTAssertEqual(L10n.tr("Not a key in the catalog"), "Not a key in the catalog")
    }

    func testSwitchingBackRestoresEnglish() {
        L10n.setLanguage("ca")
        L10n.setLanguage("en")
        XCTAssertEqual(L10n.tr("Settings"), "Settings")
    }

    func testDateFormattersFollowTheLanguage() {
        var components = DateComponents()
        components.year = 2026
        components.month = 10
        components.day = 10
        let date = Calendar.current.date(from: components)!
        L10n.setLanguage("ca")
        XCTAssertTrue(
            L10n.dateFormatter(template: "dMMMMyyyy").string(from: date).contains("octubre")
        )
        L10n.setLanguage("en")
        XCTAssertTrue(
            L10n.dateFormatter(template: "dMMMMyyyy").string(from: date).contains("October")
        )
    }

    func testRelativeTimeFollowsTheLanguage() {
        L10n.setLanguage("ca")
        let text = L10n.relativeFormatter(unitsStyle: .full).localizedString(
            fromTimeInterval: -3600
        )
        XCTAssertTrue(
            text.hasPrefix("fa "),
            text
        )
    }
}

/// Re-checks the catalog from source, so a missing Catalan, Basque or Castellano value fails on macOS too
/// (the full check is `scripts/l10n/check_localization.py`).
final class LocalizationCatalogTests: XCTestCase {
    func testEveryKeyHasCatalanBasqueAndCastellanoValues() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tribuneros/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["sourceLanguage"] as? String, "en")
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])
        XCTAssertGreaterThan(strings.count, 100)
        for (key, entry) in strings {
            let localizations = entry["localizations"] as? [String: Any]
            XCTAssertNotNil(
                localizations?["ca"],
                "No Catalan for \(key)"
            )
            XCTAssertNotNil(
                localizations?["eu"],
                "No Basque for \(key)"
            )
            XCTAssertNotNil(
                localizations?["es"],
                "No Castellano for \(key)"
            )
        }
    }
}
