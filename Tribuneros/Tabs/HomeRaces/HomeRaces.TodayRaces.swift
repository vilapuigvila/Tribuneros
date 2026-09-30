//
//  HomeRaces.TodayRaces.swift
//  Tribuneros
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

    func remainingTimeDescription(now: Date = Date()) -> String? {
        guard let finishDate else { return nil }
        let seconds = finishDate.timeIntervalSince(now)
        guard seconds > 0 else { return nil }

        let totalMinutes = max(1, Int(seconds / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    var accessibilityDescription: String {
        var parts = [
            title,
            subtitle,
            isLive ? "live now" : "later today",
            "expected finish \(eta)"
        ]
        if let remaining = remainingTimeDescription() {
            parts.append("in \(remaining)")
        }
        return parts.joined(separator: ", ")
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
            now: Date = Date()
        ) -> [Representable.RaceNext] {
            nextToFinish
                .enumerated()
                .map { offset, race in
                    (
                        offset: offset,
                        race: Representable.RaceNext(
                            eta: race.eta,
                            duration: race.duration,
                            name: race.name,
                            category: race.category,
                            raceType: race.raceType,
                            distance: race.distance,
                            urlPath: race.urlPath.isEmpty ? nil : race.urlPath,
                            flagCode: race.flagCode,
                            isLive: isLive(race, in: liveStats),
                            finishDate: finishDate(eta: race.eta, duration: race.duration, now: now)
                        )
                    )
                }
                .sorted { lhs, rhs in
                    switch (lhs.race.finishDate, rhs.race.finishDate) {
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
                .map(\.race)
        }

        /// PCS counts hours to go only while the finish is ahead, so an ETA far off the other way is the neighbouring day.
        static func finishDate(eta: String, duration: String, now: Date) -> Date? {
            let calendar = Calendar.current
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
            let untilEta = today.timeIntervalSince(now)
            if hasTimeToGo && untilEta < -2 * 60 * 60 {
                return calendar.date(byAdding: .day, value: 1, to: today)
            }
            if !hasTimeToGo && untilEta > 12 * 60 * 60 {
                return calendar.date(byAdding: .day, value: -1, to: today)
            }
            return today
        }

        /// LiveStats links to the race's `/live` page; the shared title is the fallback when a path is missing.
        static func isLive(_ race: DTO.NextToFinishResult, in liveStats: [DTO.LiveStatsRace]) -> Bool {
            let racePath = relativePath(race.urlPath)
            return liveStats.contains { entry in
                guard entry.isLive else { return false }
                let entryPath = relativePath(entry.racePath)
                if !racePath.isEmpty, !entryPath.isEmpty {
                    return racePath == entryPath
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
