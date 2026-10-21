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
        /// A press circle opens the site's native headlines screen.
        case didTapOnPress(PressItem)
        /// Transfer, program and birthday cards open the native rider screen.
        case didTapOnRider(RiderContext)
        /// The rider screen's "Season results" link.
        case didTapOnSeasonResults(SeasonResultsContext)
    }

    enum Filter: CaseIterable, Sendable {
        case all
        case transfers
        case programs
        case birthdays

        var title: String {
            switch self {
            case .all: L10n.tr("All")
            case .transfers: L10n.tr("Transfers")
            case .programs: L10n.tr("Programs")
            case .birthdays: L10n.tr("Birthdays")
            }
        }
    }

    /// The Moves section's segmented control; each side shows one kind of feed card.
    enum Segment: CaseIterable, Sendable {
        case transfers
        case programs

        var filter: Filter {
            switch self {
            case .transfers: .transfers
            case .programs: .programs
            }
        }

        var title: String { filter.title }

        init(filter: Filter) {
            self = filter == .programs ? .programs : .transfers
        }
    }
}

// MARK: - View State -
extension Paddock {
    struct ViewState: Equatable {
        let press: Press
        let filter: Filter
        let feed: Feed
        /// Every birthday in the feed, shown on their own card above Moves.
        var birthdays: [BirthdaysCard.Entry] = []
        var transferCount = 0
        var programCount = 0

        /// The birthday card shows at most this many rows; a sheet lists them all.
        static let birthdaysPreviewLimit = 3

        var previewBirthdays: [BirthdaysCard.Entry] { Array(birthdays.prefix(Self.birthdaysPreviewLimit)) }
        var hasMoreBirthdays: Bool { birthdays.count > Self.birthdaysPreviewLimit }

        var segment: Segment { Segment(filter: filter) }

        func count(of segment: Segment) -> Int {
            switch segment {
            case .transfers: transferCount
            case .programs: programCount
            }
        }

        static let idle = ViewState(
            press: .loading,
            filter: .transfers,
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

    struct PressItem: Identifiable, Hashable {
        var id: URL { url }
        let url: URL
        let name: String
        let domain: String?

        // Cloudflare blocks the app from these sites' feeds, so their circle opens the site itself.
        private static let webOnlyHosts: Set<String> = ["ciclismo2005.com"]

        var opensInWebView: Bool {
            let host = url.host()?.lowercased() ?? ""
            return Self.webOnlyHosts.contains(host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
        }

        /// "Escape Collective" → "EC", "cyclingnews.com" → "CY": the press circle's stand-in logo.
        var monogram: String {
            // A bare domain ("cyclingnews.com") is one word: its site name, without the TLD.
            let base = !name.contains(" ") && name.contains(".")
                ? String(name.split(separator: ".").dropLast().joined(separator: "."))
                : name
            let words = base
                .split { !$0.isLetter && !$0.isNumber }
                .filter { !$0.isEmpty }
            let letters = words.count > 1
                ? words.prefix(2).compactMap(\.first).map(String.init).joined()
                : String(words.first?.prefix(2) ?? "")
            return letters.uppercased()
        }

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
        /// The English day name ("Today", "Yesterday", "Earlier"): the view model groups by it.
        let title: String
        let cards: [Card]

        /// The day name in the active language, for the view.
        var displayTitle: String {
            switch title {
            case "Yesterday": L10n.tr("Yesterday")
            case "Earlier": L10n.tr("Earlier")
            default: L10n.tr("Today")
            }
        }

        /// Stand-ins shaped like a real feed, drawn redacted while it loads.
        static let placeholders: [Section] = {
            let rider = Rider(
                name: "RIDER Name",
                countryCode: "",
                url: nil
            )
            return [
                .init(
                    title: "Today", // l10n:ignore: English day key, the same as the feed grouping
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

    /// The feed card a rider screen was opened from; its data heads that screen.
    enum RiderContext: Hashable {
        case transfer(TransferCard)
        case program(ProgramCard)
        case birthday(BirthdaysCard.Entry)

        var rider: Rider {
            switch self {
            case .transfer(let card): card.rider
            case .program(let card): card.rider
            case .birthday(let entry): entry.rider
            }
        }
    }

    struct Rider: Hashable {
        let name: String
        let countryCode: String
        let url: URL?
    }

    struct TransferCard: Hashable {
        let id: String
        let date: String
        let rider: Rider
        let teamName: String
    }

    struct ProgramCard: Hashable {
        struct Change: Hashable {
            let isAdded: Bool
            let raceName: String
        }

        let id: String
        let timeAgo: String
        let rider: Rider
        let changes: [Change]
    }

    struct BirthdaysCard: Equatable {
        struct Entry: Hashable {
            let rider: Rider
            let age: String
        }

        let id: String
        let entries: [Entry]
    }
}
