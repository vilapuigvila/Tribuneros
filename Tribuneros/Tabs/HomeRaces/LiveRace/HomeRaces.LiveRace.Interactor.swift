//
//  HomeRaces.LiveRace.Interactor.swift
//  Tribuneros
//

import Foundation
import Combine

extension HomeRaces.LiveRace {

    /// The hint's stored values, injectable so tests never touch `UserSettings`.
    struct HintStore {
        /// When the hint first showed; `nil` on a fresh install.
        let firstShown: () -> Date?
        /// How many times the hint has shown.
        let count: () -> Int
        /// Records one showing: the first-shown date (kept once set) and the new count.
        let record: (Date, Int) -> Void

        static let userSettings = HintStore(
            firstShown: { UserSettings.liveHintFirstShown },
            count: { UserSettings.liveHintShownCount ?? 0 },
            record: { now, count in
                UserSettings.liveHintFirstShown = UserSettings.liveHintFirstShown ?? now
                UserSettings.liveHintShownCount = count
            }
        )
    }

    /// `refresh()` for callers that can await it, see `ViewModel.refresh()`.
    protocol LiveRefreshing {
        @MainActor func refresh() async
    }

    final class InteractorImpl: InteractorProtocol, LiveRefreshing {
        typealias Domain = HomeRaces.LiveRace.Domain
        typealias UseCase = HomeRaces.LiveRace.UseCase

        private let subject: CurrentValueSubject<Domain, Never>
        /// Fetches and parses the live page; injectable so previews and tests never hit the network.
        private let loadPage: (URL) async -> DTO.LivePage?
        private let now: () -> Date
        /// Waits between two polls; injectable so tests run on a fake clock.
        private let sleep: (TimeInterval) async -> Void
        private let hintStore: HintStore
        /// The running polling window; `nil` when none runs.
        private var window: Task<Void, Never>?
        private var hintEvaluated = false

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        init(
            url: URL?,
            loadPage: @escaping (URL) async -> DTO.LivePage? = {
                await Service.getLivePage(url: $0)
            },
            now: @escaping () -> Date = Date.init,
            sleep: @escaping (TimeInterval) async -> Void = { seconds in
                do {
                    try await Task.sleep(for: .seconds(seconds))
                } catch {}
            },
            hintStore: HintStore = .userSettings
        ) {
            subject = CurrentValueSubject<Domain, Never>(Domain(url: url))
            self.loadPage = loadPage
            self.now = now
            self.sleep = sleep
            self.hintStore = hintStore
        }

        deinit {
            window?.cancel()
        }

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .start:
                if domain.url != nil {
                    evaluateHint()
                }
                guard window == nil else { return }
                startWindow(firstFetchDone: nil)
            case .refresh:
                startWindow(firstFetchDone: nil)
            case .stop:
                window?.cancel()
                window = nil
                mutate { $0.isPolling = false }
            case .dismissHint:
                mutate { $0.showHint = false }
            }
        }

        /// Pull to refresh: restarts the window and returns once its first fetch is applied, so
        /// `.refreshable` keeps its spinner until the page has landed.
        @MainActor
        func refresh() async {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                startWindow(firstFetchDone: { continuation.resume() })
            }
        }

        /// Starts a fresh window, replacing a running one: a fetch at once, then one every
        /// `Polling.interval` for as long as `fitsAnotherPoll` allows. `firstFetchDone` is called
        /// once that first fetch is over, whatever its outcome, so a continuation waiting on it
        /// always resumes.
        private func startWindow(firstFetchDone: (() -> Void)?) {
            window?.cancel()
            window = nil
            guard domain.url != nil else {
                mutate {
                    $0.load = .failed
                    $0.isPolling = false
                }
                firstFetchDone?()
                return
            }
            // Only the window's first fetch shows the loading state: the polls after it keep
            // the page or the failure on screen, so a failing page doesn't flicker every 5 s.
            switch domain.load {
            case .idle, .failed:
                mutate { $0.load = .loading }
            case .loading, .loaded:
                break
            }
            mutate { $0.isPolling = true }
            let clock = now
            let pause = sleep
            let windowStart = clock()
            window = Task { @MainActor [weak self] in
                await self?.poll()
                firstFetchDone?()
                while !Task.isCancelled,
                      InteractorImpl.fitsAnotherPoll(
                          since: windowStart,
                          now: clock()
                      ) {
                    await pause(Polling.interval)
                    guard !Task.isCancelled else { break }
                    await self?.poll()
                }
                // A cancelled window leaves the state to whoever cancelled it (stop or a new window).
                guard !Task.isCancelled else { return }
                self?.mutate { $0.isPolling = false }
                self?.window = nil
            }
        }

        /// Whether another poll still starts inside the window, given that a poll has just landed
        /// at `now`: the next one, `Polling.interval` later, must be before `start + Polling.window`.
        /// With 5 s polls in a 60 s window that gives 12 polls, at 0, 5 … 55 s; the one due at
        /// 60 s never runs. Slow fetches push the later polls back, so they can give fewer.
        static func fitsAnotherPoll(
            since start: Date,
            now: Date
        ) -> Bool {
            now.timeIntervalSince(start) + Polling.interval < Polling.window
        }

        /// One fetch of the live page, applied unless the window was cancelled meanwhile. A failed
        /// fetch keeps the last page; it shows as a failure only when nothing has loaded yet.
        @MainActor
        private func poll() async {
            guard !Task.isCancelled, let url = domain.url else { return }
            let page = await loadPage(url)
            guard !Task.isCancelled else { return }
            let polledAt = now()
            mutate { value in
                if let page {
                    value.load = .loaded(page)
                    value.updatedAt = polledAt
                } else if case .loaded = value.load {
                    // Keep the page on screen.
                } else {
                    value.load = .failed
                }
            }
        }

        /// The hint shows on the first start of a screen with a live page, and again once 48 h
        /// have passed since; each showing is recorded. Evaluated once per interactor, so a second
        /// start of the same screen neither shows it again nor records it.
        private func evaluateHint() {
            guard !hintEvaluated else { return }
            hintEvaluated = true
            let date = now()
            let count = hintStore.count()
            guard Hint.shouldShow(
                now: date,
                firstShown: hintStore.firstShown(),
                count: count
            ) else {
                return
            }
            hintStore.record(date, count + 1)
            mutate { $0.showHint = true }
        }

        private func mutate(_ change: (inout Domain) -> Void) {
            var domain = subject.value
            change(&domain)
            subject.send(domain)
        }
    }
}
