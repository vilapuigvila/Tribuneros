//
//  Paddock.Interactor.swift
//  Tribuneros
//
//  Created by albert vila on 28/9/26.
//

import Foundation
import Combine
import Alfy

extension Paddock {

    struct Domain: Equatable {
        struct Event: Equatable {
            enum Kind: Equatable {
                case transfer(DTO.Transfer)
                case programUpdate(DTO.ProgramUpdate)
                case birthdays([DTO.Birthday])
            }

            let date: Date
            let kind: Kind
        }

        var press: [DTO.PressLink]
        var events: [Event]
        var filter: Filter
        var lastUpdated: Date?
        var loading: Bool
        var error: EquatableError?

        static let empty = Domain(
            press: [],
            events: [],
            filter: .all,
            lastUpdated: nil,
            loading: false,
            error: nil
        )
    }

    enum UseCase: Sendable {
        case request
        case selectFilter(Filter)
    }
}

extension Paddock {
    final class InteractorImpl: InteractorProtocol {
        typealias Domain = Paddock.Domain
        typealias UseCase = Paddock.UseCase

        private let subject = CurrentValueSubject<Domain, Never>(.empty)

        var publisher: AnyPublisher<Domain, Never> {
            subject.eraseToAnyPublisher()
        }
        var domain: Domain { subject.value }

        private var pressTask: Task<Void, Never>?
        private var feedTask: Task<Void, Never>?

        func useCase(_ useCase: UseCase) {
            switch useCase {
            case .request:
                requestPress()
                requestFeed()
            case .selectFilter(let filter):
                mutate { $0.filter = filter }
            }
        }

        private func requestPress() {
            guard pressTask == nil else { return }
            pressTask = Task { @MainActor [weak self] in
                let links = await Service.getPressLinks()
                self?.mutate { $0.press = links }
                self?.pressTask = nil
            }
        }

        private func requestFeed() {
            guard feedTask == nil else { return }
            mutate {
                $0.loading = true
                $0.error = nil
            }
            feedTask = Task { @MainActor [weak self] in
                defer { self?.feedTask = nil }
                do {
                    let paddock = try await Service.getPaddock()
                    let now = Date()
                    let events = Self.events(
                        from: paddock,
                        fetchedAt: now
                    )
                    nonFatalCrashlytics(!events.isEmpty, "PCS homepage: every Paddock section parsed empty")
                    self?.mutate {
                        $0.events = events
                        $0.lastUpdated = now
                        $0.loading = false
                    }
                } catch {
                    if !Service.isOffline(error) {
                        nonFatalCrashlytics(false, error.localizedDescription)
                    }
                    self?.mutate {
                        $0.loading = false
                        $0.error = error.toEquatableError()
                    }
                }
            }
        }

        private func mutate(_ change: (inout Domain) -> Void) {
            var copy = subject.value
            change(&copy)
            subject.send(copy)
        }

        static func events(
            from paddock: DTO.Paddock,
            fetchedAt now: Date,
            calendar: Calendar = .current
        ) -> [Domain.Event] {
            var events: [Domain.Event] = []
            if !paddock.birthdays.isEmpty {
                events.append(
                    .init(
                        date: now,
                        kind: .birthdays(paddock.birthdays)
                    )
                )
            }
            for update in paddock.programUpdates {
                let date = Self.date(
                    fromTimeAgo: update.timeAgo,
                    relativeTo: now
                )
                nonFatalCrashlytics(date != nil, "Unexpected PCS program update time: \(update.timeAgo)")
                events.append(
                    .init(
                        date: date ?? .distantPast,
                        kind: .programUpdate(update)
                    )
                )
            }
            for transfer in paddock.transfers {
                let date = Self.date(
                    fromDayMonth: transfer.date,
                    relativeTo: now,
                    calendar: calendar
                )
                nonFatalCrashlytics(date != nil, "Unexpected PCS transfer date: \(transfer.date)")
                events.append(
                    .init(
                        date: date ?? .distantPast,
                        kind: .transfer(transfer)
                    )
                )
            }
            return events
        }

        static func date(fromTimeAgo value: String, relativeTo now: Date) -> Date? {
            guard let unit = value.last,
                  let amount = Double(value.dropLast())
            else {
                return nil
            }
            switch unit {
            case "m": return now.addingTimeInterval(-amount * 60)
            case "h": return now.addingTimeInterval(-amount * 60 * 60)
            case "d": return now.addingTimeInterval(-amount * 24 * 60 * 60)
            default: return nil
            }
        }

        static func date(
            fromDayMonth value: String,
            relativeTo now: Date,
            calendar: Calendar
        ) -> Date? {
            let parts = value.split(separator: "/").compactMap { Int($0) }
            guard parts.count == 2 else {
                return nil
            }
            var components = calendar.dateComponents([.year], from: now)
            components.day = parts[0]
            components.month = parts[1]
            guard let date = calendar.date(from: components) else {
                return nil
            }
            // PCS omits the year: a date ahead of now is from last year (a December transfer read in January).
            return date > now ? calendar.date(byAdding: .year, value: -1, to: date) : date
        }
    }
}
