//
//  LaunchSplash.swift
//  Tribuneros
//

import AVFoundation
import Lottie
import SwiftUI

enum LaunchSplash {
    static let minimumDuration: Duration = .seconds(5)
    static let fadeDuration: TimeInterval = 0.4
    static let title = "Cycling Tribune"

    static func isEnabled(
        override: Bool?,
        hasMockScenario: Bool
    ) -> Bool {
        override ?? !hasMockScenario
    }

    #if DEBUG
    /// Mocked launches (Maestro) skip the splash unless `LAUNCH_SPLASH` or the `launchSplash` launch argument turns it on.
    static var isEnabledAtLaunch: Bool {
        isEnabled(
            override: debugOverride(
                environment: ProcessInfo.processInfo.environment,
                launchValue: UserDefaults.standard.string(forKey: "launchSplash")
            ),
            hasMockScenario: HomeRaces.MockScenario.current != nil
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
    static let isEnabledAtLaunch = true
    #endif
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
    @StateObject private var jingle = LaunchJingle()
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
                .accessibilityHidden(isShowingSplash)
            if isShowingSplash {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(1)
                    .onAppear { jingle.play() }
                    .task { await finish() }
            }
        }
    }

    private func finish() async {
        try? await Task.sleep(for: LaunchSplash.minimumDuration)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: LaunchSplash.fadeDuration)) {
            isShowingSplash = false
        }
        await jingle.fadeOut(duration: LaunchSplash.fadeDuration)
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
