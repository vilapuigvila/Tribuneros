//
//  Loader.swift
//  Tribuneros
//
//  Created by albert vila puigvila on 5/11/25.
//

import SwiftUI

struct LoaderView: View {
    let title: String
    let subtitle: String?

    @State private var rotate = false

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.tribuneru(.vaporTextPrimary).opacity(0.08), lineWidth: 10)
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.tribuneru(.vaporAccent).opacity(0.9),
                                Color.tribuneru(.vaporAccent).opacity(0.2),
                                Color.tribuneru(.vaporAccent).opacity(0.9)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotate)
            }
            .frame(width: 72, height: 72)
            .shadow(color: Color.tribuneru(.vaporAccent).opacity(0.35), radius: 12)
            .onAppear { rotate = true }

            TribuneruText(
                content: title,
                style: .vaporRaceNameNext,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
            .multilineTextAlignment(.center)

            if let subtitle {
                TribuneruText(
                    content: subtitle,
                    style: .vaporMeta,
                    color: .tribuneru(.vaporTextSecondary),
                    lineLimit: 2
                )
                .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Delayed loader -

/// What a loading screen shows: nothing while a load is `waiting` (its first second), then the
/// `loader`, kept for at least another second once shown, then the `content`. Fast loads never
/// flash a loader, and a loader never flashes away.
enum LoaderPhase: Equatable {
    case waiting
    case loader
    case content

    static let delay: Duration = .seconds(1)
    static let minimumDisplay: Duration = .seconds(1)

    init(isLoading: Bool) {
        self = isLoading ? .waiting : .content
    }
}

extension View {
    /// Drives `phase` from `isLoading`; attach it to a view that stays on screen while loading.
    func loaderPhase(
        _ phase: Binding<LoaderPhase>,
        isLoading: Bool
    ) -> some View {
        modifier(
            LoaderPhaseModifier(
                isLoading: isLoading,
                phase: phase
            )
        )
    }
}

private struct LoaderPhaseModifier: ViewModifier {
    let isLoading: Bool
    @Binding var phase: LoaderPhase
    @State private var loaderShownAt: ContinuousClock.Instant?

    func body(content: Content) -> some View {
        content
        // Transitions that need no timer happen in the same update, not a task hop later.
        .onChange(of: isLoading) { _, isLoading in
            if isLoading, phase == .content {
                phase = .waiting
            } else if !isLoading, phase == .waiting {
                phase = .content
            }
        }
        .task(id: isLoading) {
            if isLoading {
                if phase == .content {
                    phase = .waiting
                }
                guard phase == .waiting else { return }
                try? await Task.sleep(for: LoaderPhase.delay)
                guard !Task.isCancelled else { return }
                loaderShownAt = .now
                phase = .loader
            } else {
                if phase == .loader, let loaderShownAt {
                    try? await Task.sleep(
                        until: loaderShownAt + LoaderPhase.minimumDisplay,
                        clock: .continuous
                    )
                    guard !Task.isCancelled else { return }
                }
                phase = .content
            }
        }
    }
}
