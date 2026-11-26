//
//  PushNotifications.swift
//  Tribuneros
//

import UIKit
import UserNotifications
import FirebaseMessaging

enum PushPermission {
    static func shouldAsk(
        status: UNAuthorizationStatus,
        isLaunchSplashFinished: Bool,
        isOnboardingShowing: Bool,
        isMockedLaunch: Bool,
        isPromptFlagOn: Bool
    ) -> Bool {
        guard status == .notDetermined, isLaunchSplashFinished, !isOnboardingShowing else { return false }
        return !isMockedLaunch || isPromptFlagOn
    }

    #if DEBUG
    static var isMockedLaunch: Bool { HomeRaces.MockScenario.current != nil }

    /// `PUSH_PROMPT` or the `pushPrompt` launch argument lets a mocked launch ask.
    static var isPromptFlagOn: Bool {
        Onboarding.debugFlag(
            environment: ProcessInfo.processInfo.environment,
            key: "PUSH_PROMPT",
            launchValue: UserDefaults.standard.string(forKey: "pushPrompt")
        ) ?? false
    }
    #else
    static let isMockedLaunch = false
    static let isPromptFlagOn = false
    #endif
}

@MainActor
final class PushNotifications: NSObject {
    static let shared = PushNotifications()

    private var center: UNUserNotificationCenter { .current() }
    private var backgroundObserver: NSObjectProtocol?

    /// Called from `didFinishLaunching`, after `FirebaseApp.configure()` ran in `TribunerosApp.init()`.
    func start(application: UIApplication) {
        center.delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
        // A badge left after the user opened the app reads as unread news, so it goes when the app leaves.
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            // queue: .main, so this already runs on the main actor; no hop before the app is suspended.
            MainActor.assumeIsolated {
                PushNotifications.shared.clearBadge()
            }
        }
    }

    func clearBadge() {
        center.setBadgeCount(0) { error in
            guard let error else { return }
            AppLogger.network.error("Badge reset failed: \(error.localizedDescription)")
        }
    }

    func requestPermissionIfNeeded(
        isLaunchSplashFinished: Bool,
        isOnboardingShowing: Bool
    ) async {
        let status = await center.notificationSettings().authorizationStatus
        guard PushPermission.shouldAsk(
            status: status,
            isLaunchSplashFinished: isLaunchSplashFinished,
            isOnboardingShowing: isOnboardingShowing,
            isMockedLaunch: PushPermission.isMockedLaunch,
            isPromptFlagOn: PushPermission.isPromptFlagOn
        ) else { return }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            AppLogger.network.log("Push permission granted: \(granted)")
        } catch {
            nonFatalCrashlytics(
                false,
                "Push permission request failed: \(error.localizedDescription)"
            )
        }
    }
}

extension PushNotifications: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    // Main actor: UIKit runs the completion (snapshot/state restoration) on the thread this returns on.
    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        Messaging.messaging().appDidReceiveMessage(content.userInfo)
        guard let request = RaceAlerts.OpenRequest(
            identifier: response.notification.request.identifier,
            userInfo: content.userInfo
        ) else { return }
        RaceAlerts.OpenRequests.shared.pending = request
    }
}

extension PushNotifications: MessagingDelegate {
    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        AppLogger.network.log("FCM token: \(fcmToken ?? "nil")")
    }
}

extension PushNotifications {
    nonisolated static func subscribeToAllTopic() {
        Messaging.messaging().subscribe(toTopic: "all") { error in
            if let error {
                nonFatalCrashlytics(
                    false,
                    "FCM topic subscribe failed: \(error.localizedDescription)"
                )
                AppLogger.network.error("FCM topic subscribe failed: \(error.localizedDescription)")
            } else {
                AppLogger.network.log("Subscribed to topic all")
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushNotifications.shared.start(application: application)
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        AppLogger.network.log("APNs token: \(hex)")
        Messaging.messaging().apnsToken = deviceToken
        PushNotifications.subscribeToAllTopic()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.network.error("APNs registration failed: \(error.localizedDescription)")
    }
}
