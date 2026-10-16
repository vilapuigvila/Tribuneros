//
//  Settings.swift
//  Tribuneros
//

import Foundation

enum Settings { }

// MARK: - View Action -
extension Settings {
    enum Action {
        case didTapShowOnboarding
        case didTapLanguage
        case didTapAcknowledgements
        case didSelectLanguage(String)
        case didToggleHidesResults(Bool)
    }
}

// MARK: - View State -
extension Settings {
    struct ViewState: Equatable {
        let languageTitle: String
        let languages: [Representable.Language]
        let hidesResults: Bool

        static var idle: ViewState {
            ViewModel<InteractorImpl>.mapToViewState(
                from: Domain(language: Domain.defaultLanguage)
            )
        }
    }

    enum Representable {
        struct Language: Equatable, Identifiable {
            let id: String
            let title: String
            let isSelected: Bool
        }
    }
}
