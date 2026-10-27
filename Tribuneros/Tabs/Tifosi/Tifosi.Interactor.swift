//
//  Tifosi.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension Tifosi {
    enum TVLoad: Equatable {
        case idle
        case loading
        case loaded(DTO.CourseDuJourPage)
        case failed
    }

    struct Domain: Equatable {
        var filter: Channel = .tv
        var posts: [Post]
        var race: String
        var date: Date
        /// Today's page; its day list feeds the strip.
        var tv: TVLoad = .idle
        /// The day picked in the strip; nil is today.
        var tvDay: String?
        var tvOtherDays: [String: TVLoad] = [:]
        /// The race marked after "Where to watch"; a manual chip or day pick clears it.
        var featuredRaceID: String?

        var tvSelectedLoad: TVLoad {
            tvDay.map { tvOtherDays[$0] ?? .idle } ?? tv
        }

        /// Posts from the selected chip's source.
        var filtered: [Post] {
            posts.filter { $0.channel == filter }
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
        case appear
        case selectChannel(Channel)
        case retryTV
        case selectTVDay(String?)
        case feature(raceID: String?, day: String)
    }

    final class InteractorImpl: InteractorProtocol {
        typealias Domain = Tifosi.Domain
        typealias UseCase = Tifosi.UseCase

        private let subject: CurrentValueSubject<Domain, Never>

        var publisher: AnyPublisher<Domain, Never> { subject.eraseToAnyPublisher() }
        var domain: Domain { subject.value }

        /// Fetches a day (nil is the site's today); injectable so tests never hit the network.
        private let loadPage: (String?) async -> DTO.CourseDuJourPage?
        private var tvTasks: [String: Task<Void, Never>] = [:]

        /// Posts are fixed mock content, whatever `MOCK_SCENARIO` says; only the TV guide loads.
        init(
            date: Date = Date(),
            loadPage: @escaping (String?) async -> DTO.CourseDuJourPage? = {
                await Service.getCourseDuJourPage(date: $0)
            }
        ) {
            self.loadPage = loadPage
            subject = CurrentValueSubject(
                Domain(
                    posts: Mock.posts,
                    race: Mock.race,
                    date: date
                )
            )
        }

        deinit {
            tvTasks.values.forEach { $0.cancel() }
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .appear:
                if subject.value.filter == .tv {
                    loadTV(day: subject.value.tvDay)
                }
            case .selectChannel(let channel):
                guard channel.isAvailable, channel != subject.value.filter else { return }
                var updated = subject.value
                updated.filter = channel
                updated.featuredRaceID = nil
                subject.send(updated)
                if channel == .tv {
                    loadTV(day: updated.tvDay)
                }
            case .retryTV:
                if case .failed = subject.value.tvSelectedLoad {
                    loadTV(day: subject.value.tvDay)
                }
            case .selectTVDay(let date):
                var day = date
                if case .loaded(let today) = subject.value.tv, today.date == date {
                    day = nil
                }
                guard day != subject.value.tvDay else { return }
                mutate {
                    $0.tvDay = day
                    $0.featuredRaceID = nil
                }
                loadTV(day: day)
            case .feature(let raceID, let day):
                var isToday = false
                if case .loaded(let today) = subject.value.tv {
                    isToday = today.date == day
                }
                mutate {
                    $0.filter = .tv
                    $0.tvDay = isToday ? nil : day
                    $0.featuredRaceID = raceID
                }
                // Today's page also feeds the strip, and tells a "today" day string apart from another day.
                loadTV(day: nil)
                if !isToday {
                    loadTV(day: day)
                }
            }
        }

        private func loadTV(day: String?) {
            switch subject.value.tvSelectedLoad {
            case .idle, .failed:
                break
            case .loading, .loaded:
                return
            }
            mutate { Self.set(.loading, day: day, in: &$0) }
            let loadPage = loadPage
            tvTasks[day ?? ""] = Task { @MainActor [weak self] in
                let page = await loadPage(day)
                guard !Task.isCancelled else { return }
                self?.mutate {
                    Self.set(page.map { .loaded($0) } ?? .failed, day: day, in: &$0)
                    if day == nil, let page, $0.tvDay == page.date {
                        $0.tvDay = nil
                    }
                }
            }
        }

        private static func set(
            _ load: TVLoad,
            day: String?,
            in domain: inout Domain
        ) {
            if let day {
                domain.tvOtherDays[day] = load
            } else {
                domain.tv = load
            }
        }

        private func mutate(_ change: (inout Domain) -> Void) {
            var updated = subject.value
            change(&updated)
            subject.send(updated)
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
