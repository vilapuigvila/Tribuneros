//
//  ErrorFlash.swift
//  Tribuneros
//

import SwiftUI
import UIKit

/// A transient error card: `.errorFlash(message: $message)` shows it when the binding gets a value, then clears it.
enum ErrorFlash {
    static let enterDuration: TimeInterval = 0.35
    static let holdDuration: TimeInterval = 1.8
    static let exitDuration: TimeInterval = 0.35
    static var totalDuration: TimeInterval { enterDuration + holdDuration + exitDuration }

    enum Phase: Equatable {
        case entering
        case holding
        case leaving
        case gone
    }

    static func phase(at elapsed: TimeInterval) -> Phase {
        switch elapsed {
        case ..<enterDuration: .entering
        case ..<(enterDuration + holdDuration): .holding
        case ..<totalDuration: .leaving
        default: .gone
        }
    }

    static func isShown(_ phase: Phase) -> Bool {
        phase == .entering || phase == .holding
    }

    /// Offset above the resting spot; Reduce Motion keeps the card in place and only fades.
    static func yOffset(shown: Bool, reduceMotion: Bool) -> CGFloat {
        shown || reduceMotion ? 0 : -24
    }

    @MainActor
    static func announce(_ message: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        UIAccessibility.post(
            notification: .announcement,
            argument: message
        )
    }
}

private struct ErrorFlashModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownMessage: String?
    @State private var isShown = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let shownMessage {
                    card(shownMessage)
                        .opacity(isShown ? 1 : 0)
                        .offset(y: ErrorFlash.yOffset(shown: isShown, reduceMotion: reduceMotion))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .task(id: message) {
                guard let text = message else { return }
                await run(text)
            }
    }

    private func card(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tribuneru(.vaporNegative))
            TribuneruText(
                content: text,
                style: .vaporMeta,
                color: .tribuneru(.vaporTextPrimary),
                lineLimit: 2
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.tribuneru(.vaporCardSurface))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.tribuneru(.vaporNegative),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityIdentifier("errorFlash")
    }

    private func run(_ text: String) async {
        shownMessage = text
        isShown = false
        ErrorFlash.announce(text)
        withAnimation(.easeOut(duration: ErrorFlash.enterDuration)) { isShown = true }
        try? await Task.sleep(for: .seconds(ErrorFlash.enterDuration + ErrorFlash.holdDuration))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: ErrorFlash.exitDuration)) { isShown = false }
        try? await Task.sleep(for: .seconds(ErrorFlash.exitDuration))
        guard !Task.isCancelled else { return }
        shownMessage = nil
        message = nil
    }
}

extension View {
    func errorFlash(message: Binding<String?>) -> some View {
        modifier(ErrorFlashModifier(message: message))
    }
}
