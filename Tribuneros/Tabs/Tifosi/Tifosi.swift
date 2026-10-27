//
//  Tifosi.swift
//  Tribuneros
//

import Foundation
import SwiftUI

enum Tifosi { }

// MARK: - Model -
extension Tifosi {
    /// Where a post comes from; the first five cases are filter chips, `.reddit` has no chip.
    enum Channel: String, CaseIterable, Equatable, Sendable {
        case tv, radio, x, bluesky, instagram, reddit

        static var chips: [Channel] { [.tv, .radio, .x, .bluesky, .instagram] }

        /// Only these chips have a content source yet; the rest are shown disabled.
        var isAvailable: Bool { self == .tv }

        var title: String {
            switch self {
            case .tv: L10n.tr("TV")
            case .radio: L10n.tr("Radio")
            case .x: L10n.tr("X")
            case .bluesky: L10n.tr("Bluesky")
            case .instagram: L10n.tr("Instagram")
            case .reddit: "Reddit" // l10n:ignore: brand name
            }
        }
    }

    enum Kind: Equatable, Sendable {
        case post, radio, tv

        var tag: String {
            switch self {
            case .post: L10n.tr("POST")
            case .radio: L10n.tr("RADIO")
            case .tv: L10n.tr("TV")
            }
        }
    }

    struct Post: Equatable, Identifiable, Sendable {
        let id: String
        let channel: Channel
        let kind: Kind
        let initials: String
        let handle: String
        let source: String
        /// "1h" for the leader, "+0:12" for the chase.
        let age: String
        let text: String
        let shares: String?
        let likes: String?
        let isStale: Bool
    }
}

// MARK: - TV guide -
extension Tifosi {
    struct TVChannel: Equatable, Identifiable, Sendable {
        let name: String
        let regions: String
        let url: URL?
        /// The channel's regions include the device's region.
        let isLocal: Bool
        var id: String { name }
    }

    struct TVRace: Equatable, Identifiable, Sendable {
        let id: String
        let title: String
        let meta: String
        let discipline: String
        let start: Date?
        let end: Date?
        /// "14:30", or a dash when the schedule has no start.
        let startText: String
        /// Local channels first.
        let channels: [TVChannel]

        func isOnAir(now: Date) -> Bool {
            guard let start, let end else { return false }
            return start <= now && now < end
        }

        func isFinished(now: Date) -> Bool {
            guard let end else { return false }
            return end <= now
        }

        /// "2h 14m" until the start; nil when the race has no start or has begun.
        func countdown(now: Date) -> String? {
            start.flatMap { Self.duration(from: now, to: $0) }
        }

        /// "15m" until the end; nil when the race has no end or is over.
        func remaining(now: Date) -> String? {
            end.flatMap { Self.duration(from: now, to: $0) }
        }

        private static func duration(
            from now: Date,
            to date: Date
        ) -> String? {
            let seconds = date.timeIntervalSince(now)
            guard seconds > 0 else { return nil }
            let totalMinutes = max(1, Int(seconds / 60))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            if hours > 0 {
                return minutes > 0
                    ? L10n.tr("%lldh %lldm", hours, minutes)
                    : L10n.tr("%lldh", hours)
            }
            return L10n.tr("%lldm", minutes)
        }
    }

    enum TVRaceStatus: Equatable, Sendable {
        case onAir, next, later, ended
    }

    struct TVDeckCard: Equatable, Identifiable {
        let race: TVRace
        let status: TVRaceStatus
        var id: String { race.id }
    }

    struct TVGuide: Equatable {
        /// Ordered by start.
        let races: [TVRace]

        /// Most relevant first: on air (closest to the finish first), then upcoming by start, finished last.
        /// With a `featured` race id in the guide, that card goes first and the rest keep their order.
        func deck(
            now: Date,
            featured: String? = nil
        ) -> [TVDeckCard] {
            let cards = orderedDeck(now: now)
            guard let featured, let index = cards.firstIndex(where: { $0.id == featured }) else { return cards }
            var reordered = cards
            reordered.insert(reordered.remove(at: index), at: 0)
            return reordered
        }

