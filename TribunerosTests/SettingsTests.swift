//
//  SettingsTests.swift
//  TribunerosTests
//

import XCTest
@testable import Tribuneros

final class SettingsTests: XCTestCase {
    private func makeInteractor(
        stored: String? = nil,
        saved: @escaping (String) -> Void = { _ in }
    ) -> Settings.InteractorImpl {
        Settings.InteractorImpl(
            store: Settings.Store(
                loadLanguage: { stored },
                saveLanguage: saved
            )
        )
    }

    override func setUp() {
        super.setUp()
        L10n.setLanguage("en")
    }

    func testDefaultLanguageFollowsTheSystem() {
        let interactor = makeInteractor()
        XCTAssertEqual(interactor.domain.language, "system")
        let state = Settings.ViewModel<Settings.InteractorImpl>.mapToViewState(from: interactor.domain)
        XCTAssertEqual(state.languageTitle, "System default")
        XCTAssertEqual(state.languages.map(\.id), ["system", "en", "ca"])
        XCTAssertEqual(state.languages.map(\.isSelected), [true, false, false])
    }

    func testLanguagesAreNamedInThemselves() {
        L10n.setLanguage("ca")
        defer { L10n.setLanguage("en") }
        let state = Settings.ViewModel<Settings.InteractorImpl>.mapToViewState(
            from: Settings.Domain(language: "ca")
        )
        XCTAssertEqual(state.languages.map(\.title), ["Predeterminat del sistema", "English", "Català"])
        XCTAssertEqual(state.languageTitle, "Català")
    }

    func testUnknownStoredLanguageFallsBackToSystem() {
        XCTAssertEqual(makeInteractor(stored: "xx").domain.language, "system")
    }

    func testSelectingCatalanSaves() {
        var saved: [String] = []
        let interactor = makeInteractor { saved.append($0) }
        interactor.useCase(.selectLanguage("ca"))
        XCTAssertEqual(interactor.domain.language, "ca")
        XCTAssertEqual(saved, ["ca"])
    }

    func testSelectingEnglishKeepsItAndSaves() {
        var saved: [String] = []
        let interactor = makeInteractor { saved.append($0) }
        interactor.useCase(.selectLanguage("en"))
        XCTAssertEqual(interactor.domain.language, "en")
        XCTAssertEqual(saved, ["en"])
    }

    func testSelectingUnsupportedLanguageIsIgnored() {
        var saved: [String] = []
        let interactor = makeInteractor { saved.append($0) }
        interactor.useCase(.selectLanguage("fr"))
        XCTAssertEqual(interactor.domain.language, "system")
        XCTAssertTrue(saved.isEmpty)
    }

    func testLanguagePersistsThroughUserSettingsKey() {
        let previous = UserDefaults.standard.data(forKey: UserPreferencesKey.appLanguage.rawValue)
        defer {
            UserDefaults.standard.set(
                previous,
                forKey: UserPreferencesKey.appLanguage.rawValue
            )
        }
        UserDefaults.standard.removeObject(forKey: UserPreferencesKey.appLanguage.rawValue)
        XCTAssertEqual(UserSettings.appLanguage, "system")
        makeStoreInteractor().useCase(.selectLanguage("en"))
        XCTAssertNotNil(UserDefaults.standard.data(forKey: UserPreferencesKey.appLanguage.rawValue))
        XCTAssertEqual(makeStoreInteractor().domain.language, "en")
    }

    private func makeStoreInteractor() -> Settings.InteractorImpl {
        Settings.InteractorImpl(store: .userSettings)
    }

    @MainActor
    func testReplayShowsWelcomeBackWithoutTouchingTheSchedule() {
        var saves = 0
        let presenter = Onboarding.Presenter(
            store: Onboarding.Store(
                load: { Onboarding.Record(firstShown: nil, count: 0) },
                save: { _ in saves += 1 }
            )
        )
        presenter.replay()
        XCTAssertEqual(presenter.showing, 2)
        XCTAssertEqual(saves, 0)
        XCTAssertEqual(
            Onboarding.pages(showing: presenter.showing ?? 1).first?.title,
            "Welcome back to Cycling Tribune"
        )
        presenter.dismiss(.skip)
        XCTAssertNil(presenter.showing)
        XCTAssertEqual(saves, 0)
    }
}
