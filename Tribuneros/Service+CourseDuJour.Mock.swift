//
//  Service+CourseDuJour.Mock.swift
//  Tribuneros
//

#if DEBUG
import Foundation

enum CourseDuJourMock {
    private static var formatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// Today plus seven days, relative to now so the strip is always current; today has two road
    /// races and one gravel race, tomorrow one road race, every other day a single filler race.
    static func page(
        date: String?,
        now: Date = Date()
    ) -> DTO.CourseDuJourPage {
        let calendar = Calendar.current
        let today = formatter.string(from: now)
        let selected = date ?? today
        let days = (0..<8).map { offset -> DTO.CourseDuJourPage.Day in
            let day = calendar.date(
                byAdding: .day,
                value: offset,
                to: now
            ) ?? now
            return DTO.CourseDuJourPage.Day(
                date: formatter.string(from: day),
                offset: offset,
                raceCount: offset == 0 ? 3 : 1
            )
        }
        let offset = days.first { $0.date == selected }?.offset ?? 0
        return DTO.CourseDuJourPage(
            date: selected,
            heading: selected == today ? "Today" : "Day \(offset)",
            updatedAt: now.addingTimeInterval(-3600),
            days: days,
            sections: sections(
                offset: offset,
                now: now
            )
        )
    }

    private static func sections(
        offset: Int,
        now: Date
    ) -> [DTO.CourseDuJourPage.Section] {
        func race(
            _ name: String,
            stage: String? = nil,
            category: String,
            location: String,
            startingIn hours: Double,
            channels: [(String, String)]
        ) -> DTO.CourseDuJourPage.Race {
            DTO.CourseDuJourPage.Race(
                name: name,
                stage: stage,
                category: category,
                location: location,
                start: now.addingTimeInterval(hours * 3600),
                end: now.addingTimeInterval((hours + 3) * 3600),
                broadcasters: channels.map {
                    DTO.CourseDuJourPage.Broadcaster(
                        name: $0.0,
                        regions: $0.1,
                        url: URL(string: "https://www.example.com"),
                        start: nil,
                        end: nil
                    )
                }
            )
        }
        switch offset {
        case 0:
            return [
                DTO.CourseDuJourPage.Section(
                    discipline: "Road",
                    caption: "2 races with live coverage",
                    races: [
                        race(
                            "CRO Race",
                            stage: "Stage 1",
                            category: "2.1 (Men)",
                            location: "Zagreb, Croatia",
                            startingIn: -1,
                            channels: [("Sporza / VRT", "BE")]
                        ),
                        race(
                            "GP de Montréal",
                            category: "1.UWT (Men)",
                            location: "Montréal, Canada",
                            startingIn: 3,
                            channels: [("FloBikes", "CA, US"), ("Eurosport / HBO Max", "FI, SE")]
                        )
                    ]
                ),
                DTO.CourseDuJourPage.Section(
                    discipline: "CX",
                    caption: "no live coverage today",
                    races: []
                ),
                DTO.CourseDuJourPage.Section(
                    discipline: "Gravel",
                    caption: "no live coverage today",
                    races: [
                        race(
                            "Mock Gravel Classic",
                            category: "UCI Gravel Series",
                            location: "Girona, Spain",
                            startingIn: 5,
                            channels: []
                        )
                    ]
                )
            ]
        case 1:
            return [
                DTO.CourseDuJourPage.Section(
                    discipline: "Road",
                    caption: "1 race with live coverage",
                    races: [
                        race(
                            "Coppa Bernocchi",
                            category: "1.Pro (Men)",
                            location: "Legnano, Italy",
                            startingIn: 26,
                            channels: [("RAI Sport", "IT")]
                        )
                    ]
                )
            ]
        default:
            return [
                DTO.CourseDuJourPage.Section(
                    discipline: "Road",
                    caption: "1 race with live coverage",
                    races: [
                        race(
                            "Mock Filler Race \(offset)",
                            category: "1.2 (Men)",
                            location: "Somewhere, Italy",
                            startingIn: Double(24 * offset + 2),
                            channels: [("HBO Max", "US")]
                        )
                    ]
                )
            ]
        }
    }
}
#endif