        private func orderedDeck(now: Date) -> [TVDeckCard] {
            let onAir = races
                .filter { $0.isOnAir(now: now) }
                .sorted { ($0.end ?? .distantFuture) < ($1.end ?? .distantFuture) }
            let upcoming = races.filter { !$0.isOnAir(now: now) && !$0.isFinished(now: now) }
            let finished = races.filter { $0.isFinished(now: now) }
            return onAir.map { TVDeckCard(race: $0, status: .onAir) }
                + upcoming.enumerated().map { TVDeckCard(race: $0.element, status: $0.offset == 0 ? .next : .later) }
                + finished.map { TVDeckCard(race: $0, status: .ended) }
        }
    }

    /// A tab of the day strip, from the site's own day list.
    struct TVDay: Equatable, Identifiable {
        /// "2026-10-27"
        let date: String
        /// 0 is today.
        let offset: Int
        /// "TODAY", "TUE"
        let weekday: String
        let dayNumber: String
        let raceCount: Int
        let isSelected: Bool
        let accessibilityLabel: String
        var id: String { date }
    }

    enum TVState: Equatable {
        case loading
        case failed
        case empty
        case guide(TVGuide)

        /// Stand-ins shaped like the guide, drawn redacted while the page loads.
        static let placeholders = TVGuide(
            races: [
                placeholderRace(id: "p1"),
                placeholderRace(id: "p2"),
                placeholderRace(id: "p3")
            ]
        )

        // l10n:ignore-start
        private static func placeholderRace(id: String) -> TVRace {
            TVRace(
                id: id,
                title: "Loading the race", // l10n:ignore
                meta: "Somewhere, Country",
                discipline: "Road",
                start: nil,
                end: nil,
                startText: "00:00",
                channels: [
                    TVChannel(name: "Channel one", regions: "AA, BB", url: nil, isLocal: false),
                    TVChannel(name: "Channel two", regions: "CC", url: nil, isLocal: false)
                ]
            )
        }

        static let placeholderDays: [TVDay] = (0..<7).map {
            TVDay(
                date: "placeholder-\($0)",
                offset: $0,
                weekday: "DAY",
                dayNumber: "00",
                raceCount: 1,
                isSelected: $0 == 0,
                accessibilityLabel: ""
            )
        }
        // l10n:ignore-end
    }

    /// What the TV chip shows: the day strip and the selected day.
    struct TVScreen: Equatable {
        /// Empty until today's page has loaded.
        let days: [TVDay]
        let isToday: Bool
        /// "Tuesday 27 October" for another day; empty for today.
        let dayTitle: String
        let state: TVState
        /// The race to mark, from "Where to watch" on Race info.
        let featuredRaceID: String?
    }
}

// MARK: - View Action -
extension Tifosi {
    enum Action {
        case didAppear
        case didSelectChannel(Channel)
        case didTapTVChannel(URL)
        case didRetryTV
        case didSelectTVDay(String?)
        case didFeatureRace(raceID: String?, day: String)
    }
}

// MARK: - View State -
extension Tifosi {
    struct ViewState: Equatable {
        let dateLine: String
        let chips: [Representable.Chip]
        let race: String
        let leader: Post?
        let chase: [Post]
        /// The TV chip replaces the feed with the guide.
        let showsTVGuide: Bool
        let tv: TVScreen

        static var idle: ViewState {
            ViewModel<InteractorImpl>.mapToViewState(from: InteractorImpl().domain)
        }
    }

    enum Representable {
        struct Chip: Equatable, Identifiable {
            let channel: Channel
            let title: String
            let isSelected: Bool
            let isEnabled: Bool
            var id: Channel { channel }
        }
    }
}

// MARK: - Cross-tab entry -
extension EnvironmentValues {
    /// Opens the Tifosi TV guide on `day` with `raceID` featured; set by `TabBarView`, called by Race info.
    @Entry var featureRaceOnTV: (_ raceID: String?, _ day: String) -> Void = { _, _ in }
}
