//
//  OnboardingMusic.swift
//  Tribuneros
//

import AVFoundation

/// Loops the current onboarding page's track, crossfading on page changes.
@MainActor
final class OnboardingMusic: ObservableObject {
    private static let fadeDuration: TimeInterval = 0.6

    @Published private(set) var isMuted = UserSettings.onboardingMusicMuted ?? false

    private var current: (track: String, player: AVAudioPlayer)?
    private var fadingOut: [AVAudioPlayer] = []

    func toggleMute() {
        isMuted.toggle()
        UserSettings.onboardingMusicMuted = isMuted
        current?.player.setVolume(
            isMuted ? 0 : 1,
            fadeDuration: Self.fadeDuration
        )
    }

    func play(_ track: String) {
        guard current?.track != track else { return }
        fadeOutCurrent()
        guard let url = Bundle.main.url(
            forResource: track,
            withExtension: "m4a"
        ) else {
            nonFatalCrashlytics(
                false,
                "Onboarding track \(track).m4a missing from the bundle"
            )
            return
        }
        do {
            // Ambient: respects the silent switch and doesn't stop the user's own audio.
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default
            )
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            player.setVolume(
                isMuted ? 0 : 1,
                fadeDuration: Self.fadeDuration
            )
            current = (track, player)
        } catch {
            nonFatalCrashlytics(
                false,
                "Onboarding track \(track) failed: \(error)"
            )
        }
    }

    func stop() {
        fadeOutCurrent()
    }

    private func fadeOutCurrent() {
        guard let player = current?.player else { return }
        current = nil
        fadingOut.append(player)
        player.setVolume(
            0,
            fadeDuration: Self.fadeDuration
        )
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.fadeDuration))
            player.stop()
            guard let self else { return }
            fadingOut.removeAll { $0 === player }
            if current == nil, fadingOut.isEmpty {
                try? AVAudioSession.sharedInstance().setActive(
                    false,
                    options: .notifyOthersOnDeactivation
                )
            }
        }
    }
}
