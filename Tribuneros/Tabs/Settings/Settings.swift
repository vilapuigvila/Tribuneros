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
        case didSelectLanguage(String)
    }
}

// MARK: - View State -
extension Settings {
    struct ViewState: Equatable {
        let languageTitle: String
        let languages: [Representable.Language]

        static let idle = ViewState(
            languageTitle: "English",
            languages: [
                Representable.Language(
                    id: "en",
                    title: "English",
                    isSelected: true
                )
            ]
        )
    }

    enum Representable {
        struct Language: Equatable, Identifiable {
            let id: String
            let title: String
            let isSelected: Bool
        }
    }
}
