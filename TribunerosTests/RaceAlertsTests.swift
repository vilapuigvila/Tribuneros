//
//  RaceAlertsTests.swift
//  TribunerosTests
//

import XCTest
import UserNotifications
@testable import Tribuneros

final class RaceAlertsTests: XCTestCase {
    private typealias VM = RaceAlerts.ViewModel<RaceAlerts.InteractorImpl>
    private typealias Hint = RaceAlerts.Hint

    private let now = Date()

    override func setUp() {
        super.setUp()
        L10n.setLanguage("en")
    }

    func testAlertSoundShipsInTheAppBundle() {
        let name = RaceAlerts.UserNotificationScheduler.soundFileName as NSString
        XCTAssertNotNil(
            Bundle.main.url(
                forResource: name.deletingPathExtension,
                withExtension: name.pathExtension
            )
        )
    }

    // MARK: - Fixtures -

    private final class HintBox {
        var state: RaceAlerts.HintState?
        var store: Hint.Store {
            Hint.Store(
                load: { self.state },
                save: { self.state = $0 }
            )
        }
    }

    private func makeInteractor(
        stored: [String]? = [],
        authorization: RaceAlerts.Authorization = .allowed,
        saved: @escaping ([String]) -> Void = { _ in }
    ) -> RaceAlerts.InteractorImpl {
        RaceAlerts.InteractorImpl(
            store: RaceAlerts.Store(
                loadFollowed: { stored },
                saveFollowed: saved,
                authorization: { authorization },
                loadCalendar: { [] },
                loadSchedules: { [] },
                scheduler: FakeScheduler()
            )
        )
    }

