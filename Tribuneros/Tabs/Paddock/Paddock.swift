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
        let press: [PressItem]
        let filter: Filter
        let feed: Feed

        static let idle = ViewState(
            press: [],
            filter: .all,
            feed: .loading
        )
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
    }

    struct Section: Identifiable, Equatable {
        var id: String { title }
        let title: String
        let cards: [Card]
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
