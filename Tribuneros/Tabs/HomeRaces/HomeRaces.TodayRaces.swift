//
//  HomeRaces.TodayRaces.swift
//  Tribuneros
//
//  What the "Today" section and its "Today's races" list show: PCS's "Next to finish" rows,
//  ordered by finish time, each marked LIVE when PCS also lists it under LiveStats.
//

import Foundation

extension HomeRaces.Representable.RaceNext {

    /// PCS writes a stage after the race name as " - S2"; the title is the name without it.
    var title: String {
        stageSplit?.title ?? name
    }

    var stageLabel: String? {
        stageSplit.map { "Stage \($0.stage)" }
    }

    var subtitle: String {
        stageLabel ?? "One-day race"
    }

    /// When the race is expected to finish, today unless PCS still counts hours to go for an
    /// ETA that already passed by a wide margin (a finish after midnight).
    func finishDate(now: Date, calendar: Calendar = .current) -> Date? {
        let parts = eta.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0..<24).contains(hour),
              (0..<60).contains(minute),
              let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)
        else {
            return nil
        }
        let hasTimeToGo = duration.contains(where: \.isNumber)
        let isFarPast = today.timeIntervalSince(now) < -2 * 60 * 60
        if hasTimeToGo && isFarPast {
            return calendar.date(byAdding: .day, value: 1, to: today)
        }
        return today
    }

    /// "2h 14m", "45m", or `nil` when the ETA can't be read or has passed.
    func remainingTimeDescription(now: Date = Date()) -> String? {
        guard let finish = finishDate(now: now) else { return nil }
        let seconds = finish.timeIntervalSince(now)
        guard seconds > 0 else { return nil }

        let totalMinutes = max(1, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    private var stageSplit: (title: String, stage: String)? {
        guard let range = name.range(of: " - S", options: .backwards) else { return nil }
        let stage = name[range.upperBound...]
        guard let first = stage.first,
              first.isNumber,
              stage.allSatisfy({ $0.isNumber || ($0.isLetter && $0.isLowercase) })
        else {
            return nil
        }
        return (String(name[..<range.lowerBound]), String(stage))
    }
}

extension HomeRaces {
    enum TodayRaces {

        static func build(
            nextToFinish: [DTO.NextToFinishResult],
            liveStats: [DTO.LiveStatsRace],
            now: Date = Date(),
            calendar: Calendar = .current
        ) -> [Representable.RaceNext] {
            nextToFinish
                .map { race in
                    Representable.RaceNext(
                        eta: race.eta,
                        duration: race.duration,
                        name: race.name,
                        category: race.category,
                        raceType: race.raceType,
                        distance: race.distance,
                        urlPath: race.urlPath.isEmpty ? nil : race.urlPath,
                        flagCode: race.flagCode,
                        isLive: isLive(race, in: liveStats)
                    )
                }
                .enumerated()
                .sorted { lhs, rhs in
                    let left = lhs.element.finishDate(now: now, calendar: calendar)
                    let right = rhs.element.finishDate(now: now, calendar: calendar)
                    switch (left, right) {
                    case let (left?, right?) where left != right:
                        return left < right
                    case (.some, .none):
                        return true
                    case (.none, .some):
                        return false
                    default:
                        return lhs.offset < rhs.offset
                    }
                }
                .map(\.element)
        }

        /// LiveStats links to the race's `/live` page, so its path is the race path plus `/live`;
        /// the shared title is the fallback when a path is missing.
        static func isLive(_ race: DTO.NextToFinishResult, in liveStats: [DTO.LiveStatsRace]) -> Bool {
            let racePath = relativePath(race.urlPath)
            return liveStats.contains { entry in
                guard entry.isLive else { return false }
                if !racePath.isEmpty, relativePath(entry.racePath) == racePath {
                    return true
                }
                return entry.raceName.caseInsensitiveCompare(race.name) == .orderedSame
            }
        }

        private static func relativePath(_ value: String) -> String {
            var path = value
            if let host = path.range(of: "procyclingstats.com/") {
                path = String(path[host.upperBound...])
            }
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if path.hasSuffix("/live") {
                path = String(path.dropLast("/live".count))
            }
            return path
        }
    }
}
