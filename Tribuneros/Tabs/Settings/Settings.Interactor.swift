//
//  Settings.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension Settings {
    struct Domain: Equatable {
        var language: String
        /// Today Races results start hidden behind the spoiler painting.
        var hidesResults = true

        /// Follow the device's languages until the user picks one.
        static let defaultLanguage = AppLanguage.system
        /// "System default" first, then each bundled language by its own name.
        /// Adding a language is one entry in `AppLanguage.localizations`.
        static var supportedLanguages: [(code: String, title: String)] {
            AppLanguage.supported.map { (code: $0, title: title(for: $0)) }
        }

        static func title(for code: String) -> String {
            if code == AppLanguage.system {
                return L10n.tr("System default")
            }
            return AppLanguage.endonym(code) ?? code
        }
    }

    enum UseCase: Sendable {
        case selectLanguage(String)
        case setHidesResults(Bool)
    }

    struct Store {
        var loadLanguage: () -> String?
        var saveLanguage: (String) -> Void
        var loadHidesResults: () -> Bool? = { true }
        var saveHidesResults: (Bool) -> Void = { _ in }

        static let userSettings = Store(
            loadLanguage: { UserSettings.appLanguage },
            saveLanguage: { code in
                UserSettings.appLanguage = code
                Task { @MainActor in
                    AppLocalization.shared.apply(stored: code)
                }
            },
            // Today Races listens to the key, so the change applies without a restart.
            loadHidesResults: { UserSettings.hidesResults },
            saveHidesResults: { UserSettings.hidesResults = $0 }
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
            subject = CurrentValueSubject(
                Domain(
                    language: language,
                    hidesResults: store.loadHidesResults() ?? true
                )
            )
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .selectLanguage(let code):
                guard Domain.supportedLanguages.contains(where: { $0.code == code }) else { return }
                store.saveLanguage(code)
                var updated = subject.value
                updated.language = code
                subject.send(updated)
            case .setHidesResults(let value):
                guard value != subject.value.hidesResults else { return }
                store.saveHidesResults(value)
                var updated = subject.value
                updated.hidesResults = value
                subject.send(updated)
            }
        }
    }
}
