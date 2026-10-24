//
//  Tifosi.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension Tifosi {
    struct Domain: Equatable {
        var filter: Channel = .everything
        var posts: [Post]
        var race: String
        var date: Date

        /// Posts the filter lets through; Everything shows all, a chip matches the post's source.
        var filtered: [Post] {
            filter == .everything ? posts : posts.filter { $0.channel == filter }
        }

        /// The most-shared post: the first filtered one that carries like counts.
        var leader: Post? {
            filtered.first { $0.likes != nil }
        }

        var chase: [Post] {
            let leaderID = leader?.id
            return filtered.filter { $0.id != leaderID }
        }
    }

    enum UseCase: Sendable {
        case selectChannel(Channel)
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = Tifosi.Domain
        typealias UseCase = Tifosi.UseCase

        private let subject: CurrentValueSubject<Domain, Never>

        var publisher: AnyPublisher<Domain, Never> { subject.eraseToAnyPublisher() }
        var domain: Domain { subject.value }

        /// Fixed mock content, whatever `MOCK_SCENARIO` says; no networking yet.
        init(date: Date = Date()) {
            subject = CurrentValueSubject(
                Domain(
                    posts: Mock.posts,
                    race: Mock.race,
                    date: date
                )
            )
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .selectChannel(let channel):
                guard channel != subject.value.filter else { return }
                var updated = subject.value
                updated.filter = channel
                subject.send(updated)
            }
        }
    }
}

// MARK: - Mock -
extension Tifosi {
    // l10n:ignore-start
    enum Mock {
        static let race = "[race]"

        static let posts: [Post] = [
            Post(
                id: "leader",
                channel: .bluesky,
                kind: .post,
                initials: "GG",
                handle: "@grupetto_gossip",
                source: "Bluesky",
                age: "1h",
                text: "Team bus spotted parked across three disabled spots at the start village. The soigneur is now negotiating with a traffic warden in four languages.", // l10n:ignore
                shares: "2.4k",
                likes: "9.1k",
                isStale: false
            ),
            Post(
                id: "radio",
                channel: .radio,
                kind: .radio,
                initials: "RR",
                handle: "Race radio",
                source: "Radio",
                age: "+0:12",
                text: "“Chute, chute in the bunch at 31 km. Everyone is back on the bike.”", // l10n:ignore
                shares: nil,
                likes: nil,
                isStale: false
            ),
            Post(
                id: "bidon",
                channel: .instagram,
                kind: .post,
                initials: "BH",
                handle: "@bidon_hunter",
                source: "Instagram",
                age: "+0:42",
                text: "Caught a bidon at km 112. Still sticky. Framing it anyway.", // l10n:ignore
                shares: nil,
                likes: nil,
                isStale: false
            ),
            Post(
                id: "tv",
                channel: .tv,
                kind: .tv,
                initials: "TV",
                handle: "[TV CHANNEL]",
                source: "TV",
                age: "+1:30",
                text: "Highlights: the last 10 km of yesterday’s stage, 4 min.", // l10n:ignore
                shares: nil,
                likes: nil,
                isStale: false
            ),
            Post(
                id: "reddit",
                channel: .reddit,
                kind: .post,
                initials: "FF",
                handle: "u/flandrien_forever",
                source: "r/peloton",
                age: "+3:15",
                text: "Unpopular opinion: the gravel sector was too short and I want my money back (it was free).", // l10n:ignore
                shares: nil,
                likes: nil,
                isStale: false
            ),
            Post(
                id: "stale",
                channel: .x,
                kind: .post,
                initials: "TM",
                handle: "@team_[NAME]",
                source: "X",
                age: "+18:07",
                text: "Yesterday’s stage recap is live! Link in bio.", // l10n:ignore
                shares: nil,
                likes: nil,
                isStale: true
            )
        ]
    }
    // l10n:ignore-end
}
