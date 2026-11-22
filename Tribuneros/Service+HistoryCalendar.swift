//
//  Service+HistoryCalendar.swift
//  Tribuneros
//
//  History's fallback when PCS's "Latest race results" list has no road row left (it only covers
//  about two weeks, all cyclocross in the off-season): the season calendar, `races.php?year=<year>`
//  (UCI WorldTour, the page's default circuit), whose finished races carry their winner. Scraped on
//  the device like the rest of PCS (see CLAUDE.md).
//

import Foundation
import SwiftSoup
import Alfy

extension Service {

    /// Finished calendar races before `cutoff`, newest first: this year's calendar, else last year's
    /// (early January, before the first race of the season). `[]` when neither loads or has one.
    static func getSeasonCalendarHistory(
        before cutoff: Date,
        calendar: Calendar
    ) async -> [DTO.TodayResult] {
        let year = calendar.component(.year, from: cutoff)
        for season in [year, year - 1] {
            guard let document = await seasonCalendarDocument(year: season) else { continue }
            let results = parseSeasonCalendarResults(
                document,
                year: season,
                before: cutoff,
                calendar: calendar
            )
            if !results.isEmpty { return results }
        }
        return []
    }

    private static func seasonCalendarDocument(year: Int) async -> Document? {
        do {
            let (data, _) = try await Requester
                .makeRequest(baseStringURL + "races.php?year=\(year)")
                .ttl(.hours(6))
                .cacheControlBehavior(.ignoreServer)
                .send()
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return try SwiftSoup.parse(html)
        } catch {
            if !isOffline(error) {
                nonFatalCrashlytics(false, "History calendar fetch error: \(error.localizedDescription)")
            }
            return nil
        }
    }

    /// `races.php` rows are date ("19.01 - 24.01" or "31.01"), start date, race (flag + link), winner
    /// (`rider/` link, empty until the race is over) and UCI class. A row becomes a result when it has a
    /// winner and its last day is before `cutoff`; the winner is its only podium entry.
    static func parseSeasonCalendarResults(
        _ document: Document,
        year: Int,
        before cutoff: Date,
        calendar: Calendar = .current
    ) -> [DTO.TodayResult] {
        let output = DateFormatter()
        output.calendar = calendar
        output.timeZone = calendar.timeZone
        output.setLocalizedDateFormatFromTemplate("d MMM")

        guard let rows = try? document.select("table.basic > tbody > tr").array() else { return [] }
        var seen = Set<String>()
        let results = rows.compactMap { row -> (end: Date, result: DTO.TodayResult)? in
            guard let cells = try? row.select("td").array(), cells.count >= 5,
                  let raceLink = try? cells[2].select("a[href^=race/]").first(),
                  let href = try? raceLink.attr("href"),
                  let raceName = try? raceLink.text().trimmingCharacters(in: .whitespaces),
                  !raceName.isEmpty,
                  let winnerLink = try? cells[3].select("a[href^=rider/]").first(),
                  let winnerName = try? winnerLink.text().trimmingCharacters(in: .whitespaces),
                  !winnerName.isEmpty,
                  let dateText = try? cells[0].text(),
                  let end = calendarRaceEnd(
                      dateText,
                      year: year,
                      calendar: calendar
                  ),
                  end < cutoff,
                  seen.insert(href).inserted
            else {
                return nil
            }
            let raceClass = ((try? cells[4].text()) ?? "").trimmingCharacters(in: .whitespaces)
            if isCyclocross(raceClass: raceClass, hasRoute: true) { return nil }
            let flagCode = spanFlagCode(in: cells[3])
            let result = DTO.TodayResult(
                raceName: raceClass.isEmpty ? raceName : "\(raceName) (\(raceClass))",
                raceDetails: output.string(from: end),
                raceURL: URL(string: baseStringURL + href),
                winner: nil,
                podium: [
                    DTO.TodayResult.Winner(
                        position: "1",
                        flag: flagCode.flatMap { URL(string: baseStringURL + "images/flags/" + $0 + ".png") },
                        countryCode: flagCode,
                        name: winnerName,
                        team: "",
                        time: ""
                    )
                ],
                additionalDetails: [],
                raceCountryCode: spanFlagCode(in: cells[2])
            )
            return (end, result)
        }
        // Stable newest-first: rows finishing the same day keep the page order.
        let sorted = results.enumerated().sorted {
            $0.element.end != $1.element.end
                ? $0.element.end > $1.element.end
                : $0.offset < $1.offset
        }
        return sorted
            .prefix(historyLimit)
            .map { $0.element.result }
    }

    /// The last day of "19.01 - 24.01" or "31.01" in `year`; a range over New Year ends the next year.
    static func calendarRaceEnd(
        _ text: String,
        year: Int,
        calendar: Calendar
    ) -> Date? {
        let parts = text
            .components(separatedBy: "-")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = parts.first,
              let start = dayMonth(first),
              let end = dayMonth(parts.last ?? first)
        else {
            return nil
        }
        let endYear = (end.month, end.day) < (start.month, start.day) ? year + 1 : year
        return calendar.date(
            from: DateComponents(
                year: endYear,
                month: end.month,
                day: end.day
            )
        )
    }

    private static func dayMonth(_ text: String) -> (day: Int, month: Int)? {
        let numbers = text.split(separator: ".").compactMap { Int($0) }
        guard numbers.count == 2,
              (1...31).contains(numbers[0]),
              (1...12).contains(numbers[1])
        else {
            return nil
        }
        return (numbers[0], numbers[1])
    }
}
