//
//  Paddock.PressPage.swift
//  Tribuneros
//
//  A press site's native headlines screen (route `paddockPress`): the latest articles of the
//  site's own feed (title, date, image, the feed's short summary). A headline, or "Open site"
//  when no feed could be read, hands off to the system browser.
//

import Foundation

extension Paddock {
    enum PressPage {

        /// Headlines kept on screen; the feed already caps itself, this is the screen's own limit.
        static let headlineLimit = 30

        enum Action: Sendable {
            case onAppear
            case openArticle(URL)
            case openSite
        }

        struct ViewState: Equatable {
            struct Row: Identifiable, Equatable {
                var id: URL { url }
                let url: URL
                let title: String
                /// "2 hr. ago", empty when the feed gave no date.
                let date: String
                let imageURL: URL?
                let summary: String?
            }

            enum Body: Equatable {
                case loading
                case loaded([Row])
                case unavailable(String)
            }

            let name: String
            let monogram: String
            let domain: String
            let body: Body

            /// Stand-ins drawn redacted while the feed loads.
            static let placeholders: [Row] = (1...5).map { index in
                Row(
                    url: URL(string: "https://placeholder.invalid/\(index)")!,
                    title: "Headline placeholder that runs onto two lines", // l10n:ignore
                    date: "0 hr. ago", // l10n:ignore
                    imageURL: nil,
                    summary: "Summary placeholder that runs over a few lines of the card, like the real one does." // l10n:ignore
                )
            }
        }
    }
}
