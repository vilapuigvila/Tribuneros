//
//  VideoPlaybackView.swift
//  Tribuneros
//

import AVFoundation
import SwiftUI
import UIKit
import YouTubePlayerKit

/// A YouTube video to play full screen over a tab.
struct VideoPlayback: Identifiable, Equatable {
    let videoID: String
    let url: URL
    var id: String { videoID }
}

extension View {
    /// Plays `video` full screen, landscape and muted, while it's set; the close button clears it.
    func videoPlayback(
        _ video: Binding<VideoPlayback?>,
        openURL: @escaping (URL) -> Void
    ) -> some View {
        fullScreenCover(item: video) { shown in
            VideoPlaybackView(
                video: shown,
                onClose: { video.wrappedValue = nil },
                openURL: openURL
            )
        }
    }
}

struct VideoPlaybackView: View {
    let video: VideoPlayback
    let onClose: () -> Void
    let openURL: (URL) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.tribuneru(.black)
                .ignoresSafeArea()
            content
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.tribuneru(.white(level: 1)))
                    .frame(width: 44, height: 44)
                    .background(Color.tribuneru(.black).opacity(0.6))
                    .clipShape(Circle())
            }
            .padding(16)
            .accessibilityLabel(L10n.tr("Close video"))
            .accessibilityIdentifier("video-playback-close")
        }
        .onAppear {
            Self.rotate(toLandscape: true)
        }
        .onDisappear {
            Self.rotate(toLandscape: false)
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if HomeRaces.MockScenario.current != nil {
            mockPlayer
        } else {
            LivePlayer(
                video: video,
                openURL: openURL
            )
        }
        #else
        LivePlayer(
            video: video,
            openURL: openURL
        )
        #endif
    }

    #if DEBUG
    /// Stands in for the web view under a mock scenario, so no flow loads YouTube.
    private var mockPlayer: some View {
        Image(systemName: "play.rectangle.fill")
            .font(.system(size: 40))
            .foregroundColor(.tribuneru(.white(level: 1)))
            .accessibilityIdentifier("video-playback-player")
    }
    #endif

    private static func rotate(toLandscape isLandscape: Bool) {
        guard let scene = UIApplication.keyWindow?.windowScene else { return }
        scene.requestGeometryUpdate(
            .iOS(
                interfaceOrientations: isLandscape ? .landscape : .portrait
            )
        )
    }

    private struct LivePlayer: View {
        let video: VideoPlayback
        let openURL: (URL) -> Void

        @StateObject private var player: YouTubePlayer

        init(
            video: VideoPlayback,
            openURL: @escaping (URL) -> Void
        ) {
            self.video = video
            self.openURL = openURL
            _player = StateObject(
                wrappedValue: YouTubePlayer(
                    source: .video(id: video.videoID),
                    parameters: .init(
                        autoPlay: true,
                        showFullscreenButton: false
                    ),
                    configuration: .init(allowsInlineMediaPlayback: true)
                )
            )
        }

        var body: some View {
            YouTubePlayerView(player) { state in
                switch state {
                case .idle:
                    Color.tribuneru(.black)
                case .ready:
                    EmptyView()
                case .error:
                    fallback
                }
            }
            .accessibilityIdentifier("video-playback-player")
            .task {
                for await state in player.statePublisher.values {
                    guard case .ready = state else { continue }
                    try? await player.mute()
                    break
                }
            }
            .onAppear {
                try? AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .moviePlayback
                )
            }
        }

        private var fallback: some View {
            Button {
                openURL(video.url)
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.tribuneru(.white(level: 1)))
                    TribuneruText(
                        content: L10n.tr("Open in YouTube"),
                        style: .vaporRaceNameNext,
                        color: .tribuneru(.white(level: 1)),
                        lineLimit: 1
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }
}