    private func event(
        daysFromNow days: Int,
        race: String,
        raceClass: String = "C1",
        isCancelled: Bool = false
    ) -> DTO.CXCalendarEvent {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let date = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: now
        )!
        return .init(
            date: formatter.string(from: date),
            race: race,
            raceClass: raceClass,
            flagURL: nil,
            winnerName: "",
            isCancelled: isCancelled,
            raceID: nil,
            raceSlug: nil,
            raceURL: nil,
            resultsURL: nil,
            videoURL: nil,
            websiteURL: nil,
            raceCountry: "Belgium",
            winnerURL: nil,
            winnerCountry: nil,
            winnerFlagURL: nil
        )
    }

    private func state(
        followed: Set<CXRaces.RaceSeries> = [],
        authorization: RaceAlerts.Authorization = .allowed,
        calendar: [DTO.CXCalendarEvent] = []
    ) -> RaceAlerts.ViewState {
        VM.mapToViewState(
            from: RaceAlerts.Domain(
                followed: followed,
                authorization: authorization,
                calendar: calendar
            ),
            now: now
        )
    }

    // MARK: - Hint -

    func testFreshInstallHintWaitsForTheSecondLaunch() {
        let box = HintBox()
        XCTAssertEqual(
            Hint.recordLaunch(
                store: box.store,
                isFreshInstall: true,
                isEnabled: true
            ),
            .waiting
        )
        XCTAssertFalse(Hint.isDueThisLaunch)
        XCTAssertFalse(Hint.present(store: box.store, isEnabled: true))

        // The second launch still looks fresh to the onboarding check (mocked launches never record it).
        XCTAssertEqual(
            Hint.recordLaunch(
                store: box.store,
                isFreshInstall: true,
                isEnabled: true
            ),
            .due
        )
        XCTAssertTrue(Hint.isDueThisLaunch)
        XCTAssertTrue(Hint.present(store: box.store, isEnabled: true))
        XCTAssertEqual(box.state, .shown)
    }

    func testExistingInstallHintIsDueAtOnce() {
        let box = HintBox()
        XCTAssertEqual(
            Hint.recordLaunch(
                store: box.store,
                isFreshInstall: false,
                isEnabled: true
            ),
            .due
        )
        XCTAssertTrue(Hint.isDueThisLaunch)
        XCTAssertTrue(Hint.present(store: box.store, isEnabled: true))
    }

    func testHintNeverShowsAgainOnceShown() {
        let box = HintBox()
        box.state = .shown
        for isFresh in [true, false] {
            XCTAssertEqual(
                Hint.recordLaunch(
                    store: box.store,
                    isFreshInstall: isFresh,
                    isEnabled: true
                ),
                .shown
            )
            XCTAssertFalse(Hint.isDueThisLaunch)
            XCTAssertFalse(Hint.present(store: box.store, isEnabled: true))
        }
    }

    func testHintStaysDueUntilItAppears() {
        let box = HintBox()
        box.state = .due
        Hint.recordLaunch(
            store: box.store,
            isFreshInstall: false,
            isEnabled: true
        )
        XCTAssertEqual(box.state, .due)
        XCTAssertTrue(Hint.present(store: box.store, isEnabled: true))
        XCTAssertFalse(Hint.present(store: box.store, isEnabled: true))
    }

    func testMockedLaunchHidesTheHintUnlessTheFlagIsOn() {
        XCTAssertTrue(Hint.isEnabled(isMockedLaunch: false, isFlagOn: false))
        XCTAssertFalse(Hint.isEnabled(isMockedLaunch: true, isFlagOn: false))
        XCTAssertTrue(Hint.isEnabled(isMockedLaunch: true, isFlagOn: true))

        let box = HintBox()
        box.state = .due
        XCTAssertFalse(Hint.present(store: box.store, isEnabled: false))
        XCTAssertEqual(box.state, .due)
        Hint.recordLaunch(
            store: box.store,
            isFreshInstall: false,
            isEnabled: false
        )
        XCTAssertFalse(Hint.isDueThisLaunch)
    }

    func testHintStateRoundTripsThroughUserSettings() {
        let key = UserPreferencesKey.raceAlertsHint.rawValue
        let previous = UserDefaults.standard.data(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertNil(UserSettings.raceAlertsHint)
        UserSettings.raceAlertsHint = .waiting
        XCTAssertEqual(UserSettings.raceAlertsHint, .waiting)
    }

    // MARK: - Following -

    func testSwitchingASeriesOnAndOffSavesIt() {
        var saved: [[String]] = []
        let interactor = makeInteractor { saved.append($0) }
        interactor.useCase(.setFollowing(.superprestige, true))
        interactor.useCase(.setFollowing(.worldCup, true))
        interactor.useCase(.setFollowing(.worldCup, true))
        interactor.useCase(.setFollowing(.superprestige, false))
        XCTAssertEqual(interactor.domain.followed, [.worldCup])
        XCTAssertEqual(
            saved,
            [
                ["superprestige"],
                ["worldCup", "superprestige"],
                ["worldCup"]
            ]
        )
    }

    func testOnlyTheFourSeriesCanBeFollowed() {
        var saved: [[String]] = []
        let interactor = makeInteractor(stored: ["exactCross", "otherBelgian", "nonsense"]) { saved.append($0) }
        XCTAssertEqual(interactor.domain.followed, [.otherBelgian])
        interactor.useCase(.setFollowing(.championships, true))
        XCTAssertEqual(interactor.domain.followed, [.otherBelgian])
        XCTAssertTrue(saved.isEmpty)
    }

    func testFollowedSeriesPersistThroughUserSettingsKey() {
        let key = UserPreferencesKey.raceAlertSeries.rawValue
        let previous = UserDefaults.standard.data(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(UserSettings.raceAlertSeries, [])

        RaceAlerts.InteractorImpl().useCase(.setFollowing(.worldCup, true))
        XCTAssertEqual(UserSettings.raceAlertSeries, ["worldCup"])
        XCTAssertEqual(RaceAlerts.InteractorImpl().domain.followed, [.worldCup])

        RaceAlerts.InteractorImpl().useCase(.setFollowing(.worldCup, false))
        XCTAssertEqual(UserSettings.raceAlertSeries, [])
    }

    @MainActor
    func testAuthorizationIsReadFromTheStore() async {
        let interactor = makeInteractor(authorization: .blocked)
        XCTAssertEqual(interactor.domain.authorization, .notDetermined)
        await interactor.refreshAuthorization()
        XCTAssertEqual(interactor.domain.authorization, .blocked)
    }

    func testAuthorizationFromIOSStatus() {
        XCTAssertEqual(RaceAlerts.Authorization(.denied), .blocked)
        XCTAssertEqual(RaceAlerts.Authorization(.notDetermined), .notDetermined)
        for status in [UNAuthorizationStatus.authorized, .provisional, .ephemeral] {
            XCTAssertEqual(RaceAlerts.Authorization(status), .allowed)
        }
    }

    func testMockedLaunchReportsAllowedUnlessBlocked() {
        XCTAssertNil(
            RaceAlerts.Authorization.mocked(
                isMockedLaunch: false,
                environment: ["NOTIFICATIONS_STATUS": "blocked"],
                launchValue: nil
            )
        )
        XCTAssertEqual(
            RaceAlerts.Authorization.mocked(
                isMockedLaunch: true,
                environment: [:],
                launchValue: nil
            ),
            .allowed
        )
        XCTAssertEqual(
            RaceAlerts.Authorization.mocked(
                isMockedLaunch: true,
                environment: [:],
                launchValue: "blocked"
            ),
            .blocked
        )
        XCTAssertEqual(
            RaceAlerts.Authorization.mocked(
                isMockedLaunch: true,
                environment: ["NOTIFICATIONS_STATUS": "blocked"],
                launchValue: nil
            ),
            .blocked
        )
    }

    // MARK: - Bell -

    func testBellStates() {
        XCTAssertEqual(state().bell, .none)
        XCTAssertEqual(state(followed: [.worldCup, .x2oTrofee]).bell, .following(2))
        XCTAssertEqual(
            state(
                followed: [.worldCup],
                authorization: .blocked
            ).bell,
            .blocked
        )
        XCTAssertEqual(state(authorization: .notDetermined).bell, .none)
    }

    func testAlertOnTagFollowsTheSeriesUnlessBlocked() {
        XCTAssertEqual(state(followed: [.worldCup]).alertOnSeries, [.worldCup])
        XCTAssertTrue(
            state(
                followed: [.worldCup],
                authorization: .blocked
            ).alertOnSeries.isEmpty
        )
    }

    // MARK: - Sheet -

    func testSheetRowsWhenAllowed() {
        let calendar = [
            event(daysFromNow: -3, race: "World Cup Zonhoven", raceClass: "CDM"),
            event(daysFromNow: 4, race: "World Cup Namur", raceClass: "CDM"),
            event(daysFromNow: 9, race: "World Cup Hoogerheide", raceClass: "CDM")
        ]
        let viewState = state(
            followed: [.worldCup, .superprestige],
            calendar: calendar
        )
        let sheet = viewState.cxSheet
        XCTAssertFalse(sheet.isBlocked)
        XCTAssertEqual(sheet.rows.map(\.series), [.worldCup, .superprestige, .x2oTrofee, .otherBelgian])
        XCTAssertEqual(sheet.rows.map(\.title), ["World Cup", "Superprestige", "X2O Trofee", "Other Belgian"])
        XCTAssertEqual(sheet.rows.map(\.isOn), [true, true, false, false])
        XCTAssertTrue(sheet.rows.allSatisfy(\.isEnabled))

        let date = Calendar.current.date(byAdding: .day, value: 4, to: now)!
        let day = L10n.dateFormatter(template: "dMMM").string(from: date)
        XCTAssertEqual(sheet.rows[0].subtitle, "On · next: Namur, \(day)")
        // No Superprestige round in the calendar: plain "On".
        XCTAssertEqual(sheet.rows[1].subtitle, "On")
        XCTAssertEqual(sheet.rows[2].subtitle, "Off")

        // Settings has no calendar: always plain.
        XCTAssertEqual(viewState.settingsSheet.rows.map(\.subtitle), ["On", "On", "Off", "Off"])
    }

    func testSheetRowsWhenBlockedKeepTheStoredChoice() {
        var saved: [[String]] = []
        let interactor = makeInteractor(stored: ["worldCup"]) { saved.append($0) }
        var domain = interactor.domain
        domain.authorization = .blocked
        let sheet = VM.mapToViewState(from: domain).cxSheet
        XCTAssertTrue(sheet.isBlocked)
        XCTAssertEqual(sheet.rows.count, 4)
        XCTAssertTrue(sheet.rows.allSatisfy { !$0.isOn && !$0.isEnabled })
        XCTAssertTrue(sheet.rows.allSatisfy { $0.subtitle == "Needs notifications in iOS" })
        XCTAssertEqual(interactor.domain.followed, [.worldCup])
        XCTAssertTrue(saved.isEmpty)
    }

    func testVenueDropsTheSeriesName() {
        XCTAssertEqual(RaceAlerts.venue(of: "World Cup Namur"), "Namur")
        XCTAssertEqual(RaceAlerts.venue(of: "UCI World Cup - Benidorm"), "Benidorm")
        XCTAssertEqual(RaceAlerts.venue(of: "Superprestige Niel"), "Niel")
        XCTAssertEqual(RaceAlerts.venue(of: "X2O Badkamers Trofee Baal"), "Baal")
        XCTAssertEqual(RaceAlerts.venue(of: "Kleeberg Cross Mechelen"), "Kleeberg Cross Mechelen")
        XCTAssertEqual(RaceAlerts.venue(of: "Superprestige"), "Superprestige")
    }

    // MARK: - Settings tiles -

    func testSettingsTileSubtitles() {
        XCTAssertEqual(state(authorization: .allowed).notificationsSubtitle, "On in iOS")
        XCTAssertEqual(state(authorization: .blocked).notificationsSubtitle, "Off in iOS")
        XCTAssertEqual(state(authorization: .notDetermined).notificationsSubtitle, "Off in iOS")

        XCTAssertEqual(state().raceAlertsSubtitle, "Off")
        XCTAssertEqual(state(followed: [.worldCup]).raceAlertsSubtitle, "1 series")
        XCTAssertEqual(state(followed: [.worldCup, .otherBelgian]).raceAlertsSubtitle, "2 series")
    }

    func testCatalanSeriesCountIsPlural() {
        L10n.setLanguage("ca")
        defer { L10n.setLanguage("en") }
        XCTAssertEqual(state(followed: [.worldCup]).raceAlertsSubtitle, "1 sèrie")
        XCTAssertEqual(state(followed: [.worldCup, .superprestige]).raceAlertsSubtitle, "2 sèries")
    }

    func testOpenIOSSettingsGoesThroughTheRouter() {
        let router = Router()
        var opened: [URL] = []
        router.openExternally = { opened.append($0) }
        let viewModel = VM(
            router: router,
            interactor: makeInteractor()
        )
        viewModel.action(.didTapOpenSystemSettings)
        XCTAssertEqual(opened, [RaceAlerts.systemSettingsURL].compactMap { $0 })
        XCTAssertEqual(opened.count, 1)
    }
}
