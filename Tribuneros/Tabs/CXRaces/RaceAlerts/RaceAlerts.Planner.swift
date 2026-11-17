//
//  RaceAlerts.Planner.swift
//  Tribuneros
//

import Foundation

extension RaceAlerts {
    struct PlannedAlert: Equatable {
        enum Kind: String { case start, finish }
        let id: String
        let kind: Kind
        let fireDate: Date
        let title: String
        let body: String
        /// Delivered with the notification; only finish alerts carry the race to open.
        var userInfo: [String: String] = [:]
    }

    protocol NotificationScheduling {
        func pendingIdentifiers() async -> [String]
        func remove(identifiers: [String])
        func add(_ alerts: [PlannedAlert]) async
        func requestAuthorization() async -> Bool
    }

    /// Plans the local notifications of the followed series; pure, so tests never touch iOS.
    enum Planner {
        static let idPrefix = "raceAlert."
        static let fallbackLastStart = "15:00"

        static func alerts(
            followed: Set<CXRaces.RaceSeries>,
            calendar: [DTO.CXCalendarEvent],
            schedules: [DTO.CXSchedules.Entry],
            now: Date,
            pending: Set<String> = [],
            limit: Int = 64
        ) -> [PlannedAlert] {
            var candidates: [PlannedAlert] = []
            for event in calendar where !event.isCancelled {
                let series = CXRaces.RaceSeries.of(
                    race: event.race,
                    raceClass: event.raceClass,
                    country: event.raceCountry
                )
                guard followed.contains(series), RaceAlerts.series.contains(series) else { continue }
                candidates += alerts(
                    for: event,
                    series: series,
                    schedules: schedules,
                    now: now,
                    pending: pending
                )
            }
            return Array(
                candidates
                    .sorted { ($0.fireDate, $0.id) < ($1.fireDate, $1.id) }
                    .prefix(limit)
            )
        }

        private static func alerts(
            for event: DTO.CXCalendarEvent,
            series: CXRaces.RaceSeries,
            schedules: [DTO.CXSchedules.Entry],
            now: Date,
            pending: Set<String>
        ) -> [PlannedAlert] {
            let parts = event.date.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return [] }
            var venue = Calendar(identifier: .gregorian)
            venue.timeZone = CXRaces.SeriesLens.venueTimeZone(country: event.raceCountry)
            guard let dayStart = venue.date(
                from: DateComponents(
                    year: parts[2],
                    month: parts[1],
                    day: parts[0]
                )
            ), dayStart >= venue.startOfDay(for: now)
            else { return [] }

            let slug = event.raceSlug ?? event.race
            let idSlug = event.raceSlug ?? event.race
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            let isoDay = String(format: "%04d-%02d-%02d", parts[2], parts[1], parts[0])
            let flag = flagEmoji(country: event.raceCountry)
            let name = flag.map { "\($0) \(event.race)" } ?? event.race
            var result: [PlannedAlert] = []

            var rng = SeededGenerator(seed: "\(slug)|\(event.date)|start")
            let minute = Int(rng.next() % 120)
            let startFire = dayStart.addingTimeInterval(TimeInterval(9 * 3600 + minute * 60))
            let cutoff = dayStart.addingTimeInterval(TimeInterval(10 * 3600 + 55 * 60))
            let startID = "\(idPrefix)\(series.rawValue).start.\(idSlug).\(isoDay)"
            // The cutoffs only stop new alerts: one already pending stays until it fires.
            if now <= cutoff || pending.contains(startID), startFire > now {
                let isWomen = rng.next() % 2 == 0
                result.append(
                    PlannedAlert(
                        id: startID,
                        kind: .start,
                        fireDate: startFire,
                        title: name,
                        body: isWomen
                            ? L10n.tr("Women’s elite starts soon - stay tuned 👀")
                            : L10n.tr("Men’s elite starts soon - stay tuned 👀")
                    )
                )
            }

            let lastStart = dayStart.addingTimeInterval(
                TimeInterval(lastStartMinutes(for: event, schedules: schedules) * 60)
            )
            let finishID = "\(idPrefix)\(series.rawValue).finish.\(idSlug).\(isoDay)"
            let finishFire = lastStart.addingTimeInterval(75 * 60)
            if now <= lastStart.addingTimeInterval(60 * 60) || pending.contains(finishID), finishFire > now {
                var finishRng = SeededGenerator(seed: "\(slug)|\(event.date)|finish")
                let isWomen = finishRng.next() % 2 == 0
                result.append(
                    PlannedAlert(
                        id: finishID,
                        kind: .finish,
                        fireDate: finishFire,
                        title: "\(name) 🏁🏁🏁",
                        body: isWomen
                            ? L10n.tr("Women’s elite finished - see the results 🏆🏆🏆")
                            : L10n.tr("Men’s elite finished - see the results 🏆🏆🏆"),
                        userInfo: finishUserInfo(for: event)
                    )
                )
            }
            return result
        }

        private static func finishUserInfo(for event: DTO.CXCalendarEvent) -> [String: String] {
            var info = [
                OpenRequest.dateKey: event.date,
                OpenRequest.raceKey: event.race
            ]
            info[OpenRequest.slugKey] = event.raceSlug
            return info
        }

        /// The series in a `raceAlert.<series>.<kind>.<slug>.<date>` id; nil for other or older ids.
        static func series(ofID id: String) -> CXRaces.RaceSeries? {
            guard id.hasPrefix(idPrefix) else { return nil }
            let component = id.dropFirst(idPrefix.count).split(separator: ".").first.map(String.init)
            return component.flatMap(CXRaces.RaceSeries.init(rawValue:))
        }

        /// Minutes after midnight of the latest row on the race day; 15:00 without an entry or rows.
        private static func lastStartMinutes(
            for event: DTO.CXCalendarEvent,
            schedules: [DTO.CXSchedules.Entry]
        ) -> Int {
            let rows = CXRaces.scheduleEntry(
                for: event,
                in: schedules
            )?.filter { $0.date == nil || $0.date == event.date } ?? []
            let times = rows.compactMap { minutes(of: $0.time) }
            return times.max() ?? minutes(of: fallbackLastStart) ?? 15 * 60
        }

        private static func minutes(of time: String) -> Int? {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return parts[0] * 60 + parts[1]
        }

        private static let regionsByName: [String: String] = {
            let english = Locale(identifier: "en_US")
            var map: [String: String] = [
                "great britain": "GB",
                "usa": "US"
            ]
            for region in Locale.Region.isoRegions {
                let code = region.identifier
                guard code.count == 2,
                      let name = english.localizedString(forRegionCode: code) else { continue }
                map[name.lowercased()] = code
            }
            return map
        }()

        static func flagEmoji(country: String?) -> String? {
            guard let country,
                  let code = regionsByName[country.lowercased().trimmingCharacters(in: .whitespaces)]
            else { return nil }
            let base: UInt32 = 0x1F1E6 - 65
            let scalars = code.unicodeScalars.compactMap { Unicode.Scalar(base + $0.value) }
            return scalars.count == 2 ? String(String.UnicodeScalarView(scalars)) : nil
        }
    }

    /// FNV-1a of the seed text feeding SplitMix64: stable across launches, unlike `Hasher`.
    struct SeededGenerator {
        private var state: UInt64

        init(seed: String) {
            var hash: UInt64 = 0xcbf29ce484222325
            for byte in seed.utf8 {
                hash = (hash ^ UInt64(byte)) &* 0x100000001b3
            }
            state = hash
        }

        mutating func next() -> UInt64 {
            state &+= 0x9e3779b97f4a7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
            z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
            return z ^ (z >> 31)
        }
    }
}
