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

    func testDefaultLanguageIsEnglish() {
        let interactor = makeInteractor()
        XCTAssertEqual(interactor.domain.language, "en")
        let state = Settings.ViewModel<Settings.InteractorImpl>.mapToViewState(from: interactor.domain)
        XCTAssertEqual(state.languageTitle, "English")
        XCTAssertEqual(state.languages.map(\.id), ["en"])
        XCTAssertEqual(state.languages.first?.isSelected, true)
    }

    func testUnknownStoredLanguageFallsBackToEnglish() {
        XCTAssertEqual(makeInteractor(stored: "xx").domain.language, "en")
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
        XCTAssertEqual(interactor.domain.language, "en")
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
        XCTAssertEqual(UserSettings.appLanguage, "en")
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
