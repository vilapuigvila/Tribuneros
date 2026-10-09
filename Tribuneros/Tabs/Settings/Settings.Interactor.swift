//
//  Settings.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension Settings {
    struct Domain: Equatable {
        var language: String

        static let defaultLanguage = "en"
        /// Adding a language is one entry here.
        static let supportedLanguages: [(code: String, title: String)] = [
            (code: "en", title: "English")
        ]
    }

    enum UseCase: Sendable {
        case selectLanguage(String)
    }

    struct Store {
        var loadLanguage: () -> String?
        var saveLanguage: (String) -> Void

        static let userSettings = Store(
            loadLanguage: { UserSettings.appLanguage },
            saveLanguage: { UserSettings.appLanguage = $0 }
        )
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = Settings.Domain
        typealias UseCase = Settings.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        private let store: Store

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(store: Store = .userSettings) {
            self.store = store
            let stored = store.loadLanguage()
            let language = Domain.supportedLanguages.contains { $0.code == stored }
                ? stored ?? Domain.defaultLanguage
                : Domain.defaultLanguage
            subject = CurrentValueSubject(Domain(language: language))
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .selectLanguage(let code):
                guard Domain.supportedLanguages.contains(where: { $0.code == code }) else { return }
                store.saveLanguage(code)
                subject.send(Domain(language: code))
            }
        }
    }
}
