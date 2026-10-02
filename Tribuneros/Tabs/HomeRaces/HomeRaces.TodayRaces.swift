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
        stageSplit.map { HomeRaces.Stage.label($0.stage) }
    }

    var subtitle: String {
        stageLabel ?? HomeRaces.Stage.oneDayLabel
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
            isLive ? "live now" : "later today"
        ]
        if let startTime {
            parts.append("started at \(startTime)")
        }
        parts.append("expected finish \(eta)")
        if let remaining = remainingTimeDescription() {
            parts.append("in \(remaining)")
        }
        return parts.joined(separator: ", ")
    }

    private var stageSplit: (title: String, stage: String)? {
        HomeRaces.Stage.split(name: name)
    }
}

extension HomeRaces {
    /// How PCS names a stage: a number with an optional lowercase letter ("3", "2b"). Shared by
    /// Today Races (the " - S2" name suffix) and the race result screen (the "Stage 2b | …"
    /// details line and the `stage-2b` URL).
    enum Stage {
        static let oneDayLabel = "One-day race"

        static func label(_ stage: String) -> String {
            "Stage \(stage)"
        }

        /// "Tour of Turkey - S2" → ("Tour of Turkey", "2").
        static func split(name: String) -> (title: String, stage: String)? {
            guard let range = name.range(of: " - S", options: .backwards) else { return nil }
            let stage = name[range.upperBound...]
            guard isStageNumber(stage) else { return nil }
            return (String(name[..<range.lowerBound]), String(stage))
        }

        /// "Stage 2a (ITT) | Wulpen - Wulpen (6km)" → "2a".
        static func number(inDetails details: String) -> String? {
            let lead = details
                .split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            guard lead.hasPrefix("Stage ") else { return nil }
            let token = lead.dropFirst("Stage ".count).split(separator: " ").first ?? ""
            return isStageNumber(token) ? String(token) : nil
        }

        /// ".../2026/stage-2b" → "2b".
        static func number(inURL url: URL?) -> String? {
            guard let last = url?.lastPathComponent, last.hasPrefix("stage-") else { return nil }
            let token = last.dropFirst("stage-".count)
            return isStageNumber(token) ? String(token) : nil
        }

        static func isStageNumber<S: StringProtocol>(_ value: S) -> Bool {
            guard let first = value.first, first.isNumber else { return false }
            return value.allSatisfy { $0.isNumber || ($0.isLetter && $0.isLowercase) }
        }
    }
}

extension HomeRaces {
    enum TodayRaces {

        /// PCS writes a race page's start time as local time, then site time: "08:00  (16:00 CET)".
        /// The homepage ETAs are in site time, so that's the one to show; a lone time is used as is.
        static func siteStartTime(_ raw: String) -> String? {
            let pattern = "([0-9]{1,2}:[0-9]{2})"
            if let cet = raw.range(of: "\\(\\s*" + pattern + "\\s*CES?T\\s*\\)", options: .regularExpression),
               let time = raw[cet].range(of: pattern, options: .regularExpression) {
                return String(raw[cet][time])
            }
            return raw.range(of: pattern, options: .regularExpression).map { String(raw[$0]) }
        }

        static func build(
            nextToFinish: [DTO.NextToFinishResult],
            liveStats: [DTO.LiveStatsRace],
            startTimes: [String: String] = [:],
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
                            finishDate: finishDate(eta: race.eta, duration: race.duration, now: now),
                            startTime: startTimes[race.urlPath]
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
