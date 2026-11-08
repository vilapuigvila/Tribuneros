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

    /// Called from `didFinishLaunching`, after `FirebaseApp.configure()` ran in `TribunerosApp.init()`.
    func start(application: UIApplication) {
        center.delegate = self
        Messaging.messaging().delegate = self
        application.registerForRemoteNotifications()
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
}

extension PushNotifications: MessagingDelegate {
    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        AppLogger.network.log("FCM token: \(fcmToken ?? "nil")")
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
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.network.error("APNs registration failed: \(error.localizedDescription)")
    }
}
