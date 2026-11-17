//
//  RaceAlerts.OpenRequest.swift
//  Tribuneros
//

import Foundation
import Combine

extension RaceAlerts {
    /// What a tapped finish alert carries: enough to find the race it is about.
    struct OpenRequest: Equatable {
        static let slugKey = "raceSlug"
        static let dateKey = "date"
        static let raceKey = "race"

        let slug: String?
        let date: String
        let race: String

        /// Nil unless `identifier` is a race-alert finish id with a date and a race name.
        init?(
            identifier: String,
            userInfo: [AnyHashable: Any]
        ) {
            guard identifier.hasPrefix(Planner.idPrefix),
                  identifier.contains(".\(PlannedAlert.Kind.finish.rawValue)."),
                  let date = userInfo[Self.dateKey] as? String,
                  let race = userInfo[Self.raceKey] as? String
            else { return nil }
            self.date = date
            self.race = race
            slug = userInfo[Self.slugKey] as? String
        }

        init(
            slug: String?,
            date: String,
            race: String
        ) {
            self.slug = slug
            self.date = date
            self.race = race
        }
    }

    /// Hand-off between the notification delegate and `TabBarView`; a tap on a cold launch waits here for the UI.
    @MainActor
    final class OpenRequests: ObservableObject {
        static let shared = OpenRequests()
        @Published var pending: OpenRequest?
    }

    /// The calendar entry for the request (slug + date, else name + date), or a minimal event built from it.
    static func event(
        for request: OpenRequest,
        in calendar: [DTO.CXCalendarEvent]
    ) -> DTO.CXCalendarEvent {
        let match = calendar.first { event in
            guard event.date == request.date else { return false }
            if let slug = request.slug { return event.raceSlug == slug }
            return event.race == request.race
        }
        if let match { return match }
        return .init(
            date: request.date,
            race: request.race,
            raceClass: "",
            flagURL: nil,
            winnerName: "",
            isCancelled: false,
            raceID: nil,
            raceSlug: request.slug,
            raceURL: request.slug.flatMap { URL(string: "https://cyclocross24.com/race/\($0)/") },
            resultsURL: nil,
            videoURL: nil,
            websiteURL: nil,
            raceCountry: nil,
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )
    }

    #if DEBUG
    /// `OPEN_RACE_ALERT=<slug>` (or `openRaceAlert`): a mocked launch opens as if that slug's latest race finish alert was tapped.
    static var debugOpenSlug: String? {
        guard HomeRaces.MockScenario.current != nil else { return nil }
        let value = ProcessInfo.processInfo.environment["OPEN_RACE_ALERT"]
            ?? UserDefaults.standard.string(forKey: "openRaceAlert")
        return value?.isEmpty == false ? value : nil
    }

    /// The most recent calendar race with `slug` dated on or before `now`.
    static func debugRequest(
        slug: String,
        in calendar: [DTO.CXCalendarEvent],
        now: Date = Date()
    ) -> OpenRequest? {
        calendar
            .filter { $0.raceSlug == slug }
            .compactMap { event in event.eventDate.map { (event, $0) } }
            .filter { $0.1 <= now }
            .max { $0.1 < $1.1 }
            .map { OpenRequest(slug: slug, date: $0.0.date, race: $0.0.race) }
    }
    #endif
}
