//
//  Paddock.PressPage.ViewModel.swift
//  Tribuneros
//

import Foundation
import Combine

extension Paddock.PressPage {

    final class ViewModel<Interactor: InteractorProtocol>: ObservableObject
        where Interactor.Domain == Paddock.PressPage.Domain, Interactor.UseCase == Paddock.PressPage.UseCase {

        @Published private(set) var stateView: ViewState

        let router: Router
        let interactor: Interactor

        init(
            router: Router,
            interactor: Interactor
        ) {
            self.router = router
            self.interactor = interactor
            stateView = Self.mapToViewState(
                interactor.domain,
                now: Date()
            )
            interactor
                .publisher
                .receive(on: DispatchQueue.main)
                .map { Self.mapToViewState($0, now: Date()) }
                .assign(to: &$stateView)
        }

        func action(_ action: Action) {
            switch action {
            case .onAppear:
                interactor.useCase(.load)
            case .openArticle(let url):
                router.openInSystem(url)
            case .openSite:
                router.openInSystem(interactor.domain.item.url)
            }
        }

        static func mapToViewState(
            _ domain: Domain,
            now: Date
        ) -> ViewState {
            let item = domain.item
            let header = (
                name: item.name,
                monogram: item.monogram,
                domain: item.domain ?? item.url.host ?? item.url.absoluteString
            )
            let body: ViewState.Body
            switch domain.load {
            case .idle, .loading:
                body = .loading
            case .loaded(let feed):
                let rows = rows(
                    from: feed.articles,
                    now: now
                )
                body = rows.isEmpty
                    ? .unavailable(L10n.tr("No headlines found for this site."))
                    : .loaded(rows)
            case .failed:
                body = .unavailable(L10n.tr("Couldn’t load the headlines for this site."))
            }
            return ViewState(
                name: header.name,
                monogram: header.monogram,
                domain: header.domain,
                body: body
            )
        }

        /// Newest first; articles without a date keep their place after the dated ones.
        static func rows(
            from articles: [DTO.PressFeed.Article],
            now: Date
        ) -> [ViewState.Row] {
            let formatter = L10n.relativeFormatter()
            let indexed = Array(articles.enumerated())
            let dated = indexed
                .filter { $0.element.date != nil }
                .sorted { lhs, rhs in
                    guard let left = lhs.element.date, let right = rhs.element.date, left != right else {
                        return lhs.offset < rhs.offset
                    }
                    return left > right
                }
            let undated = indexed.filter { $0.element.date == nil }
            return (dated + undated)
                .prefix(Paddock.PressPage.headlineLimit)
                .map { entry in
                    let article = entry.element
                    return ViewState.Row(
                        url: article.url,
                        title: article.title,
                        date: article.date.map { formatter.localizedString(for: $0, relativeTo: now) } ?? "",
                        imageURL: article.imageURL,
                        summary: article.summary
                    )
                }
        }
    }
}
