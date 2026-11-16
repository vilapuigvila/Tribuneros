//
//  RaceAlerts.swift
//  Tribuneros
//

import UIKit

/// The series a user follows for race alerts. Stored on the device only; nothing is sent yet.
enum RaceAlerts {
    /// The series that can be followed, in the sheet's order.
    static let series: [CXRaces.RaceSeries] = [
        .worldCup,
        .superprestige,
        .x2oTrofee,
        .otherBelgian
    ]

    static var systemSettingsURL: URL? {
        URL(string: UIApplication.openNotificationSettingsURLString)
    }
}

// MARK: - View Action -
extension RaceAlerts {
    enum Action {
        /// The app came to the foreground, the sheet opened or Settings appeared: iOS permission may have changed.
        case didRequestAuthorizationRefresh
        case didToggle(CXRaces.RaceSeries, isOn: Bool)
        case didTapOpenSystemSettings
        case didLoadCalendar([DTO.CXCalendarEvent])
    }
}

// MARK: - View State -
extension RaceAlerts {
    enum Bell: Equatable {
        case none
        case following(Int)
        case blocked
    }

    struct Row: Equatable, Identifiable {
        let series: CXRaces.RaceSeries
        let title: String
        let subtitle: String
        /// Drawn state of the switch: always off while blocked.
        let isOn: Bool
        let isEnabled: Bool

        var id: String { series.rawValue }
    }

    struct Sheet: Equatable {
        let isBlocked: Bool
        let rows: [Row]
    }

    struct ViewState: Equatable {
        let bell: Bell
        /// Series whose next-round hero shows "ALERT ON"; empty while blocked.
        let alertOnSeries: Set<CXRaces.RaceSeries>
        /// Opened from CX Zone: the rows name each series' next round.
        let cxSheet: Sheet
        /// Opened from Settings, which has no calendar.
        let settingsSheet: Sheet
        let notificationsSubtitle: String
        let raceAlertsSubtitle: String

        static var idle: ViewState {
            ViewModel<InteractorImpl>.mapToViewState(from: Domain())
        }
    }
}
