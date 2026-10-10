//
//  Settings.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension Settings {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == Settings.Domain, Interactor.UseCase == Settings.UseCase {

        @Published private(set) var stateView: Settings.ViewState

        let router: Router
        let interactor: Interactor

        init(router: Router, interactor: Interactor) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(from: interactor.domain)
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { Self.mapToViewState(from: $0) }
                .assign(to: &$stateView)
        }

        /// `didTapShowOnboarding` is handled by the view, which holds the host's replay closure.
        func action(_ action: Settings.Action) {
            switch action {
            case .didTapShowOnboarding:
                break
            case .didTapLanguage:
                router.routeTo(.settingsLanguage)
            case .didSelectLanguage(let code):
                interactor.useCase(.selectLanguage(code))
            }
        }

        static func mapToViewState(from domain: Settings.Domain) -> Settings.ViewState {
            let languages = Settings.Domain.supportedLanguages.map {
                Settings.Representable.Language(
                    id: $0.code,
                    title: $0.title,
                    isSelected: $0.code == domain.language
                )
            }
            return Settings.ViewState(
                languageTitle: languages.first { $0.isSelected }?.title ?? Settings.Domain.title(for: Settings.Domain.defaultLanguage),
                languages: languages
            )
        }
    }
}
