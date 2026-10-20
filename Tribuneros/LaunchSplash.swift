//
//  LaunchSplash.swift
//  Tribuneros
//

import AVFoundation
import Lottie
import SwiftUI

enum LaunchSplash {
    static let minimumDuration: Duration = .seconds(3)
    static let maximumDuration: Duration = .seconds(8)
    static let fadeDuration: TimeInterval = 0.4
    static let title = "Cycling Tribune"

    static func isEnabled(
        override: Bool?,
        hasMockScenario: Bool,
        isFreshInstall: Bool = false
    ) -> Bool {
        override ?? (!hasMockScenario && !isFreshInstall)
    }

    /// Nothing recorded about the onboarding yet (or a debug reset asked for): the onboarding is the only thing shown.
    static var isFreshInstall: Bool {
        UserSettings.onboardingFirstShown == nil || Onboarding.resetsAtLaunch
    }

    /// Mocked launches never reach the network, so for them the request counts as already finished.
    static func warmHomepage(
        hasMockScenario: Bool = hasMockScenarioAtLaunch,
        fetch: @Sendable () async throws -> Void = { _ = try await Service.getHomepageDocument() }
    ) async throws {
        guard !hasMockScenario else { return }
        try await fetch()
    }

    /// Closes after at least `minimum`, then as soon as `request` ends (a throw counts as ended), and never after `maximum`; a request still running at the cap keeps going and fills the cache.
    static func waitToClose(
        minimum: Duration = minimumDuration,
        maximum: Duration = maximumDuration,
        request: @escaping @Sendable () async throws -> Void
    ) async {
        let clock = ContinuousClock()
        let start = clock.now
        let (ended, signal) = AsyncStream<Void>.makeStream()
        Task.detached(priority: .userInitiated) {
            try? await request()
            signal.yield()
        }
        let cap = Task {
            try? await clock.sleep(until: start.advanced(by: maximum))
            signal.yield()
        }
        defer { cap.cancel() }
        try? await clock.sleep(until: start.advanced(by: minimum))
        for await _ in ended { break }
    }

    #if DEBUG
    static var hasMockScenarioAtLaunch: Bool {
        HomeRaces.MockScenario.current != nil
    }

    /// Mocked launches (Maestro) skip the splash unless `LAUNCH_SPLASH` or the `launchSplash` launch argument turns it on.
    static var isEnabledAtLaunch: Bool {
        isEnabled(
            override: debugOverride(
                environment: ProcessInfo.processInfo.environment,
                launchValue: UserDefaults.standard.string(forKey: "launchSplash")
            ),
            hasMockScenario: HomeRaces.MockScenario.current != nil,
            isFreshInstall: isFreshInstall
        )
    }

    static func debugOverride(
        environment: [String: String],
        launchValue: String?
    ) -> Bool? {
        (environment["LAUNCH_SPLASH"] ?? launchValue)
            .map { ["1", "on", "true", "yes"].contains($0.lowercased()) }
    }
    #else
    static let hasMockScenarioAtLaunch = false
    static var isEnabledAtLaunch: Bool { !isFreshInstall }
    #endif
}

private struct LaunchSplashFinishedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False while the launch splash is on screen or fading out, true once it is gone (or when there is none); set by `LaunchSplashHost`.
    var isLaunchSplashFinished: Bool {
        get { self[LaunchSplashFinishedKey.self] }
        set { self[LaunchSplashFinishedKey.self] = newValue }
    }
}

@MainActor
final class LaunchJingle: ObservableObject {
    private var player: AVAudioPlayer?

    func play() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(
            forResource: "launch_jingle",
            withExtension: "m4a"
        ) else {
            nonFatalCrashlytics(false, "launch_jingle.m4a missing from the bundle")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            self.player = player
        } catch {
            nonFatalCrashlytics(false, "Launch jingle: \(error.localizedDescription)")
        }
    }

    func fadeOut(duration: TimeInterval) async {
        guard let player else { return }
        player.setVolume(
            0,
            fadeDuration: duration
        )
        try? await Task.sleep(for: .seconds(duration))
        player.stop()
        self.player = nil
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}

/// Owns the splash state so hiding it re-renders only this view; `content` is built once, like `MaintenanceHost`.
struct LaunchSplashHost<Content: View>: View {
    @State private var isShowingSplash = LaunchSplash.isEnabledAtLaunch
    @State private var isFinished = !LaunchSplash.isEnabledAtLaunch
    @StateObject private var jingle = LaunchJingle()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .environment(
                    \.isLaunchSplashFinished,
                    isFinished
                )
                .accessibilityHidden(isShowingSplash)
            if isShowingSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(1)
                    .onAppear { jingle.play() }
            }
        }
        .task { await finish() }
    }

    private func finish() async {
        guard isShowingSplash else { return }
        await LaunchSplash.waitToClose { try await LaunchSplash.warmHomepage() }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: LaunchSplash.fadeDuration)) {
            isShowingSplash = false
        }
        async let jingleFaded: Void = jingle.fadeOut(duration: LaunchSplash.fadeDuration)
        try? await Task.sleep(for: .seconds(LaunchSplash.fadeDuration))
        isFinished = true
        await jingleFaded
    }
}

struct LaunchSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.tribuneru(.vaporPageBackground)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                LottieView(animation: .named("launch_splash"))
                    .playbackMode(
                        reduceMotion
                            ? .paused(at: .progress(1))
                            : .playing(.fromProgress(
                                0,
                                toProgress: 1,
                                loopMode: .playOnce
                            ))
                    )
                    .resizable()
                    .aspectRatio(
                        4 / 3,
                        contentMode: .fit
                    )
                    .frame(maxWidth: 400)
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [
                                Color.tribuneru(.vaporPageBackground).opacity(0),
                                Color.tribuneru(.vaporPageBackground)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 90)
                    }
                    .accessibilityHidden(true)
                TribuneruText(
                    content: LaunchSplash.title,
                    style: .vaporHeroTitle,
                    color: .tribuneru(.vaporTextPrimary)
                )
            }
            .padding(.horizontal, 16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(LaunchSplash.title)
        .accessibilityIdentifier("launch.splash")
    }
}
