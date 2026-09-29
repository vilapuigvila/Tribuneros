//
//  Paddock.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import Foundation

enum Paddock { }

// MARK: - View Action -
extension Paddock {
    enum Action {
        case didAppear
        case didRequestRefresh
        case didSelectFilter(Filter)
        case didTapOnLink(URL?)
    }

    enum Filter: CaseIterable, Sendable {
        case all
        case transfers
        case programs
        case birthdays

        var title: String {
            switch self {
            case .all: "All"
            case .transfers: "Transfers"
            case .programs: "Programs"
            case .birthdays: "Birthdays"
            }
        }
    }
}

// MARK: - View State -
extension Paddock {
    struct ViewState: Equatable {
        let press: Press
        let filter: Filter
        let feed: Feed

        static let idle = ViewState(
            press: .loading,
            filter: .all,
            feed: .loading
        )
    }

    enum Press: Equatable {
        /// No list known yet: the panel shows redacted placeholder cards.
        case loading
        /// An empty list hides the panel.
        case loaded([PressItem])
    }

    enum Feed: Equatable {
        case loading
        case loaded([Section])
        case empty
        case error
    }

    struct PressItem: Identifiable, Equatable {
        var id: URL { url }
        let url: URL
        let name: String
        let domain: String?

        /// Stand-ins shaped like real cards, drawn redacted while the list loads.
        static let placeholders: [PressItem] = (1...4).map { index in
            .init(
                url: URL(string: "https://placeholder.invalid/\(index)")!,
                name: "Cycling news",
                domain: "cyclingnews.com"
            )
        }
    }

    struct Section: Identifiable, Equatable {
        var id: String { title }
        let title: String
        let cards: [Card]

        /// Stand-ins shaped like a real feed, drawn redacted while it loads.
        static let placeholders: [Section] = {
            let rider = Rider(
                name: "RIDER Name",
                countryCode: "",
                url: nil
            )
            return [
                .init(
                    title: "Today",
                    cards: [
                        .transfer(
                            .init(
                                id: "placeholder-transfer-1",
                                date: "00/00",
                                rider: rider,
                                teamName: "Team name placeholder"
                            )
                        ),
                        .program(
                            .init(
                                id: "placeholder-program",
                                timeAgo: "0h",
                                rider: rider,
                                changes: [
                                    .init(
                                        isAdded: true,
                                        raceName: "Race name placeholder"
                                    )
                                ]
                            )
                        ),
                        .birthdays(
                            .init(
                                id: "placeholder-birthdays",
                                entries: [
                                    .init(
                                        rider: rider,
                                        age: "00"
                                    ),
                                    .init(
                                        rider: rider,
                                        age: "00"
                                    )
                                ]
                            )
                        ),
                        .transfer(
                            .init(
                                id: "placeholder-transfer-2",
                                date: "00/00",
                                rider: rider,
                                teamName: "Team name placeholder"
                            )
                        )
                    ]
                )
            ]
        }()
    }

    enum Card: Identifiable, Equatable {
        case transfer(TransferCard)
        case program(ProgramCard)
        case birthdays(BirthdaysCard)

        var id: String {
            switch self {
            case .transfer(let card): card.id
            case .program(let card): card.id
            case .birthdays(let card): card.id
            }
        }
    }

    struct Rider: Equatable {
        let name: String
        let countryCode: String
        let url: URL?
    }

    struct TransferCard: Equatable {
        let id: String
        let date: String
        let rider: Rider
        let teamName: String
    }

    struct ProgramCard: Equatable {
        struct Change: Equatable {
            let isAdded: Bool
            let raceName: String
        }

        let id: String
        let timeAgo: String
        let rider: Rider
        let changes: [Change]
    }

    struct BirthdaysCard: Equatable {
        struct Entry: Equatable {
            let rider: Rider
            let age: String
        }

        let id: String
        let entries: [Entry]
    }
}
