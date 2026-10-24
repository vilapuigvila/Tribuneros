//
//  Tifosi.swift
//  Tribuneros
//

import Foundation

enum Tifosi { }

// MARK: - Model -
extension Tifosi {
    /// Where a post comes from; the first six cases are filter chips, `.reddit` only shows under Everything.
    enum Channel: String, CaseIterable, Equatable, Sendable {
        case everything, tv, radio, x, bluesky, instagram, reddit

        static var chips: [Channel] { [.everything, .tv, .radio, .x, .bluesky, .instagram] }

        var title: String {
            switch self {
            case .everything: L10n.tr("Everything")
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

// MARK: - View Action -
extension Tifosi {
    enum Action {
        case didSelectChannel(Channel)
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

        static var idle: ViewState {
            ViewModel<InteractorImpl>.mapToViewState(from: InteractorImpl().domain)
        }
    }

    enum Representable {
        struct Chip: Equatable, Identifiable {
            let channel: Channel
            let title: String
            let isSelected: Bool
            var id: Channel { channel }
        }
    }
}
