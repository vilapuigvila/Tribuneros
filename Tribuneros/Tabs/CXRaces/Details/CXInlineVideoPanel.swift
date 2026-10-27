//
//  CXInlineVideoPanel.swift
//  Tribuneros
//

import AVFoundation
import SwiftUI
import UIKit
import YouTubePlayerKit

/// The race video played inside the screen (YouTube's iframe player in a web view, via YouTubePlayerKit).
/// A player that can't load or play the video (embedding disabled, offline) shows an "open in YouTube" button.
struct CXInlineVideoPanel: View {
    let videoID: String
    let openURL: (URL) -> Void

    var body: some View {
        MudPanel(title: L10n.tr("Race video")) {
            #if DEBUG
            if HomeRaces.MockScenario.current != nil, !Self.isLiveVideoOn {
                mockPlayer
            } else {
                LivePlayer(
                    videoID: videoID,
                    openURL: openURL
                )
            }
            #else
            LivePlayer(
                videoID: videoID,
                openURL: openURL
            )
            #endif
        }
    }

    #if DEBUG
    /// `LIVE_VIDEO` (or a `liveVideo` launch argument) keeps the real player under a mock scenario.
    private static var isLiveVideoOn: Bool {
        let value = ProcessInfo.processInfo.environment["LIVE_VIDEO"]
            ?? UserDefaults.standard.string(forKey: "liveVideo")
        return ["1", "on", "true", "yes"].contains(value?.lowercased() ?? "")
    }

    /// Stands in for the web view under a mock scenario, so no flow loads YouTube.
    private var mockPlayer: some View {
        ZStack {
            Color.tribuneru(.mudCardSurface)
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.tribuneru(.mudTextSecondary))
        }
        .aspectRatio(
            16 / 9,
            contentMode: .fit
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("Race video"))
        .accessibilityIdentifier("event-video-player")
    }
    #endif

    private struct LivePlayer: View {
        let videoID: String
        let openURL: (URL) -> Void

        @StateObject private var player: YouTubePlayer

        init(
            videoID: String,
            openURL: @escaping (URL) -> Void
        ) {
            self.videoID = videoID
            self.openURL = openURL
            _player = StateObject(
                wrappedValue: YouTubePlayer(
                    source: .video(id: videoID),
                    parameters: .init(
                        autoPlay: false,
                        showFullscreenButton: true
                    ),
                    configuration: .init(
                        fullscreenMode: .system,
                        // Without inline playback, tapping play opens the system full-screen player.
                        allowsInlineMediaPlayback: false
                    )
                )
            )
        }

        var body: some View {
            YouTubePlayerView(player) { state in
                switch state {
                case .idle:
                    Color.tribuneru(.mudCardSurface)
                        .redacted(reason: .placeholder)
                case .ready:
                    EmptyView()
                case .error:
                    fallback
                }
            }
            .aspectRatio(
                16 / 9,
                contentMode: .fit
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("event-video-player")
            .task {
                for await state in player.statePublisher.values {
                    guard case .ready = state else { continue }
                    try? await player.mute()
                    break
                }
            }
            .task {
                for await state in player.fullscreenStatePublisher.values {
                    Self.rotate(toLandscape: state.isFullscreen)
                }
            }
            .onDisappear {
                Self.rotate(toLandscape: false)
            }
            .onAppear {
                try? AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .moviePlayback
                )
            }
        }

        /// Lets the video's full screen turn landscape and returns the app to portrait when it ends.
        private static func rotate(toLandscape isLandscape: Bool) {
            guard let scene = UIApplication.keyWindow?.windowScene else { return }
            scene.requestGeometryUpdate(
                .iOS(
                    interfaceOrientations: isLandscape ? .landscape : .portrait
                )
            )
        }

        private var fallback: some View {
            Button {
                if let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") {
                    openURL(url)
                }
            } label: {
                ZStack {
                    Color.tribuneru(.mudCardSurface)
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.tribuneru(.mudTextSecondary))
                        TribuneruText(
                            content: L10n.tr("Open in YouTube"),
                            style: .vaporRaceNameNext,
                            color: .tribuneru(.mudTextPrimary),
                            lineLimit: 1
                        )
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}

extension CXInlineVideoPanel {
    /// The id of a `youtube.com/watch?v=` or `youtu.be/` link; nil for any other URL.
    static func youTubeID(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        if host == "youtu.be" {
            return url.pathComponents.dropFirst().first
        }
        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        return URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems?.first { $0.name == "v" }?.value
    }
}
